# Host setup & hardening (Debian 12)

One-time steps to make the server reliable, secure, and unattended. Do these
on the Debian host after a fresh minimal install, before/around bringing the
Docker stack up.

## 0. Base install choices

- Install **Debian 12**, netinstall/minimal. **No desktop environment** —
  select only "SSH server" and "standard system utilities" in tasksel.
- Create your user; you'll disable root SSH below.

## 1. Static IP (so the address never changes)

A server and a DNS server both need a fixed address. Either reserve it in
your router's DHCP (bind to the laptop's MAC — easiest), or set it on the
host. Note the IP; it's used everywhere (`<server-ip>`).

## 2. Automatic security updates

```bash
sudo apt-get update && sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # answer "Yes"
```

This patches the OS itself. Watchtower (in the stack) updates containers;
HAOS updates itself.

## 3. SSH lockdown

Set up key-based login from your main machine first (`ssh-copy-id user@<server-ip>`),
then in `/etc/ssh/sshd_config`:

```
PermitRootLogin no
PasswordAuthentication no
```

```bash
sudo systemctl restart ssh
```

## 4. Firewall

```bash
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 53          # AdGuard DNS
sudo ufw allow 80,443/tcp  # Caddy
# If NOT using Tailscale and you expose services directly, also open the
# specific service ports you need. With Tailscale you generally don't.
sudo ufw enable
```

Tailscale manages its own interface and works alongside ufw.

## 5. Free up port 53 for AdGuard Home

Debian's `systemd-resolved` may hold port 53. Disable its stub listener so
AdGuard can bind it:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/adguard.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

After AdGuard is running, point your router's DHCP DNS at `<server-ip>` so
the whole network gets ad-blocking. Add a DNS rewrite in AdGuard:
`*.home.lan -> <server-ip>` so the Caddy hostnames resolve.

## 6. Laptop: don't sleep when the lid closes

Critical for a laptop server. In `/etc/systemd/logind.conf`:

```
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

```bash
sudo systemctl restart systemd-logind
```

Leave the battery in — it acts as a mini-UPS against brief power cuts. If you
want graceful shutdown on real outages later, add a real UPS + `nut`.

## 7. Docker + the stack

Follow the main [README](../README.md): install Docker, create `/srv/data`
and `/srv/appdata`, `cp .env.example .env`, edit it, `docker compose up -d`.

## 8. Home Assistant VM

See [homeassistant-vm/README.md](../homeassistant-vm/README.md).

## 9. Backups — schedule restic

Set up per [scripts/backup.sh](../scripts/backup.sh), then automate with a
systemd timer (runs daily at 03:30):

`/etc/systemd/system/homeserver-backup.service`
```ini
[Unit]
Description=Home server restic backup
[Service]
Type=oneshot
ExecStart=/usr/bin/bash /path/to/HomeServer/scripts/backup.sh
```

`/etc/systemd/system/homeserver-backup.timer`
```ini
[Unit]
Description=Daily home server backup
[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now homeserver-backup.timer
```

**Test a restore** at least once — a backup you've never restored isn't a
backup. `restic restore latest --target /tmp/restore-test`.

## Reliability checklist

- [ ] Static IP set
- [ ] `unattended-upgrades` on
- [ ] SSH key-only, root login off
- [ ] `ufw` enabled
- [ ] `systemd-resolved` stub off (port 53 free for AdGuard)
- [ ] Lid-close = ignore
- [ ] Docker stack up (`docker compose ps` all healthy)
- [ ] HAOS VM auto-starts (`virsh list --all`)
- [ ] restic timer enabled **and a restore tested**
- [ ] Uptime Kuma monitoring each service with a phone notification channel
