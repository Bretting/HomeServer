# Cloudflare Tunnel — public access without open ports

This exposes **selected** services on real public URLs (e.g.
`https://books.example.com`) with **no port-forwarding** — `cloudflared`
makes an outbound connection to Cloudflare and holds it open, so your home
IP stays hidden and your router stays closed.

We expose **only Kavita (books)** here, behind a Cloudflare Access login.
Home Assistant stays on **Tailscale** for the Companion app (the app doesn't
play nicely behind an Access login page).

> ⚠️ Anything you route through the tunnel is on the public internet. Only
> add hostnames you intend to share, and always put **Cloudflare Access** in
> front. Never tunnel the *arr apps, qBittorrent, Dockge, or Dozzle.

## Prerequisites

1. A **domain name**.
2. The domain added to **Cloudflare** with DNS managed there (free plan):
   Cloudflare dashboard → *Add a site* → follow the nameserver change at your
   registrar. Wait until the domain shows **Active**.

## 1. Create the tunnel (token-managed)

1. Go to **Cloudflare dashboard → Zero Trust → Networks → Tunnels**
   (Zero Trust is free; you may be asked to pick the free plan once).
2. **Create a tunnel** → choose **Cloudflared** → name it e.g. `homeserver`.
3. On the "Install connector" screen, copy the **token** (the long string in
   the `--token ...` command). You don't need to run their install command —
   our `cloudflared` container uses the token.

## 2. Give the token to the container

In your `.env`:

```
CLOUDFLARE_TUNNEL_TOKEN=eyJ...your-token...
```

Then:

```bash
docker compose up -d cloudflared
docker compose logs -f cloudflared      # should show "Registered tunnel connection"
```

Back in the dashboard the tunnel should flip to **HEALTHY**.

## 3. Add the public hostname (route → Kavita)

In the tunnel's **Public Hostname** tab → **Add a public hostname**:

| Field | Value |
|---|---|
| Subdomain | `books` |
| Domain | `example.com` (yours) |
| Path | *(leave empty)* |
| Type | `HTTP` |
| URL | `kavita:5000` |

`cloudflared` reaches Kavita by its container name over the Docker network,
so `kavita:5000` is correct (not an IP). Save — `https://books.example.com`
is now live. Cloudflare handles the public HTTPS certificate automatically.

## 4. Lock it down with Cloudflare Access (do this!)

**Zero Trust → Access → Applications → Add an application → Self-hosted:**

- Application domain: `books.example.com`
- Add a **policy**: Action *Allow*, and a rule like
  *Emails* → your email address (and family members' emails).
- Login method: the built-in **One-time PIN** (emails a code) works with no
  extra setup; or wire up Google/GitHub.

Now visitors get a Cloudflare login *before* they can even see Kavita's login
page. Two doors instead of one.

> **Reader apps + Access:** a browser handles the Access login fine. Native
> OPDS reader apps can't do the interactive login, so for those either read
> in the browser (PWA), or create an Access **Service Token** / bypass for
> the OPDS path — see Cloudflare's "Service Auth" docs. Simplest is to use
> Tailscale for app-based reading and the tunnel for browser/sharing.

## Adding more later

Repeat step 3 for any other hostname, and step 4 to protect it. To expose
Home Assistant publicly later, route `home.example.com → <haos-vm-ip>:8123`
and rely on HA's own login + 2FA (or accept the Companion-app/Access
trade-off). Until then, HA stays on Tailscale.

## Turning it off

Remove the hostname in the dashboard, and either blank `CLOUDFLARE_TUNNEL_TOKEN`
in `.env` or comment out the `cloudflared` service, then `docker compose up -d`.
