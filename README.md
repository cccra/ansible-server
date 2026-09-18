# nas-setup

My Ansible NAS setup. One playbook (`run.yml`) takes a bare Ubuntu box and turns it
into a self-hosted NAS/homelab server: base system, storage (MergerFS + SnapRAID),
security hardening, and 35 services that each run as a Docker container behind a
reverse proxy.

Everything is off by default. You pick what you want with `enable_*` flags in your own
variable file, and re-running the playbook adds, updates, or tears down services to
match.

## What you get

### Media

- **[Jellyfin](https://jellyfin.org/)** — film and TV streaming, with NVIDIA hardware transcoding
- **[Navidrome](https://www.navidrome.org/)** — music streaming
- **[Audiobookshelf](https://www.audiobookshelf.org/)** — audiobooks and podcasts
- **[OpenReader](https://github.com/richardr1126/openreader)** — ebook reader with GPU text-to-speech
- **[Tdarr](https://tdarr.io/)** — automated library transcoding
- **[Jellyseerr](https://github.com/seerr-team/seerr)** — media requests
- **[Wizarr](https://github.com/wizarrrr/wizarr)** — Jellyfin invitations and onboarding

### Acquisition

- **[Sonarr](https://sonarr.tv/)** / **[Radarr](https://radarr.video/)** / **[Lidarr](https://lidarr.audio/)** / **[LazyLibrarian](https://lazylibrarian.gitlab.io/)** — TV, film, music and book automation
- **[Prowlarr](https://prowlarr.com/)** — indexer management for all of the above
- **[Bazarr](https://www.bazarr.media/)** — subtitles
- **[FlareSolverr](https://github.com/FlareSolverr/FlareSolverr)** — Cloudflare challenge solver for Prowlarr
- **[Unpackerr](https://unpackerr.zip/)** — extracts completed downloads
- **[qBittorrent](https://www.qbittorrent.org/)** — torrents, forced through a WireGuard tunnel
- **[neko](https://neko.m1k1o.net/)** — a Chromium in a web page that browses through that same tunnel, via qBittorrent's Privoxy

### Files and documents

- **[Nextcloud](https://nextcloud.com/)** — file sync and share
- **[Immich](https://immich.app/)** — photo and video backup
- **[Paperless-ngx](https://docs.paperless-ngx.com/)** — document scanning, OCR and archive
- **[linkding](https://github.com/sissbruecker/linkding)** — bookmarks
- **[Wallabag](https://wallabag.org/)** — read-later

### Personal

- **[Vaultwarden](https://github.com/dani-garcia/vaultwarden)** — Bitwarden-compatible password manager
- **[Gitea](https://about.gitea.com/)** — self-hosted git
- **[Grocy](https://grocy.info/)** — groceries and household management
- **[Tandoor](https://docs.tandoor.dev/)** — recipes and meal planning
- **[Gramps](https://www.gramps-project.org/)** — genealogy
- **[Invoice Ninja](https://invoiceninja.com/)** — invoicing

### Infrastructure

- **[nginx-proxy-manager](https://nginxproxymanager.com/)** — reverse proxy and TLS for everything else
- **[AdGuard Home](https://adguard.com/adguard-home/overview.html)** — network-wide DNS and ad blocking
- **[WireGuard](https://www.wireguard.com/)** — VPN server, with a web UI for peer management
- **[Watchtower](https://github.com/containrrr/watchtower)** — automatic container updates
- **[Homarr](https://homarr.dev/)** — dashboard
- **[dash.](https://getdashdot.com/)** — system metrics
- **Cloudflare DDNS** — keeps your DNS records pointed at a changing home IP

Underneath that: MergerFS pooling the data disks into `/mnt/storage`, SnapRAID parity
with a weekly sync, SMART monitoring, hd-idle spindown, email alerts, SSH hardening,
fail2ban, CrowdSec, and an iptables firewall that keeps published container ports
LAN-only unless you say otherwise.

## Requirements

**Control machine** (where you run Ansible — your laptop, not the server):
ansible-core **2.15 or newer**; 2.21 is what this is developed against.

**Target host**: Ubuntu Server, reachable over SSH as a user who can `sudo`. A freshly
imaged box works — the playbook probes for the SSH port and falls back through port 22
and the default Raspberry Pi and root credentials, so the same command works before and
after hardening. `upload_iso.yml` will build and upload an autoinstall Ubuntu ISO if
you need to bring the box up in the first place.

If you want the storage stack you need the data disks labelled and present; if you want
hardware transcoding you need an NVIDIA card (the driver and container toolkit are
installed for you, and the host is rebooted if a kernel update requires it). On a host
without one, set `enable_nvidia: false`.

## Getting started

**1. Install Ansible.**

```bash
sudo pacman -S ansible     # Arch
sudo apt install ansible   # Debian/Ubuntu
brew install ansible       # macOS
```

**2. Clone the repo and install the dependencies.** This pulls both the external roles
and the collections the playbook needs (`community.docker`, `community.general`,
`ansible.posix`):

```bash
git clone https://github.com/cccra/ansible-server
cd ansible-server
ansible-galaxy install -r requirements.yml
```

**3. Add your inventory.**

```bash
cp hosts_example hosts
$EDITOR hosts
```

**4. Create a variable file for your host.** The directory name must match the
inventory name you used in `hosts`:

```bash
mkdir -p group_vars/YOUR_INVENTORY_NAME
$EDITOR group_vars/YOUR_INVENTORY_NAME/vars.yml
```

A minimal one looks like this — override anything from `group_vars/all/vars.yml`, and
switch on the services you want:

```yaml
username: yourname
timezone: Europe/London
lan_network: "192.168.1.0/24"
lan_address: "192.168.1.136"

enable_iptables: true
enable_fail2ban: true
enable_nas_stuff: true

enable_container_nginx_proxy_manager: true
enable_container_jellyfin: true
enable_container_vaultwarden: true
```

**5. Set up the vault.** Store the Ansible Vault password in
[`pass`](https://www.passwordstore.org/) under the key `homeserver_ansible_secret`.
`pass.sh` reads it from there every time Ansible asks (wired up via
`vault_password_file` in `ansible.cfg`), so you never pass `--ask-vault-pass`:

```bash
pass insert homeserver_ansible_secret
ansible-vault create group_vars/YOUR_INVENTORY_NAME/vault.yml
```

At minimum the vault needs `host` (your base domain), `ssh_public_key`, `password` and
`email_password`. Each service you enable may need more — the block at the bottom of
`group_vars/all/vars.yml` lists every variable and which service wants it. They are
deliberately left undefined so a fresh clone fails loudly instead of deploying a known
password.

**6. Run it.**

```bash
ansible-playbook run.yml -l your-host -K
```

`-K` prompts for the sudo password and is only needed on the first run, since the
playbook then configures passwordless sudo for your login user. Expect the first run to
take a while and to reboot the host if a kernel or NVIDIA driver update lands.

## Everyday use

| Task | Command |
|---|---|
| Full run | `ansible-playbook run.yml -l your-host` |
| Redeploy all containers | `ansible-playbook run.yml -l your-host --tags containers` |
| Redeploy one service | `ansible-playbook run.yml -l your-host --tags containers -e service_filter=jellyfin` |
| Redeploy several | `... -e service_filter=sonarr,radarr,prowlarr` |
| Pull new images during the run | `... --tags containers -e container_pull=always` |
| Run one role | `ansible-playbook run.yml -l your-host --tags mergerfs` |
| Dry run, showing changes | `ansible-playbook run.yml -l your-host --check --diff` |
| Syntax check only | `ansible-playbook run.yml --syntax-check` |
| Debug a failing task | add `-vvv` |

A few things worth knowing about those:

- **`service_filter`** exists because every service is deployed by one role in a loop,
  and an Ansible tag cannot select an item inside a loop. So there is no `--tags
  jellyfin`; you pass the service name as a variable instead. It takes a
  comma-separated list and must be combined with `--tags containers`.
- **`container_pull`** defaults to `missing`, so a normal run only pulls images it
  doesn't already have — routine updates are Watchtower's job, not the playbook's.
  Setting it to `always` forces a pull, which is what you want when you have changed an
  image tag or want to jump ahead of Watchtower's schedule.
- **Removing a service** is the same as adding one: set its flag to `false` and re-run
  with `--tags containers`. The flags are the source of truth, so the container is
  actually stopped and removed rather than left orphaned. Its data under
  `/opt/docker/data/<name>` is left alone.
- **The SSH port probe** is tagged `always`, so it runs on every invocation whether or
  not you passed `--tags`, and never needs to be requested explicitly.
- **Every role has a tag matching its name** (`system`, `docker`, `mergerfs`,
  `snapraid`, `iptables`, `nvidia`, ...).

## Reaching your services

Almost nothing publishes a port. 30 of the 35 services are marked `proxied: true` and
are reached through nginx-proxy-manager, which terminates TLS and routes by hostname —
so you point a wildcard DNS record at the box, add a proxy host in the NPM admin UI on
port 81, and the service answers at `https://<name>.<your domain>`.

Only these publish a port directly:

| Service | Port | Bound to |
|---|---|---|
| nginx-proxy-manager | 80, 443 | all interfaces |
| WireGuard | 51820/udp | all interfaces |
| Gitea SSH | 222 | all interfaces |
| neko WebRTC | `neko_webrtc_port` (59000) tcp/udp | all interfaces |
| nginx-proxy-manager admin | 81 | `lan_address` |
| AdGuard Home | 53 tcp/udp, 3030 | `lan_address` |
| qBittorrent (Privoxy) | 8118 | `lan_address` |

**Binding to all interfaces does not make a port reachable from the internet.** With
`enable_iptables: true`, the `DOCKER-USER` chain accepts traffic from `lan_network` and
drops everything else, so by default — `docker_wan_ports` is empty — even 80 and 443
answer only on the LAN. Publishing the proxy to the internet means listing its ports
explicitly:

```yaml
docker_wan_ports: [80, 443]
```

Note that the generated rules are TCP-only, so WireGuard's UDP port cannot be opened
this way. Container ports need their own chain because they bypass `INPUT` entirely —
Docker DNATs them through `FORWARD` — so `DOCKER-USER` is the only place they can be
filtered. Ports bound to `lan_address` are LAN-only regardless, firewall or not.

### Browsing through the VPN

neko streams a real Chromium into a web page over WebRTC, and that Chromium is pinned
by policy to Privoxy in the qbittorrent container, so everything it loads leaves through
the WireGuard tunnel and pages render exactly as they would locally. The page asks for
a password before it shows anything.

To enable it: set `enable_container_neko: true` alongside `enable_container_qbittorrent`,
put `neko_user_password` and `neko_admin_password` in the vault, and add a proxy host in
NPM pointing `neko.<your domain>` at `http://neko:8080` with *Websockets Support* on.
Then log in with any username and the user password (the admin password gets the admin
role), and browse.

The video itself cannot go through NPM, because WebRTC is not HTTP. It uses
`neko_webrtc_port` instead, published on UDP and TCP. From the LAN that just works. From
the internet, add the port to `docker_wan_ports` (the hook warns if you forget), forward
it on the router, and ICE falls back to TCP since the generated rules are TCP-only.
neko looks its public IP up at startup and hands that to every client, so LAN use then
depends on the router hairpinning; for an instance you only ever use from the LAN, set
`neko_webrtc_nat1to1` to `lan_address` instead.

The proxy is a Chromium policy rather than a flag, so it cannot be changed from inside
the browser, there is no bypass list, and WebRTC inside the page is held to the proxy
too. The profile is not persisted: each recreation of the container starts clean.
Expect a couple of CPU cores and around 2 GB of RAM while a session is open, since the
video is encoded in software.

## How it's put together

| Path | What it is |
|---|---|
| `run.yml` | The one playbook. Lists every role unconditionally, each gated by a `when:` |
| `group_vars/all/vars.yml` | Committed defaults, all `enable_*` flags `false` |
| `services/<name>/` | One directory per container service — data, not tasks |
| `roles/container` | The single engine that deploys every service |
| `roles/container-fleet` | Networks, teardown of disabled services, persistent data |
| `roles/system`, `roles/docker`, `roles/nvidia`, `roles/neovim` | Base host setup |
| `roles/filesystems/*` | MergerFS, mounts, hd-idle, the SnapRAID pre-sync backup |
| `roles/security/*` | fail2ban, iptables, CrowdSec |
| `tasks/` | Shared task files included by roles (`repo_arch.yml`, `ssh_juggle_port.yml`) |

External roles from `requirements.yml` cover the cross-cutting base config:
`geerlingguy.security` (SSH hardening, passwordless sudo, unattended upgrades),
`geerlingguy.ntp`, `chriswayg.msmtp-mailer` (SMART/SnapRAID alert mail),
`oefenweb.dns`, `stuvusit.smartd`, `ironicbadger.snapraid`, `bertvv.samba`.

On the host: persistent service config lives under `/opt/docker/data/<name>`
(`docker_dir`), and media and bulk data under `/mnt/storage` (`mergerfs_root`).

### Variables

Everything is gated by `enable_*` flags, all `false` in `group_vars/all/vars.yml`.
Container services use the `enable_container_<name>` namespace; the rest
(`enable_nas_stuff`, `enable_fail2ban`, `enable_iptables`, `enable_crowdsec`,
`enable_powersaving`, ...) are bare `enable_<thing>`. Turn something on by overriding
its flag in your own file — never by editing the role list in `run.yml`.

| File | Purpose | Tracked in git |
|---|---|---|
| `group_vars/all/vars.yml` | Committed defaults. Do not put host config here. | yes |
| `group_vars/<name>/vars.yml` | Per-environment overrides | no |
| `group_vars/<name>/vault.yml` | Secrets, ansible-vault encrypted | no |

Flags worth knowing about:

- `enable_nas_stuff` gates the whole storage stack: `filesystems/mergerfs`,
  `filesystems/mounts`, `filesystems/hd-idle`, `stuvusit.smartd` and
  `ironicbadger.snapraid`. Parity, disk lists and the weekly snapraid-runner cron —
  which stops the containers, rsyncs `/opt/docker/data` to the array, then syncs — are
  all configured in `group_vars/all/vars.yml`.
- `enable_nvidia` defaults to on whenever a GPU-consuming service (jellyfin, immich,
  tdarr, openreader) is enabled. Set it to `false` on a host with no NVIDIA card:
  `roles/nvidia` is skipped and those services deploy without their GPU request, which
  a Docker daemon with no NVIDIA runtime would refuse to create.
- `enable_ipv6` is `false`. IPv6 is disabled in the kernel and shut at the firewall;
  `nas-firewall.sh` only filters IPv4, so turning it on leaves the v6 side unfiltered.
- `docker_wan_ports` lists the published container ports reachable from the internet.

### Adding a service

Three edits:

**1. Create `services/<name>/service.yml`**, a list of
[`community.docker.docker_container`](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html)
parameters exactly as the module documents them — there is no schema to translate into,
and a parameter the engine has never seen passes straight through.

**2. Register it in `group_vars/all/vars.yml`** by adding the flag, off:

Not necessary, but this is the authorititive list of variables.

**3. Switch it on in `group_vars/<your inventory name>/vars.yml`**, the same file you
made during setup:

Skip this step and the service is declared but never deployed.

The assert looks at variable *names*, and both files share one namespace, so it does
not care which of the two a flag comes from. Defining it only in step 3 satisfies it
just as well; step 2 is what keeps the repo self-describing.

The container name, the `nas-setup.service` label, `pull`, `state`, the restart policy,
the `PUID`/`PGID`/`TZ` block, the `/etc/localtime` mount and the strict network
comparison are all supplied by the engine — a definition should not restate them.
`services/navidrome/service.yml` is the template to copy.

A definition may also set two keys the engine consumes itself:

- `network:` — a private Docker network to create (`name`, optional `ipam_config`).
- `hook: true` — run `services/<name>/hook.yml` before the containers, so it can set
  facts they interpolate. Only `jellyfin` (sysctl), `lidarr` and `nextcloud` (cron),
  `qbittorrent` (VPN config, subnet lookup) and `neko` (Chromium proxy policy) need one
  currently.

Directory names use hyphens, never underscores, since the flag is derived as
`enable_container_<name with hyphens replaced by underscores>` and has to map back
unambiguously.

### Container networks

Containers are grouped into zones so that only services which actually talk to each
other share a network. The point is the boundary rather than isolation for its own
sake: a compromise of qbittorrent or flaresolverr cannot reach Vaultwarden, the
documents in Paperless, or the photos in Immich.

| Network | Contents |
|---|---|
| `media_network` | The arr/download/streaming mesh: qbittorrent, sonarr, radarr, lidarr, lazylibrarian, prowlarr, flaresolverr, unpackerr, bazarr, jellyfin, jellyseerr, wizarr, neko. Flat internally — the arrs drive qbittorrent, prowlarr drives flaresolverr, jellyseerr drives jellyfin and the arrs, neko browses through qbittorrent's Privoxy. |
| `app_network` | Low-stakes services that talk to nothing but the proxy: audiobookshelf, dashdot, grocy, linkding, navidrome, tdarr |
| `<service>_network` | One per service worth walling off. Sole network for vaultwarden, nextcloud, immich, paperless, gitea, invoiceninja and homarr; a back-end network for adguard, gramps, tandoor, openreader, wallabag and wireguard, whose web container also sits on `app_network`. |

`app_network` and `media_network` are the shared zones, identified as the networks no
service claims with a `network:` key. Only `app_network` has a pinned subnet, because
it already had one and recreating it would detach every running container; everything
else takes whatever Docker's default pool hands out.

nginx-proxy-manager's upstreams stay plain container names (`http://jellyfin:8096`);
Docker's embedded DNS resolves those over any network the two containers share. Which
networks the proxy joins is derived rather than configured: a container declares
`proxied: true`, and each one resolves to a single network — the shared zone it sits
on, or its own network if it sits on none.

So a web-facing container needs `proxied: true` and a network; that is the whole
configuration, and there is no list to update. Everything else — databases, Redis, the
Gramps Celery worker, the WireGuard tunnel — stays unmarked and out of the proxy's
reach, whether or not it happens to sit alone on a private network.

If you enable Homarr's live integrations (sonarr/radarr/qbittorrent/jellyfin widgets),
add `media_network` to its container as well — it is isolated on the assumption that
it only serves links.

### Image updates

Watchtower updates everything, with no exclusions. Datastores are held to a release
line by their tag (`mariadb:12.3`, `mysql:8.4`, `redis:8-alpine`) rather than by an
exclusion label, so patches flow but a major upgrade — which for these means an on-disk
format change the container cannot perform unattended — never arrives unasked. Moving
up a line is a deliberate edit to `group_vars/all/vars.yml`.

## Development

Lint before committing (neither linter is a runtime dependency):

```bash
pipx install ansible-lint
ansible-lint
yamllint .
ansible-playbook run.yml --syntax-check
```

The repo passes ansible-lint's `production` profile; see `.ansible-lint` for the
rules that are deliberately skipped and why, and `.yamllint` for the relaxed
line-length and truthy settings.

## License

[WTFPL](LICENSE.md).
