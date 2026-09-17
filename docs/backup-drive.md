# Adding the external backup drive

You can set up the whole server **before** you have a backup drive. Until it
arrives:

- **Home Assistant automatic backups** still run — they land on the host at
  `/srv/appdata/ha-backups` (internal disk). That protects you against config
  mistakes and bad updates now, just not against the disk itself dying.
- **restic** (the versioned, off-the-disk backup) waits for the drive. Nothing
  else in the setup depends on it.

> ⚠️ Backups that live on the **same disk** as the data are not real backups —
> one drive failure loses both. So the steps below (a separate drive, or the
> B2 cloud option) are what actually protect you. Do them as soon as you can.

---

## Option A — plug in a USB/external drive (recommended)

When the drive arrives, run these **once** on the host.

1. **Find the drive** (identify it by size; note its partition, e.g. `sdb1`):
   ```bash
   lsblk
   ```

2. **Format it** — ⚠️ only if it's new/empty; this **erases** the drive:
   ```bash
   sudo mkfs.ext4 -L backup /dev/sdb1     # <-- replace sdb1 with yours
   ```
   (Skip this if the drive already has data you want to keep.)

3. **Mount it at `/mnt/backup`, permanently** (survives reboots):
   ```bash
   sudo mkdir -p /mnt/backup
   sudo blkid /dev/sdb1                    # copy the UUID it prints
   echo 'UUID=PASTE-UUID-HERE  /mnt/backup  ext4  defaults,nofail  0  2' | sudo tee -a /etc/fstab
   sudo mount -a
   sudo chown -R "$USER":"$USER" /mnt/backup
   ```
   `nofail` means the server still boots if the drive is ever unplugged.

4. **Point restic at it and initialise:**
   ```bash
   cd ~/HomeServer
   cp scripts/backup.env.example scripts/backup.env
   chmod 600 scripts/backup.env
   nano scripts/backup.env
   ```
   Set:
   ```
   RESTIC_REPOSITORY=/mnt/backup/restic-homeserver
   RESTIC_PASSWORD=a-long-passphrase-you-store-somewhere-safe
   ```
   Then:
   ```bash
   export $(grep -v '^#' scripts/backup.env | xargs) && restic init
   bash scripts/backup.sh
   ```

5. **Schedule it daily** (systemd timer) — see
   [`host-setup.md`](./host-setup.md) §9, or the setup guide's Backups phase.

6. **Test a restore once:**
   ```bash
   restic restore latest --target /tmp/restore-test
   ```

That's it — from then on, everything in `/srv/appdata` (including the Home
Assistant backups) is versioned onto the drive automatically.

---

## Option B — back up to the cloud now, no hardware (Backblaze B2)

If you'd rather have off-site backups **tonight** without waiting for a drive,
use Backblaze B2 (a few € a month for this data size). In `scripts/backup.env`:

```
RESTIC_REPOSITORY=b2:your-bucket-name:homeserver
B2_ACCOUNT_ID=xxxxxxxxxxxx
B2_ACCOUNT_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
RESTIC_PASSWORD=a-long-passphrase-you-store-somewhere-safe
```
Then `restic init` and `bash scripts/backup.sh` as above. You can add a local
drive later as a second copy (best practice is both: local for fast restores,
cloud for off-site).

---

## Later: the 3-2-1 goal

Aim for **3** copies, on **2** kinds of media, with **1** off-site. A great
zero-cost way to get the off-site copy: run `restic` to the **3500U laptop**
left at a family member's house (Tailscale + an SMB share or a second restic
repo). Ask and I can sketch that when you're ready.
