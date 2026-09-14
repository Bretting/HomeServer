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
| **Dockge** | `dockge` | Compose-stack management UI | `:5001` |
| **Uptime Kuma** | `uptime-kuma` | Health checks + phone alerts | `:3001` |
| **Dozzle** | `dozzle` | Live container logs | `:8888` |
| **Watchtower** | `watchtower` | Auto-update containers | — |

## Prerequisites (on the host OS)

> **Home Assistant runs in a VM, not a container.** To get the add-on
> store you need Home Assistant OS (Supervisor), which runs as a KVM VM
> alongside this Docker stack. Set it up separately — see
> [`homeassistant-vm/README.md`](./homeassistant-vm/README.md).

Recommended OS: **Debian 12** (minimal, no desktop). Then:

```bash
# 1. Install Docker Engine + Compose plugin
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # log out/in afterward

# 2. Create the data layout (torrents + media on ONE filesystem so
#    the *arr apps can hardlink instead of copying files)
sudo mkdir -p /srv/appdata
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

> **Alternative — public URLs.** If you'd rather have real addresses like
> `home.example.com` with no VPN client on the phone, use a **Cloudflare
> Tunnel** instead of exposing ports. Only expose services you're happy to
> have on the public internet, always behind HTTPS + authentication.

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
4. **Jellyfin** (`:8096`) — add libraries pointing at `/media/tv`,
   `/media/movies`; enable VAAPI transcoding under Playback.
5. **Kavita** (`:5000`) — add a library at `/books`.
6. **Uptime Kuma** (`:3001`) — add a monitor for each service URL and
   connect a notification channel (Telegram/ntfy/etc.) for phone alerts.

## Backups (do this!)

`/srv/appdata` holds every service's config and database — losing it means
reconfiguring everything by hand. Back it up regularly, e.g.:

```bash
# stop, snapshot, restart (simple version)
docker compose stop
sudo tar czf /mnt/backup/appdata-$(date +%F).tar.gz /srv/appdata
docker compose start
```

Consider `restic` or `borg` to an external drive / cloud for versioned,
automated backups.

## Notes

- **AMD transcoding**: the `jellyfin` service maps `/dev/dri`; your user may
  need to be in the `render`/`video` group for hardware acceleration.
- **Readarr** uses the `develop` tag because it has no stable release yet.
- **Home Assistant** runs as a HAOS VM (for the add-on store), not a
  container — see [`homeassistant-vm/`](./homeassistant-vm/). Give the VM a
  bridged network for reliable device discovery.
- Legal reminder: only download content you're entitled to.
