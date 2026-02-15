# CWWK N355 NAS Motherboard - BIOS Power Optimization

This repository documents the BIOS configuration used to minimize idle power consumption on a CWWK N355 NAS motherboard (equipped with a 10G NIC, dual 2.5G NICs, 4x HDDs, and 2x NVMe SSDs) running Proxmox VE and ZFS.

## BIOS Changes Applied

**1. Unlocked Advanced Engineering Menus:**
* **Path:** `Chipset` -> `System Agent (SA) Configuration` -> `Graphics Configuration`
* **Action:** Enabled `Yellow Screen Workaround`.
* **Reason:** Unhides the manufacturer's deep-level advanced power and ACPI menus that are locked by default.

**2. Disabled Unused I/O (Parasitic Power Reduction):**
* **Path:** `Advanced` -> `IT8613 Super IO Configuration` & `Serial Port Console Redirection`
* **Action:** Disabled `Serial Port 1` and all COM console redirections.
* **Reason:** Legacy controller chips draw constant power. Disabling them saves ~1–2W at the wall.

**3. Configured Deep CPU Sleep (C-States):**
* **Path:** `Advanced` -> `Power & Performance` -> `CPU - Power Management Control` -> `Package C State Limit`
* **Action:** Set to `C8`. (Ensured `C states` and `Enhanced C-states` were set to `[Enabled]`).
* **Reason:** Allows the N355 processor to drop voltage significantly when idle. *Note: C10 was deliberately avoided as it is known to cause Proxmox/ZFS kernel panics on this specific motherboard.*

**4. Enabled Global PCIe Power Management (ASPM):**
* **Path:** `Advanced` -> `PCI Subsystem Settings`
* **Action:** Set `ASPM Support` to `[Auto]` (or `[L1]` where available) and set `Unpopulated Links` to `[Disable Link]`.
* **Reason:** Allows the motherboard to negotiate power drops to unused or idle PCIe lanes.

**5. Configured Deep Sleep for CPU-to-Chipset Link (DMI):**
* **Path:** `Chipset` -> `System Agent (SA) Configuration` -> `DMI/OPI Configuration`
* **Action:** Set `DMI Gen3 ASPM` and `DMI ASPM` to `[ASPM L1]`.
* **Reason:** Forces the primary data highway between the CPU and the motherboard chipset into a deep sleep state when no data is being moved.

**6. Forced L1 ASPM on Active PCIe Root Ports (NVMe & NICs):**
* **Path:** `Chipset` -> `PCH-IO Configuration` -> `PCI Express Configuration`
* **Action:** Entered each active Root Port (typically 1, 2, 3, 4, 7, and 9) and set `ASPM Support` to `[ASPM L1]` and `L1 Substates` to `[L1.1 & L1.2]`.
* **Reason:** This is the most critical step for this board. It strictly forces the 10G Aquantia NIC, the 2.5G Intel NICs, and the NVMe drives to drop to near-zero wattage when idle. *(Note: If boot loops or HDD dropouts occur, revert the ASPM setting to [Auto] or [Disabled] only on the specific Root Port tied to the JMB585/ASM1166 SATA controller).*

---

## Kernel-Level ASPM Fix (Boot Parameters)

The BIOS changes above configure ASPM at the hardware level, but the Linux kernel also needs to be told to actively manage PCIe power states.

**Note:** Proxmox with ZFS root uses `proxmox-boot-tool` (systemd-boot), not GRUB. Kernel parameters go in `/etc/kernel/cmdline`, refreshed with `proxmox-boot-tool refresh`.

### The Problem

The CWWK N355 ACPI FADT table incorrectly declares `the system doesn't support PCIe ASPM`. The kernel logs:

```
ACPI FADT declares the system doesn't support PCIe ASPM, so disable it
FADT indicates ASPM is unsupported, using BIOS configuration
```

Without kernel intervention, the OS falls back to passive BIOS-configured ASPM. This gets most devices to L1 but:
* L1 substates (L1.1/L1.2) are **not enabled** on the Intel I226-V NICs and ASM1164 SATA root ports
* The kernel cannot dynamically manage ASPM policy
* The Aquantia AQC113C 10G NIC does **not support ASPM at the hardware level** (`LnkCap: ASPM not supported`) -- no kernel parameter can fix this

### The Fix

Added via Ansible playbook (`make proxmox-grub-aspm`):

```
# /etc/kernel/cmdline
root=ZFS=rpool/ROOT/pve-1 boot=zfs pcie_aspm=force pcie_aspm.policy=powersave
```

* `pcie_aspm=force` -- overrides the broken FADT table, gives the kernel active ASPM control
* `pcie_aspm.policy=powersave` -- enables the deepest substates (L1.1/L1.2) on all capable devices and prevents drivers (e.g. igc) from disabling ASPM

### Verification (after reboot)

```bash
# Check actual boot parameters
cat /proc/cmdline
# Should contain: pcie_aspm=force pcie_aspm.policy=powersave

# Confirm ASPM is force-enabled
dmesg | grep -i aspm
# Expected: "PCIe ASPM is forcibly enabled" + no more igc driver ASPM errors

# Check a specific device (Intel I226-V)
lspci -vv -s 04:00.0 | grep -i aspm
# Expected: LnkCtl: ASPM L1 Enabled

# Check active policy
cat /sys/module/pcie_aspm/parameters/policy
# Expected: default performance [powersave] powersupersave

# Check package C-states
turbostat --Summary --quiet --show PkgWatt,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc8 sleep 5
```

### Results

After applying the kernel parameters, verified with `turbostat` and `powertop`:

| Metric | Value |
|--------|-------|
| Pkg%pc2 | ~40% |
| Pkg%pc3 | ~50% |
| Pkg%pc6 | 0% |
| Pkg%pc8 | 0% |
| PkgWatt | **0.90W** |

* **Core C-states** are healthy: all cores spend ~85-93% in C6/C7
* **Package C-states** are capped at C3 -- the package never reaches C6 or C8
* **ASPM L1** is confirmed enabled on all devices except the Aquantia 10G NIC
* **Root cause**: the Aquantia AQC113C 10G NIC does not support ASPM (`LnkCap: ASPM not supported`). Its Gen3 x2 PCIe link is always active, forcing the SoC PCIe controller to stay awake and capping the package at C3

### Possible further improvements

* **Disable the Aquantia 10G NIC in BIOS** if it is not used -- removing the always-active PCIe link should allow the package to reach C8, potentially saving another ~1-2W at the wall
* **Runtime link disable via sysfs** (`echo 1 > /sys/bus/pci/devices/0000:01:00.0/remove`) as a less permanent alternative -- could be scripted to disable when 10G is not needed
* **Try `powersupersave` policy** (`pcie_aspm.policy=powersupersave`) for even more aggressive power management on the remaining devices
* **Investigate the Aquantia `atlantic` driver** power management options -- some firmware versions support PCI-PM L1.2 substates even without ASPM (the device does report `L1SubCap: PCI-PM_L1.2+`)

### Notes

* If stability issues arise (NVMe disconnects, network drops), fall back to just `pcie_aspm=force` without `pcie_aspm.policy=powersave` by overriding the Ansible variable: `make proxmox-grub-aspm -e "aspm_params=pcie_aspm=force"`
* The Aquantia AQC113C 10G NIC will always keep its PCIe link active -- this is a hardware limitation of Marvell/Aquantia 10G controllers
