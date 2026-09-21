# Remote access — full Tailscale

Everything is reached over **Tailscale**, a WireGuard-based mesh VPN. Devices
connect **directly and end-to-end encrypted**; no ports are opened on your
router and nothing is exposed to the public internet. This covers you *and*
your family — the free Personal plan allows **6 users with unlimited
devices**.

- Nothing is public. No open ports, no reverse-proxy-to-the-internet, no
  Cloudflare. Your home IP stays hidden.
- Full quality: Jellyfin, Kavita and Home Assistant work at LAN speed/quality
  remotely, including hardware transcoding — no third party in the data path.

## 1. Install Tailscale on the host

On the Debian server (also in `docs/host-setup.md`):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Log in with an identity provider (Google/Microsoft/GitHub/email). The server
is now a node on your **tailnet**. Note its Tailscale IP (`100.x.y.z`) and
its MagicDNS name:

```bash
tailscale ip -4
tailscale status
```

Enable **MagicDNS** in the admin console (https://login.tailscale.com/admin/dns)
so you can use names like `http://homeserver:8096` instead of the IP.

## 2. Install the app on your devices

Get the client from https://tailscale.com/download (macOS, Windows, Linux,
iOS, Android, Apple TV). Log in with the same account → your phone/laptop
joins the tailnet and can reach the server from anywhere.

Point the native apps at the server's Tailscale name/IP:

| App | URL |
|---|---|
| Home Assistant Companion | `http://<host>:8123` (the HAOS VM's Tailscale/LAN IP) |
| Jellyfin (or Findroid/Swiftfin) | `http://<host>:8096` |
| Kavita / OPDS reader | `http://<host>:5000` |

> **Home Assistant VM note:** the HAOS VM is a separate machine, so give it
> its own Tailscale node — install Tailscale as an **add-on inside HAOS**
> (Settings → Add-ons → Tailscale), or run the VM bridged and add a
> **subnet route** (step 4) so the VM's LAN IP is reachable over the tailnet.

## 3. Family access (wife + grandparents)

Two ways, pick per person:

### a) Add them as users on your tailnet (free, up to 6 users)
Best for anyone comfortable installing an app. Invite them from the admin
console (**Users → Invite users**). They install Tailscale, log in, and reach
whatever your ACLs allow. Private and full quality — good for sharing Jellyfin
video too.

### b) Share a single machine with them (node sharing)
From the admin console you can **share** just the server node with an external
person's tailnet, so they don't join yours. They still install the app.
See: https://tailscale.com/kb/1084/sharing

> **No-install at all?** Tailscale can't give a plain public URL + login the
> way Cloudflare Access did. If a grandparent absolutely won't install an app,
> the choices are: help them install it once (it's a one-time login), or
> revisit a tunnel later. For now we're all-Tailscale.

## 4. Limit who can reach what (ACLs)

Control access per person in the admin console (**Access controls**). Keep the
admin/download tooling to yourself and share only the media/books apps with
family. Example sketch — adapt names to your tailnet:

```jsonc
{
  "groups": {
    "group:family": ["wife@example.com", "grandpa@example.com"]
  },
  "acls": [
    // You (owner) can reach everything.
    { "action": "accept", "src": ["autogroup:owner"], "dst": ["*:*"] },

    // Family can reach ONLY Jellyfin and Kavita on the server.
    {
      "action": "accept",
      "src": ["group:family"],
      "dst": ["<host-tailscale-ip>:8096", "<host-tailscale-ip>:5000"]
    }
  ]
}
```

This keeps Sonarr/Radarr/qBittorrent/Dockge/Dozzle invisible to family while
letting them stream and read. ACL reference:
https://tailscale.com/kb/1018/acls

## 5. Optional niceties

- **Subnet router** — advertise your home LAN (`192.168.1.0/24`) from the
  server so tailnet devices can reach *any* home device by LAN IP:
  `sudo tailscale up --advertise-routes=192.168.1.0/24` then approve it in the
  admin console. https://tailscale.com/kb/1019/subnets
- **Exit node** — route a device's full internet through home (e.g. on
  untrusted Wi-Fi). https://tailscale.com/kb/1103/exit-nodes
- **Taildrop** — send files phone↔server over the tailnet.
- **MagicDNS + HTTPS** — Tailscale can issue real certs for `*.ts.net` names
  if you ever want `https://` internally. https://tailscale.com/kb/1153/enabling-https

## 6. TV — Chromecast with Google TV (dongle)

Your TV dongle is a **Chromecast with Google TV** — that's full **Android TV**
with an app store, so don't bother "casting". Install apps on it directly:

1. On the dongle, open the **Play Store** and install:
   - **Jellyfin** (the official Android TV app)
   - **Tailscale** (it has an Android TV app)
2. Open **Tailscale** on the dongle → log in with your account → the TV joins
   your tailnet (it counts as one of your free user devices).
3. Open **Jellyfin** → add server `http://<host>:8096` (the server's Tailscale
   name/IP, or its LAN IP since the TV is usually on the same network) → sign
   in. Browse and play with the remote — proper direct play, no phone needed.

Because the dongle is on your tailnet, it works **the same at home or away**
(e.g. taking it to the grandparents' TV). No open ports, no casting hop.

- **Casting still works too** if you'd rather: from the Jellyfin phone app or
  the web UI, hit the Cast button while on the same Wi-Fi as the TV. But the
  installed app is the better experience.
- **Codecs/transcoding:** Google TV handles H.264 and usually H.265/4K, so
  most files direct-play. Anything it can't, Jellyfin transcodes using the
  server's **AMD VAAPI** hardware acceleration — no CPU meltdown.
- **ACL note:** if you lock family down with ACLs (step 4), remember the TV is
  one of *your* devices, so it already has full access — nothing extra needed.

## Sources

- Download (official): https://tailscale.com/download
- What is Tailscale: https://tailscale.com/kb/1151/what-is-tailscale
- Pricing / free plan: https://tailscale.com/pricing
- Sharing nodes: https://tailscale.com/kb/1084/sharing
- ACLs: https://tailscale.com/kb/1018/acls
