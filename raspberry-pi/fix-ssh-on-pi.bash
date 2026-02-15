#!/bin/bash
# MIT License 
# Copyright (c) 2017 Ken Fallon http://kenfallon.com
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# v1.1 - changes to reflect that the sha_sum is now SHA-256
# v1.2 - Changes to split settings to different file, and use losetup

# Credits to:
# - http://hackerpublicradio.org/correspondents.php?hostid=225
# - https://gpiozero.readthedocs.io/en/stable/pi_zero_otg.html#legacy-method-sd-card-required
# - https://github.com/nmcclain/raspberian-firstboot

# Change the settings in the file mentioned below.

settings_file="fix-ssh-on-pi.ini"

# You should not need to change anything beyond here.

set -o errexit    # Used to exit upon error, avoiding cascading errors
# set -o pipefail   # Unveils hidden failures
set -o nounset    # Exposes unset variables

if [ -e "${settings_file}" ]
then
  source "${settings_file}"
elif [ -e "${HOME}/${settings_file}" ]
then
  source "${HOME}/${settings_file}"
elif [ -e "${0%.*}.ini" ]
then
  source "${0%.*}.ini"
else
  echo "💣 ERROR: Can't find the Settings file \"${settings_file}\""
  exit 1
fi

variables=(
  github_username
  static_ip
  hostname
)

for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]; then   # indirect expansion here
    echo "💣 ERROR: The variable \"${variable}\" is missing from your \""${settings_file}"\" file.";
    exit 2
  fi
done


image_to_download="https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.1-preinstalled-server-arm64+raspi.img.xz"
image_name="ubuntu-24.04.1-preinstalled-server-arm64+raspi.img.xz"
sha_gpg_url="https://cdimage.ubuntu.com/releases/24.04/release/SHA256SUMS.gpg"
sha_sum_url="https://cdimage.ubuntu.com/releases/24.04/release/SHA256SUMS"


sdcard_mount="/mnt/sdcard"

if [ $(id | grep 'uid=0(root)' | wc -l) -ne "1" ]
then
    echo "💣 You are not root "
    exit
fi

# if [ ! -e "${public_key_file}" ]
# then
#     echo "Can't find the public key file \"${public_key_file}\""
#     echo "You can create one using:"
#     echo "   ssh-keygen -t ed25519 -f ./${public_key_file} -C \"Raspberry Pi keys\""
#     exit 3
# fi

function umount_sdcard () {
    umount "${sdcard_mount}" || echo "umount: \"${sdcard_mount}\": not mounted."
    if [ $( ls -al "${sdcard_mount}" | wc -l ) -eq "3" ]
    then
        echo "✅ Sucessfully unmounted \"${sdcard_mount}\""
        sync
    else
        echo "💣 Could not unmount \"${sdcard_mount}\""
        exit 4
    fi
}

# Download the latest image, using the  --continue "Continue getting a partially-downloaded file"
echo "⚙ Downloading the image"
wget --continue ${image_to_download} -O ${image_name}
echo "✅ Downloaded the image"


echo "⚙ Checking the SHA256 of the downloaded image matches"

curl -sS -o SHA256SUMS.gpg $sha_gpg_url
curl -sS -o SHA256SUMS $sha_sum_url
gpg --keyid-format long --verify SHA256SUMS.gpg SHA256SUMS || echo "OK"

if [ $( sha256sum -c SHA256SUMS 2>&1 | grep OK | wc -l ) -eq "1" ]
then
    echo "✅ The sha_sums match"
else
    echo "💣 The sha_sums did not match"
    exit 5
fi

if [ ! -d "${sdcard_mount}" ]
then
  mkdir ${sdcard_mount}
fi

extracted_image=$(echo ${image_name} | sed 's/.xz//')
if [ -e ${extracted_image} ]
then
    echo "⚙ Deleting existing extracted image for idempotence"
    rm -f ${extracted_image}
fi

echo "⚙ Extracting \"${image_name}\" to \"${extracted_image}\""
xz --decompress ${image_name} --keep

if [ ! -e ${extracted_image} ]
then
    echo "💣 Can't find the image \"${extracted_image}\""
    exit 6
fi

umount_sdcard
echo "⚙ Mounting the sdcard boot disk"

loop_base=$( losetup --partscan --find --show "${extracted_image}" )

echo "⚙ Running: mount ${loop_base}p1 \"${sdcard_mount}\" "
mount ${loop_base}p1 "${sdcard_mount}"
ls -al /mnt/sdcard
if [ ! -e "${sdcard_mount}/initrd.img" ]
then
    echo "💣 Can't find the mounted card\"${sdcard_mount}/initrd.img\""
    exit 7
fi
echo "✅ Mounted the sdcard boot disk"


echo "⚙ Activating ssh"
touch "${sdcard_mount}/ssh"
if [ ! -e "${sdcard_mount}/ssh" ]
then
    echo "💣 Can't find the ssh file \"${sdcard_mount}/ssh\""
    exit 9
fi
echo "✅ SSH activated"

echo "Configure cloud init user-data"
user_data_template_file="templates/user-data"
if [ ! -e "${user_data_template_file}" ]
then
    echo "💣 Please provide a template file for user-data"
    exit 9
fi
echo "⚙ Add SSH keys from GitHub user \"${github_username}\" and configure hostname to \"${hostname}\""
GITHUB_USERNAME=${github_username} HOSTNAME=${hostname} envsubst < ${user_data_template_file} > "${sdcard_mount}/user-data"
echo "✅ Cloud init configured for Github \"${github_username}\""


network_config_template_file="templates/network-config"
echo "⚙ Setting static ip: \"${static_ip}\", using ${network_config_template_file}"

if [ ! -e "${network_config_template_file}" ]
then
    echo "💣 Please provide a template file for network-config"
    exit 9
fi
STATIC_IP=${static_ip} envsubst < ${network_config_template_file} > "${sdcard_mount}/network-config"
echo "✅ Set static IP to \"${static_ip}\" with cloud-init"

echo "⚙ Enable cgroup limits support"
sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' "${sdcard_mount}/cmdline.txt"
echo "✅ cgroup limits support enabled"

echo "⚙ Deactivate wifi and bluetooth"
echo 'dtoverlay=disable-wifi' | tee -a "${sdcard_mount}/usercfg.txt"
echo 'dtoverlay=disable-bt' | tee -a "${sdcard_mount}/usercfg.txt"
echo "✅ cgroup limits support enabled"

umount_sdcard

# echo "⚙ Mounting the sdcard root disk"
# echo "Running: mount ${loop_base}p2 \"${sdcard_mount}\" "
# mount ${loop_base}p2 "${sdcard_mount}"
# ls -al /mnt/sdcard
# if [ ! -e "${sdcard_mount}/etc/shadow" ]
# then
#     echo "💣 Can't find the mounted card\"${sdcard_mount}/etc/shadow\""
#     exit 10
# fi
# echo "✅ Mounted the sdcard root disk"

# echo "⚙ Change sshd_config file"
# sed -e 's;^#PasswordAuthentication.*$;PasswordAuthentication no;g' -e 's;^PermitRootLogin .*$;PermitRootLogin no;g' -i "${sdcard_mount}/etc/ssh/sshd_config"
# mkdir "${sdcard_mount}/home/ubuntu/.ssh"
# chmod 0700 "${sdcard_mount}/home/ubuntu/.ssh"
# chown 1000:1000 "${sdcard_mount}/home/ubuntu/.ssh"
# curl ${public_key_url} -o "${sdcard_mount}/home/ubuntu/.ssh/authorized_keys"
# chown 1000:1000 "${sdcard_mount}/home/ubuntu/.ssh/authorized_keys"
# chmod 0600 "${sdcard_mount}/home/ubuntu/.ssh/authorized_keys"
# echo "✅ SSH configured"

# echo "⚙ Configure hostname to \"${hostname}\""
# echo ${hostname} > "${sdcard_mount}/etc/hostname"
# echo "✅ Hostname configured"

# umount_sdcard

new_name="${extracted_image%.*}-${hostname}.img"
cp -v "${extracted_image}" "${new_name}"

losetup --detach ${loop_base}

echo ""
echo "Now you can burn the disk using something like:"
echo "      dd bs=4M status=progress if=${new_name} of=/dev/mmcblk????"
echo ""
