# Home Server

Self-hosted stack for an old laptop (16 GB RAM, AMD CPU) running Docker.
Everything is defined in [`docker-compose.yml`](./docker-compose.yml).

## What's in the box

| Service | Container | What it does | Access |
|---|---|---|---|
| **Home Assistant** | *VM (HAOS)* | Home automation **+ add-on store** | `:8123` — via **Companion app** |
| **Jellyfin** | `jellyfin` | Media server (HW transcoding) | `:8096` — via **Jellyfin app** |
| **Kavita** | `kavita` | Read books on your phone (OPDS) | `:5000` — via reader apps |
| **qBittorrent** | `qbittorrent` | Torrent client (behind VPN) | `:8080` |
| **Gluetun** | `gluetun` | VPN tunnel for all torrent traffic | — |
| **Prowlarr** | `prowlarr` | Indexer manager (feeds the *arr apps) | `:9696` |
| **Sonarr** | `sonarr` | Auto-grab TV shows | `:8989` |
| **Radarr** | `radarr` | Auto-grab movies | `:7878` |
| **Readarr** | `readarr` | Auto-grab books → Kavita | `:8787` |
| **Bazarr** | `bazarr` | Auto-download subtitles | `:6767` |
| **Jellyseerr** | `jellyseerr` | Family media **request page** → *arr | `:5055` |
| **FlareSolverr** | `flaresolverr` | Helps Prowlarr reach protected indexers | `:8191` |
| **Recyclarr** | `recyclarr` | Auto quality profiles for Sonarr/Radarr | — |
| **Caddy** | `caddy` | Reverse proxy — `https://name.home.lan` | `:80` / `:443` |
| **AdGuard Home** | `adguardhome` | Network-wide ad-block + local DNS | `:3000` setup → `:8083` |
| **Samba** | `samba` | Backup share for the HA VM (LAN only) | `:445` |
| **Homepage** | `homepage` | Dashboard linking every service | `:3010` |
| **Uptime Kuma** | `uptime-kuma` | Health checks + phone alerts | `:3001` |
| **ntfy** | `ntfy` | Self-hosted push notifications | `:8085` |
| **Scrutiny** | `scrutiny` | Disk SMART-health monitoring | `:8084` |
| **Mealie** | `mealie` | Family recipe manager | `:9925` |
| **Dockge** | `dockge` | Compose-stack management UI | `:5001` |
| **Dozzle** | `dozzle` | Live container logs | `:8888` |
| **Watchtower** | `watchtower` | Auto-update containers | — |

Host-level setup (OS install, hardening, backups, laptop lid, port 53) lives
in **[`docs/host-setup.md`](./docs/host-setup.md)** — do that alongside this.

## Prerequisites (on the host OS)

> **Home Assistant runs in a VM, not a container.** To get the add-on
> store you need Home Assistant OS (Supervisor), which runs as a KVM VM
> alongside this Docker stack. Set it up separately — see
> [`homeassistant-vm/README.md`](./homeassistant-vm/README.md).

Recommended OS: **Debian 12** (minimal, no desktop) — stable, light, and the
best-supported base for Docker + KVM. See
[`docs/host-setup.md`](./docs/host-setup.md) for the full hardening/reliability
walkthrough (static IP, auto-updates, SSH, firewall, freeing port 53 for
AdGuard, laptop lid behavior). Then:

```bash
# 1. Install Docker Engine + Compose plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # log out/in afterward

# 2. Create the data layout (torrents + media on ONE filesystem so
#    the *arr apps can hardlink instead of copying files)
sudo mkdir -p /srv/appdata/ha-backups   # HAOS drops its backups here
sudo mkdir -p /srv/data/torrents/{tv,movies,books}
sudo mkdir -p /srv/data/media/{tv,movies,books}
sudo chown -R "$USER":"$USER" /srv/appdata /srv/data
```

## Getting the phone / remote access ("app-like") working

You wanted the official apps to work whether you're home or on the train,
**without** poking holes in your router. Install **Tailscale on the host**:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Then install the Tailscale app on your phone and log in with the same
account. Your phone is now on the same private network as the server, so:

- **Home Assistant** → install the *Home Assistant Companion* app, point it
  at `http://<haos-vm-ip>:8123` (set up per
  [`homeassistant-vm/README.md`](./homeassistant-vm/README.md)).
- **Jellyfin** → install the *Jellyfin* app (or Findroid/Swiftfin), server
  URL `http://<tailscale-ip>:8096`.
- **Books** → install a reader with OPDS support (e.g. *Moon+ Reader*,
  *KyBook*, *Cantook*) and point it at Kavita's OPDS feed, or just use
  Kavita's installable web app (PWA) at `http://<tailscale-ip>:5000`.

**Family (wife, grandparents)** join the same way — the free plan allows up to
6 users. Add them in the Tailscale admin console and use ACLs to share only
Jellyfin + Kavita with them. Full walkthrough (users, node sharing, ACLs,
subnet routes) in [`docs/remote-access.md`](./docs/remote-access.md).

## Start it up

```bash
cp .env.example .env
nano .env            # set PUID/PGID, timezone, paths, and your VPN key
docker compose up -d
docker compose ps
```

Manage everything from then on in the **Dockge** UI at `:5001`.

## First-run wiring (once)

1. **qBittorrent** — get the temp password from `docker compose logs qbittorrent`,
   log in at `:8080`, change it. Set the default save path to `/data/torrents`.
2. **Prowlarr** (`:9696`) — add your indexers/trackers, then add Sonarr,
   Radarr and Readarr as "Apps" so indexers sync automatically.
3. **Sonarr/Radarr/Readarr** — add qBittorrent as the download client
   (host `gluetun`, port `8080`), and set root folders to
   `/data/media/tv`, `/data/media/movies`, `/data/media/books`.
   - In **Prowlarr**, add a **FlareSolverr** proxy at `http://flaresolverr:8191`
     and tag the indexers that need it.
   - **Recyclarr**: `docker compose run --rm recyclarr config create`, then
     edit `${CONFIG_ROOT}/recyclarr/recyclarr.yml` with each app's URL + API
     key. It syncs quality profiles daily.
4. **Jellyfin** (`:8096`) — add libraries pointing at `/media/tv`,
   `/media/movies`; enable VAAPI transcoding under Playback.
5. **Kavita** (`:5000`) — add a library at `/books`.
6. **Jellyseerr** (`:5055`) — connect to Jellyfin, then to Radarr & Sonarr.
   Invite family so they can request movies/shows themselves.
7. **AdGuard Home** (`:3000`) — run the setup wizard; set the admin interface
   to port 80 (→ host `:8083`). Then add a DNS rewrite `*.home.lan ->
   <server-ip>`, and point your router's DHCP DNS at `<server-ip>`.
8. **Caddy** — once AdGuard resolves `*.home.lan`, reach every UI by name,
   e.g. `https://jellyfin.home.lan`. Edit [`caddy/Caddyfile`](./caddy/Caddyfile)
   to add/change hosts.
9. **ntfy** (`:8085`) — pick a hard-to-guess topic name, subscribe to it in
   the ntfy phone app.
10. **Uptime Kuma** (`:3001`) — add a monitor for each service URL and set the
    notification channel to **ntfy** (URL `http://ntfy:80`, your topic).
11. **Scrutiny** (`:8084`) — edit the `devices:` list for `scrutiny` in the
    compose file to match your disks (`lsblk`); it then tracks SMART health.
12. **Homepage** (`:3010`) — edit `${CONFIG_ROOT}/homepage/services.yaml` to
    list your services. This is your daily landing page.
13. **Mealie** (`:9925`) — create the admin account; import recipes by URL.

## Backups (do this!)

`/srv/appdata` holds every service's config and database — losing it means
reconfiguring everything by hand. Use the included **restic** script for
versioned, encrypted, automated backups to an external drive or cloud:

```bash
sudo apt-get install -y restic
cp scripts/backup.env.example scripts/backup.env   # edit: repo + password
chmod 600 scripts/backup.env
export $(grep -v '^#' scripts/backup.env | xargs) && restic init
bash scripts/backup.sh
```

Schedule it daily with the systemd timer in
[`docs/host-setup.md`](./docs/host-setup.md), and **test a restore once**.

**Home Assistant is included too:** HAOS writes its full nightly backups to a
Samba share on the host (`/srv/appdata/ha-backups`), which restic then sweeps
off-site — so config, add-ons and all are covered. Setup is in
[`homeassistant-vm/README.md`](./homeassistant-vm/README.md) → Backups.

## Notes

- **AMD transcoding**: the `jellyfin` service maps `/dev/dri`; your user may
  need to be in the `render`/`video` group for hardware acceleration.
- **Readarr** uses the `develop` tag because it has no stable release yet.
- **Home Assistant** runs as a HAOS VM (for the add-on store), not a
  container — see [`homeassistant-vm/`](./homeassistant-vm/). Give the VM a
  bridged network for reliable device discovery.
- Legal reminder: only download content you're entitled to.
