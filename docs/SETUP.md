# Setup runbook — from bare laptop to running server

Follow these in order. Realistic time: **2–4 hours** for the core; the media
indexers and family onboarding can wait for another evening.

**Legend:** 🟢 core (do tonight) · 🔵 can wait · `<server-ip>` = your server's
LAN IP · `<user>` = your Linux username.

Before you start, have on hand:
- A **USB stick** (4 GB+) for the Debian installer, and a way to write it
  (balenaEtcher / Rufus / `dd`).
- Your **VPN provider's WireGuard key** (for qBittorrent). If you don't have a
  VPN yet, you can start the torrent stack later — everything else works now.
- An **external drive** (or a Backblaze B2 account) for backups.
- Your **phone** (for Tailscale) and your **laptop/desktop** to SSH from.

---

## Phase 1 — Install Debian 🟢

1. Download **Debian 12** netinstall ISO from https://www.debian.org/download
   and write it to the USB stick.
2. Boot the laptop from USB → **Graphical install**.
3. During install:
   - Create your user `<user>` (remember the password).
   - At **Software selection** (tasksel): tick **SSH server** and **standard
     system utilities**. **Untick any desktop environment.**
4. Reboot, remove USB, log in at the console.
5. Find your IP and note it:
   ```bash
   ip -4 addr | grep inet
   ```

## Phase 2 — Host prep & hardening 🟢

Do these from the laptop console, or SSH in from your main machine
(`ssh <user>@<server-ip>`). Full detail is in
[`host-setup.md`](./host-setup.md); the essentials:

6. **Update + basics:**
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo apt install -y curl git ufw unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades   # answer Yes
   ```
7. **Static address:** reserve this laptop's IP in your router's DHCP (bind to
   its MAC) so `<server-ip>` never changes. 🟢
8. **Don't sleep on lid close** (laptop!). Edit `/etc/systemd/logind.conf`:
   ```
   HandleLidSwitch=ignore
   HandleLidSwitchExternalPower=ignore
   HandleLidSwitchDocked=ignore
   ```
   ```bash
   sudo systemctl restart systemd-logind
   ```
9. **Free port 53** for AdGuard:
   ```bash
   sudo mkdir -p /etc/systemd/resolved.conf.d
   printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/adguard.conf
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   sudo systemctl restart systemd-resolved
   ```
10. **Docker:**
    ```bash
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    ```
    **Log out and back in** so the group takes effect.
11. **Tailscale:**
    ```bash
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up
    ```
    Open the login URL, authenticate. Note the server's Tailscale IP:
    `tailscale ip -4`.
12. **Firewall:**
    ```bash
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 53
    sudo ufw allow 80,443/tcp
    sudo ufw allow from 192.168.1.0/24 to any port 445   # set to YOUR subnet
    sudo ufw enable
    ```
13. **SSH lockdown** (after key login works from your main machine — run
    `ssh-copy-id <user>@<server-ip>` there first): in `/etc/ssh/sshd_config`
    set `PermitRootLogin no` and `PasswordAuthentication no`, then
    `sudo systemctl restart ssh`. 🔵 (fine to do after tonight)

## Phase 3 — Get the project & configure 🟢

14. **Create the data layout:**
    ```bash
    sudo mkdir -p /srv/appdata/ha-backups
    sudo mkdir -p /srv/data/torrents/{tv,movies,books}
    sudo mkdir -p /srv/data/media/{tv,movies,books}
    sudo chown -R "$USER":"$USER" /srv/appdata /srv/data
    ```
15. **Clone this repo:**
    ```bash
    git clone -b claude/youthful-rubin-pha6qn https://github.com/Bretting/HomeServer.git
    cd HomeServer
    ```
16. **Configure `.env`:**
    ```bash
    cp .env.example .env
    id           # note your uid/gid for PUID/PGID
    nano .env
    ```
    Set **all** of these:
    - `PUID` / `PGID` (from `id`), `TZ` (e.g. `Europe/Amsterdam`)
    - `LAN_SUBNET` (your real subnet, e.g. `192.168.1.0/24`)
    - VPN: `VPN_SERVICE_PROVIDER`, `WIREGUARD_PRIVATE_KEY`,
      `WIREGUARD_ADDRESSES`, `SERVER_COUNTRIES`
    - `SMB_USER` / `SMB_PASSWORD` (a fresh password, not your login)
    - `HOMEPAGE_ALLOWED_HOSTS` → `\<server-ip\>:3010` (+ `home.home.lan` later)
    - `MEALIE_BASE_URL` → `http://<server-ip>:9925`
17. **Point Scrutiny at your real disks:** run `lsblk`, then edit the
    `devices:` list under the `scrutiny` service in `docker-compose.yml`
    (e.g. `/dev/sda`, `/dev/sdb`; add `SYS_ADMIN` cap for NVMe).

## Phase 4 — Bring up the Docker stack 🟢

18. Start everything:
    ```bash
    docker compose up -d
    docker compose ps
    ```
    Give it a few minutes to pull images. All should show `running`/`healthy`.
19. Quick smoke test — open a couple in a browser:
    `http://<server-ip>:8096` (Jellyfin), `http://<server-ip>:5001` (Dockge).

## Phase 5 — Home Assistant VM 🟢

20. Create the HAOS VM (full detail in
    [`homeassistant-vm/README.md`](../homeassistant-vm/README.md)):
    ```bash
    sudo bash homeassistant-vm/install-haos-vm.sh
    # For LAN device discovery, create a bridge first and use:
    #   BRIDGE=br0 sudo -E bash homeassistant-vm/install-haos-vm.sh
    ```
21. Find its IP (`virsh domifaddr haos`) and open `http://<haos-ip>:8123`,
    complete onboarding.
22. Add-ons you'll likely want: **Settings → Add-ons → Store** → Mosquitto,
    ESPHome/Zigbee2MQTT (if you have devices), File editor, **Tailscale**
    (so the HA app works remotely).

## Phase 6 — First-run wiring 🔵 (can spread over a few evenings)

Follow the numbered **"First-run wiring"** list in the main
[`README.md`](../README.md): qBittorrent → Prowlarr (+FlareSolverr) → the *arr
apps (+Recyclarr) → Jellyfin → Kavita → Jellyseerr → AdGuard → Caddy → ntfy →
Uptime Kuma → Scrutiny → Homepage → Mealie.

Do at least **AdGuard** tonight so DNS + hostnames work:
23. `http://<server-ip>:3000` → wizard → set admin interface to port **80**.
    Admin then lives at `http://<server-ip>:8083`.
24. Add DNS rewrite `*.home.lan → <server-ip>`, and set your **router's DHCP
    DNS** to `<server-ip>` so the whole house gets ad-blocking + hostnames.

## Phase 7 — Backups 🟢 (don't skip)

25. **HA → host share:** in HA, **Settings → System → Storage → Add network
    storage**: server `<server-ip>`, share `ha-backups`, your `SMB_USER`/
    `SMB_PASSWORD`, usage **Backups**. Then **Settings → System → Backups →
    Automatic backups**: schedule daily, set an **encryption password** (save
    it!), target the share.
26. **restic:**
    ```bash
    sudo apt install -y restic
    cp scripts/backup.env.example scripts/backup.env
    chmod 600 scripts/backup.env
    nano scripts/backup.env        # repo location + a long password (SAVE IT)
    export $(grep -v '^#' scripts/backup.env | xargs) && restic init
    bash scripts/backup.sh         # first backup
    ```
27. **Schedule it:** add the systemd timer from
    [`host-setup.md`](./host-setup.md) §9 (`homeserver-backup.timer`).
28. 🔵 Later this week: **test a restore** (`restic restore latest --target
    /tmp/restore-test`). A backup you've never restored isn't a backup.

## Phase 8 — Your devices & family 🟢 for you, 🔵 for family

29. **Your phone/laptop:** install Tailscale (https://tailscale.com/download),
    log in with the same account. Then install the apps:
    - **Jellyfin** app → server `http://<server-ip>:8096`
    - **Home Assistant** Companion → `http://<haos-ip>:8123`
    - A book reader (or Kavita PWA) → `http://<server-ip>:5000`
    - **ntfy** app → subscribe to your alert topic
30. **Living-room TV (Chromecast w/ Google TV):** install **Jellyfin** and
    **Tailscale** from its Play Store, log in, add the server. (See
    [`remote-access.md`](./remote-access.md) §6.)
31. 🔵 **Family (wife, grandparents):** invite them in the Tailscale admin
    console, and set ACLs so they see only Jellyfin + Kavita. Details in
    [`remote-access.md`](./remote-access.md) §3–4.

## Done — verification checklist

- [ ] `docker compose ps` → all services running
- [ ] Jellyfin reachable at `:8096`; a test video plays
- [ ] HA onboarded at `:8123`; add-on store visible
- [ ] Tailscale: phone reaches the server away from home (toggle off Wi-Fi)
- [ ] AdGuard is the network DNS; `*.home.lan` resolves
- [ ] restic: `restic snapshots` shows a snapshot; timer enabled
- [ ] HA automatic backup ran and appears in `/srv/appdata/ha-backups`
- [ ] Uptime Kuma monitors up, ntfy alert received on phone

## If something's wrong

- Container won't start → `docker compose logs <name>`.
- Port 53 conflict → recheck Phase 2 step 9.
- No hardware transcoding → ensure `/dev/dri` exists and your user is in the
  `render`/`video` groups.
- qBittorrent has no internet → check `docker compose logs gluetun` (VPN creds).
- Out of disk → this is a fixed per-session allowance; clean caches/old images
  (`docker image prune`), don't assume hardware failure.
