# tf-oci-arm

Oracle Cloud has a generous Always-Free tier that includes
a 4 CPU, 24 GB RAM, 200 GB disk, arm64 vm.

Network limits are very very very generous.

Oracle Cloud also has managed terraform (called Stacks).

## this repo

This terraform + cloud-init project creates an Ampere VM with a public IP
that is fully firewalled on a [tailscale](https://tailscale.com) network.

The OS image is Ubuntu 20.04.

The cloud-init:
- Bootstraps Tailscale
- Configures SSH using your GitHub public keys (fetched from your username)
- Installs Docker

The Virtual Cloud Network has a Security List that **blocks all internet traffic** except for
tailscale's NAT traversal protocols.

Unfortunately, while NAT gateways are Free, they are not available on Free accounts that do
not have a payment method, so I left out the private IP config, which is why the VM still
must have a public IP.

## tailscale auth key (terraform-managed)

The auth key the reverse proxy VM joins with is a `tailscale_tailnet_key` resource
(`tailscale.tf`). It expires after 90 days and `recreate_if_invalid` recreates
it on the next plan, so with Burrito autoApply the rotation is automatic. A
key-only rotation does not rebuild the VM: the resulting `user_data` diff is
ignored and rebuilds are driven by the `hostname_suffix` keepers, whose
userdata fingerprint excludes the key. Any other userdata or variable change
still triggers the blue/green rebuild, and the replacement VM boots with the
current key from state.

After each rebuild, a `local-exec` step (`scripts/tailnet-adopt.sh`) waits for
the new device to join, deletes the stale `oracle-arm*` records and renames
the new device to the stable `oracle-arm`, so MagicDNS and the ansible
inventory keep working across swaps. A second step (`scripts/public-check.sh`)
fails the apply if nginx does not accept TCP on the public 80/443 within
5 minutes. To force a rebuild of a broken VM:
`terraform apply -replace=random_id.hostname_suffix`.

The Burrito layer runs with `autoApply: true` on a custom runner image
(`images/burrito-runner`: the official burrito image plus curl, jq and
netcat-openbsd for the scripts above), built by the `build-burrito-runner`
GitHub workflow and published to `ghcr.io/dixneuf19/burrito-runner` with the
burrito version as tag. One-time step after the first build: make the package
public in its GitHub settings so the cluster pulls it anonymously.

One-time setup for the provider credentials:

1. Create an OAuth client in the
   [Tailscale admin console](https://login.tailscale.com/admin/settings/oauth)
   with the `auth_keys` and `devices:core` write scopes restricted to
   `tag:brassberry` (add the `policy_file` scope too if/when the ACL becomes
   terraform-managed). Scopes cannot be edited afterwards: changing them means
   creating a new client and updating both bws secrets
2. Apply `terraform/bitwarden` to create the `tailscale-oauth-client-id` and
   `tailscale-oauth-client-secret` secrets (created with placeholder values)
   and delete the old manual `tailscale-auth-key` secret
3. Write the real values: `bws secret list` to get the IDs, then
   `bws secret edit <secret-id> --value <oauth-client-id-or-secret>`
4. `direnv reload` locally; in the cluster the `burrito-runner-cloud`
   ExternalSecret refreshes within 1h (delete the k8s secret to force it)
5. Revoke the old manual auth key in the
   [admin console](https://login.tailscale.com/admin/settings/keys)
   (the running node stays connected, keys only matter at join time)

## pre-reqs

- Oracle Cloud Account
- Tailscale Account
- GitHub Account /w SSH Keys configured

You don't need terraform installed locally, but you could do that.
We can use terraform from the Oracle Cloud UI.

## deploy

Clone the repo (or fork it):
```bash
git clone git@github.com:stealthybox/tf-oci-arm
cd tf-oci-arm
```

Create a secrets file (it's ignored in git)
```bash
cp secret.auto.tfvars.example secret.auto.tfvars
```

Update the secret values:
1. Update your `github_user` in the `secret.auto.tfvars` file
2. Create a Compartment for `tf-oci-arm`: https://cloud.oracle.com/identity/compartments  
   Copy the OCID of your new compartment  
   Update the config  
3. Create a Tailscale Auth Key: https://login.tailscale.com/admin/settings/authkeys  
   Copy the key  
   Update the config  

Now, create a Stack in Oracle Cloud: https://cloud.oracle.com/resourcemanager/stacks  
Upload your folder or zip it up first.  
(I have to use a zip personally, because WSL2 browser uploads are limited)

Copy your Compartment OCID into the field again.

Ack your values in the form.

Apply the Stack!

Hopefully it succeeds for you!  
It should if you made no changes to the cloud-init and your values are correct.

You should be able to `ssh oracle-arm` now from any machine with your private keys on your tailnet.
> if your local username doesn't match your github user, you'll need to `ssh ${GITHUB_USER}@oracle-arm`

## sudo

Once you're SSH'd in congrats. You can access any port of oracle-arm over your tailnet IP.

You won't have sudo access though because your user doesn't have a password yet.  
You can load your passwordhash through cloud-init or setup, NOPASSWD sudo.  
For now, I've settled on abusing the docker group to get a root shell to call `passwd` to manually set my
sudo password when I install my tools and shell config:
```bash
docker run -it --rm --pid host --privileged justincormack/nsenter1

passwd $(id -nu 1000)
exit

whoami
sudo whoami
```

## remote docker

Want to `docker run` arm64 containers remotely from your laptop?
Try out running NGINX or something:
```bash
GITHUB_USER=octocat

docker context create oracle-arm --docker "host=ssh://${GITHUB_USER}@oracle-arm"

DOCKER_CONTEXT=oracle-arm docker run --name nginx -d --rm -p 80:80 nginx

curl oracle-arm

DOCKER_CONTEXT=oracle-arm docker stop nginx
```
That's a private connection :)

## debugging

Very quickly after the terraform Stack succeeds, you should be able to SSH into your VM over tailscale.
If not, that's sad, and there's something wrong with your firewall config, or more likely, your tailscale key.
Maybe try minting a new tailscale key.

Alternatively, modify the Virtual Cloud Network's "Security List" to allow SSH on tcp/22 via the public IP, so you
can login over the internet and debug what's going wrong.

In this fork that fallback is built in: `terraform apply -var debug=true`
rebuilds the VM with SSH open on the public IP (security list + instance
iptables), reachable as `ssh <github_user>@<public-ip>` with your GitHub keys.
Check `/var/log/cloud-init-output.log` and `tailscale status` there. Re-apply
without the var to rebuild closed again.

## gotchas

If your Oracle Cloud Account is brand-new, you'll get free trial credits and
unlimited access to all API's for 30 days.
After that 30 days, if you don't add a billing method, your VM will be deleted
automatically, and you will lose your files.

You can re-create your VM with your new downgraded Free Account, and it will then
persist forever.

If you want to side-step this 30-day ticking time-bomb, you could probably just
add a credit card. Maybe you could even then remove it, but I can't test that theory.
I'm not sure if there's another way to invalidate the 30-day free credits other than
waiting.

An older version of this repo used `ufw` for the instance firewall instead of the
OCI VCN's Security List, but this turned out to be brittle for two reasons:
- 1. It was hard to get the firewalls to stop fighting each other, which made `ufw` unreliable
- 2. Docker's NAT rules and `ufw` don't easily fit together if `ufw` is set to default deny.

I just chose to stop using `ufw` and start managing the firewall /w terraform, but if you
really want to use `ufw`, you can try to confidently solve problem #1 and use
[chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker) to solve problem #2.

I left the default shell as zsh, sorry.
Fork and modify if you like :)

## resources
Tailscale has some docs on using the Oracle Cloud firewall + setting up Split DNS
https://tailscale.com/kb/1149/cloud-oracle/

This person's entire web log is lovely and they explain Oracle's iptables if you really want to try using `ufw`:
https://www.cflee.com/posts/oci-first-look-2/

This article details some of the oracle cloud service limits:
https://virtualizationreview.com/articles/2021/09/14/using-oracle-cloud.aspx
