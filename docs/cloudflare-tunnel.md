# Cloudflare Tunnel — public access without open ports

This exposes **selected** services on real public URLs (e.g.
`https://books.example.com`) with **no port-forwarding** — `cloudflared`
makes an outbound connection to Cloudflare and holds it open, so your home
IP stays hidden and your router stays closed.

We expose **only Kavita (books)** here, behind a Cloudflare Access login, so
**family (e.g. wife, grandparents) can read from any browser with no app to
install** — they just open the URL and log in with an emailed code. Home
Assistant stays on **Tailscale** for the Companion app (the app doesn't play
nicely behind an Access login page).

> **Why not Tailscale for the family?** Tailscale needs the app installed and
> an account on every device — fine for you, friction for grandparents.
> Tailscale *Funnel* can make a public URL but adds no login of its own.
> Cloudflare Tunnel + Access gives the "just a URL + a login" experience
> non-technical people expect. Use Tailscale for yourself, the tunnel for
> sharing.

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
- Add a **policy**: Action *Allow*, rule type **Emails**, and list **every
  family member's email address** (yours, your wife's, each grandparent's).
- Login method: leave the built-in **One-time PIN** on — Cloudflare emails a
  6-digit code, so there's **nothing to install and no password to remember**.
  Ideal for non-technical family. (You *can* add Google/GitHub too.)
- Optional: set the session duration longer (e.g. **1 month**) under the
  policy so they don't have to re-enter a code often.

Now anyone opening the URL gets a Cloudflare login *before* they can even see
Kavita — and only the emails you listed get in.

### Family experience, end to end

1. You send grandma `https://books.example.com`.
2. She opens it → "enter your email" → she types hers → gets a code by email
   → types the code. (No app, no account signup.)
3. She lands in Kavita and reads in the browser. On phones she can "Add to
   Home Screen" so it behaves like an app (PWA).

### Kavita accounts for each person

Cloudflare Access controls *who reaches the site*; Kavita still has its own
login. Two clean options:

- **Simple:** in Kavita (**Settings → Users → Invite**) create one account
  per person with a simple password, and set what libraries each can see.
- **Even simpler for grandparents:** give them a single shared read-only
  Kavita account. Since Access already verified their identity at the door,
  the shared login is just a formality.

> **Reader apps + Access:** a browser/PWA handles the Access login fine (what
> your family will use). Native OPDS reader *apps* can't do the interactive
> login — for those use Tailscale, or create an Access **Service Token** for
> the OPDS path (Cloudflare "Service Auth" docs). Family in a browser: no
> issue.

## Adding more later

Repeat step 3 for any other hostname, and step 4 to protect it. To expose
Home Assistant publicly later, route `home.example.com → <haos-vm-ip>:8123`
and rely on HA's own login + 2FA (or accept the Companion-app/Access
trade-off). Until then, HA stays on Tailscale.

## Turning it off

Remove the hostname in the dashboard, and either blank `CLOUDFLARE_TUNNEL_TOKEN`
in `.env` or comment out the `cloudflared` service, then `docker compose up -d`.
