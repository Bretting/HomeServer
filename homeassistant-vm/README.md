# Home Assistant OS (with add-ons) in a VM

You want the **add-on store**, which needs the Home Assistant **Supervisor**.
The Supervisor only ships with **Home Assistant OS (HAOS)**, not the plain
Docker image. So Home Assistant runs here as a **KVM virtual machine**,
side-by-side with the Docker stack in the parent folder. They don't interfere.

Budget ~2–4 GB RAM and ~32 GB disk for the VM — easy on your 16 GB laptop.

## Install

On the **Debian host** (not inside a container):

```bash
sudo bash install-haos-vm.sh
```

The script:
1. installs KVM/libvirt + tools,
2. finds and downloads the latest HAOS `qcow2` image,
3. creates a UEFI/q35 VM named `haos`, set to auto-start on boot.

Tunables (optional):

```bash
RAM_MB=2048 VCPUS=2 BRIDGE=br0 sudo -E bash install-haos-vm.sh
```

## Networking — bridged vs NAT

- **Bridged (recommended):** HA gets its own IP on your LAN, so device
  discovery (mDNS/Matter/HomeKit/DLNA) and inbound access work normally.
  Requires a Linux bridge on the host — see below. Then run with `BRIDGE=br0`.
- **NAT (default, zero-config):** works out of the box, but discovery is
  limited and you reach HA at `http://homeassistant.local:8123`. Fine to
  start with; switch to bridged later if discovery matters.

### Creating a bridge `br0` on Debian (for bridged mode)

Edit `/etc/network/interfaces` (replace `eth0` with your NIC from `ip a`):

```
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
```

Then `sudo systemctl restart networking` (do this at the machine or over a
connection that survives — bridging briefly drops the NIC).

## First run

1. Find the VM's IP:
   ```bash
   virsh domifaddr haos          # bridged
   ```
   or use `http://homeassistant.local:8123` (NAT).
2. Open `http://<vm-ip>:8123` and complete onboarding (first boot takes a
   few minutes while it downloads).
3. Add-ons: **Settings → Add-ons → Add-on Store**. Handy ones:
   - **Mosquitto broker** (MQTT), **Zigbee2MQTT**, **ESPHome**
   - **Node-RED** (automations), **File editor** / **Studio Code Server**
   - **Terminal & SSH**

## Passing through a Zigbee/Z-Wave USB stick

Find it: `lsusb` → note the vendor:product (e.g. `10c4:ea60`). Create `usb.xml`:

```xml
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x10c4'/>
    <product id='0xea60'/>
  </source>
</hostdev>
```

Attach it permanently:

```bash
virsh attach-device haos usb.xml --config
virsh reboot haos
```

## Managing the VM

```bash
virsh list --all            # status
virsh start haos            # start
virsh shutdown haos         # graceful stop
virsh console haos          # serial console (Ctrl+] to exit)
```

## Backups — full HA, folded into the restic set

HA lives inside this VM's disk, **not** in `/srv/appdata`, so the host's
restic job does not see it by default. Fix that by having HA write its own
**full backups** (config, dashboards, automations, users, **and every add-on
plus its data**) to the host, where restic then versions them and sends them
off-site. One backup system, HA included.

The Docker stack runs a small **Samba share** (`samba` service) exposing
`${CONFIG_ROOT}/ha-backups` as `\\<server-ip>\ha-backups`. Wire it up once:

1. In `.env`, set `SMB_USER` / `SMB_PASSWORD`, then `docker compose up -d samba`.
2. In HA: **Settings → System → Storage → Add network storage**
   - Name: `host-backups`; Server: `<server-ip>`; Share: `ha-backups`
   - Username/password: the `SMB_USER` / `SMB_PASSWORD` from `.env`
   - Usage: **Backups**
3. **Settings → System → Backups → ⋮ → Automatic backups**: set a schedule
   (e.g. daily), retention (e.g. keep 7), an **encryption password** (store it
   safely), and choose the `host-backups` location. Optionally keep one copy
   on the VM too.

Now every night HA drops a full archive into `/srv/appdata/ha-backups`, and
because restic backs up `/srv/appdata`, those archives are automatically
versioned and pushed to your restic repo — **HA is fully covered.**

**Restore:** install a fresh HAOS VM, and on the onboarding screen choose
*Restore from backup* (upload the archive + its encryption password) — you're
back exactly as you were, add-ons and all.

> **Zero-host-infra alternative:** the community **"Home Assistant Google
> Drive Backup"** add-on uploads full HA backups straight to Google Drive on a
> schedule, no Samba/restic involved. Use it instead if you'd rather not run
> the share.

> **Firewall:** the Samba share is for your LAN only — allow port 445 from
> your LAN subnet and nowhere else (see `docs/host-setup.md`).

## Remote / phone access

Same as the rest of the stack: with **Tailscale**, the **Home Assistant
Companion app** reaches `http://<vm-ip>:8123` from anywhere. Give the VM its
own Tailscale node (the Tailscale add-on inside HAOS is the easy way) — see
[`docs/remote-access.md`](../docs/remote-access.md). (Home Assistant Cloud /
Nabu Casa is another paid option that also enables cloud-based voice
assistants.)
