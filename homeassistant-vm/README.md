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

## Backups

HAOS has its own backup system (**Settings → System → Backups**) — snapshots
config *and* add-ons. Point it at a network share, or copy backups off the
VM regularly. This is separate from the Docker stack's `/srv/appdata` backup.

## Remote / phone access

Same as the rest of the stack: with **Tailscale**, the **Home Assistant
Companion app** reaches `http://<vm-ip>:8123` from anywhere. Give the VM its
own Tailscale node (the Tailscale add-on inside HAOS is the easy way) — see
[`docs/remote-access.md`](../docs/remote-access.md). (Home Assistant Cloud /
Nabu Casa is another paid option that also enables cloud-based voice
assistants.)
