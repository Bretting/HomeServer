#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Create a Home Assistant OS (HAOS) virtual machine with KVM/libvirt.
#
#  HAOS gives you the full Supervisor + one-click ADD-ON STORE, which the
#  plain Docker image cannot provide. It runs as a VM next to your Docker
#  stack; the two do not interfere with each other.
#
#  Run this on the Debian HOST (not inside a container):
#      sudo bash install-haos-vm.sh
#
#  Idempotent-ish: it refuses to clobber an existing VM of the same name.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Tunables (override via env, e.g. RAM_MB=4096 sudo -E bash ...) ───
VM_NAME="${VM_NAME:-haos}"
RAM_MB="${RAM_MB:-4096}"           # 2048 is fine; 4096 is comfortable
VCPUS="${VCPUS:-2}"
IMAGE_DIR="${IMAGE_DIR:-/var/lib/libvirt/images}"
BRIDGE="${BRIDGE:-}"               # e.g. br0 for LAN-bridged (recommended).
                                   # Leave empty to use libvirt NAT (default).

echo ">> Installing KVM / libvirt / tools ..."
apt-get update -qq
apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
  virtinst bridge-utils ovmf xz-utils curl jq

systemctl enable --now libvirtd

# ── Find the latest HAOS KVM (OVA/qcow2) image ───────────────────────
echo ">> Looking up the latest Home Assistant OS release ..."
LATEST="$(curl -fsSL https://api.github.com/repos/home-assistant/operating-system/releases/latest | jq -r .tag_name)"
if [[ -z "$LATEST" || "$LATEST" == "null" ]]; then
  echo "!! Could not determine latest release. Set HAOS_VERSION and re-run." >&2
  exit 1
fi
HAOS_VERSION="${HAOS_VERSION:-$LATEST}"
IMG_XZ="haos_ova-${HAOS_VERSION}.qcow2.xz"
URL="https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/${IMG_XZ}"
DEST="${IMAGE_DIR}/haos_ova-${HAOS_VERSION}.qcow2"

echo ">> Using HAOS ${HAOS_VERSION}"

if virsh dominfo "$VM_NAME" &>/dev/null; then
  echo "!! A VM named '$VM_NAME' already exists. Remove it first with:" >&2
  echo "     virsh destroy $VM_NAME ; virsh undefine $VM_NAME --nvram" >&2
  exit 1
fi

mkdir -p "$IMAGE_DIR"
if [[ ! -f "$DEST" ]]; then
  echo ">> Downloading $URL ..."
  curl -fL "$URL" -o "${DEST}.xz"
  echo ">> Decompressing ..."
  xz -d "${DEST}.xz"
else
  echo ">> Image already present at $DEST, skipping download."
fi

# ── Networking: bridged (recommended) or libvirt NAT (fallback) ──────
if [[ -n "$BRIDGE" ]]; then
  NET_ARG="--network bridge=${BRIDGE},model=virtio"
  echo ">> Network: bridged via ${BRIDGE} (HA will get a LAN IP)."
else
  NET_ARG="--network network=default,model=virtio"
  echo ">> Network: libvirt NAT (default). For reliable device discovery"
  echo "   and easy LAN access, set BRIDGE=br0 after creating a bridge."
fi

# ── Create the VM (UEFI + q35, importing the qcow2 disk) ─────────────
echo ">> Creating VM '$VM_NAME' ..."
virt-install \
  --name "$VM_NAME" \
  --machine q35 \
  --boot uefi \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --import \
  --disk "path=${DEST},format=qcow2,bus=virtio" \
  ${NET_ARG} \
  --graphics none \
  --os-variant generic \
  --noautoconsole \
  --autostart

cat <<EOF

════════════════════════════════════════════════════════════════════
 Home Assistant OS VM '$VM_NAME' created and set to start on boot.

 Find its IP:
     virsh domifaddr $VM_NAME          # (bridged)
   or check your router's DHCP leases  # (NAT: use http://homeassistant.local:8123)

 Open the onboarding UI:
     http://<vm-ip>:8123   (first boot takes a few minutes)

 Add-ons live under:  Settings > Add-ons > Add-on Store
 Popular ones: Mosquitto broker, Zigbee2MQTT, ESPHome, Node-RED,
               File editor, Terminal & SSH, Studio Code Server.

 USB stick (Zigbee/Z-Wave)? Pass it through:
     virsh attach-device $VM_NAME usb.xml --config   # see README
════════════════════════════════════════════════════════════════════
EOF
