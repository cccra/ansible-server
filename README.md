# nas-setup

My Ansible NAS setup. One playbook (`run.yml`) provisions a single self-hosted
NAS/homelab server: base system, storage (MergerFS + SnapRAID), security, and ~35
self-hosted services that each run as a Docker container.

Requires **ansible-core 2.15 or newer** (2.21 is what this is developed against).

## Usage

Install Ansible:

```bash
# Arch
sudo pacman -S ansible
# Debian/Ubuntu
sudo apt install ansible
# macOS
brew install ansible
```

Clone the repository:

```bash
git clone https://github.com/cccra/nas-setup
cd nas-setup
```

Install the dependencies — this installs both the external roles **and** the
collections the playbook needs (`community.docker`, `community.general`,
`ansible.posix`):

```bash
ansible-galaxy install -r requirements.yml
```

Add your inventory file:

```bash
cp hosts_example hosts
$EDITOR hosts
```

Create a variable file for your host and adjust the variables. The directory name
must match the inventory name you used in `hosts`:

```bash
mkdir -p group_vars/YOUR_INVENTORY_NAME
$EDITOR group_vars/YOUR_INVENTORY_NAME/vars.yml
```

Store the Ansible Vault password in [`pass`](https://www.passwordstore.org/) under
the key `homeserver_ansible_secret`. `pass.sh` reads it from there automatically
every time Ansible asks for it (wired up via `vault_password_file` in
`ansible.cfg`), so you never pass `--ask-vault-pass`:

```bash
pass insert homeserver_ansible_secret
```

Create an encrypted vault file for your secrets:

```bash
ansible-vault create group_vars/YOUR_INVENTORY_NAME/vault.yml
ansible-vault edit   group_vars/YOUR_INVENTORY_NAME/vault.yml
```

Finally, run the playbook:

```bash
ansible-playbook run.yml -l your-host-here -K
```

`-K` is only needed on the first run, since the playbook configures passwordless
sudo for the main login user.

To only update the Docker containers on subsequent runs:

```bash
ansible-playbook run.yml -l your-host-here --tags="containers"
```

The SSH port probe is tagged `always`, so it runs on every invocation — tagged or
not — and never needs to be requested explicitly.

Every role has a tag matching its name, so a single service can be redeployed with:

```bash
ansible-playbook run.yml -l your-host-here --tags="jellyfin"
```

## Configuration

Everything is gated by `enable_*` flags, all defaulting to `false` in
`group_vars/all/vars.yml`. Turn a service on by overriding its flag in your own
`group_vars/<inventory_name>/vars.yml` — never by editing the role list in
`run.yml`.

Variable precedence:

| File | Purpose | Tracked in git |
|---|---|---|
| `group_vars/all/vars.yml` | Committed defaults. Do not put host config here. | yes |
| `group_vars/<name>/vars.yml` | Per-environment overrides | no |
| `group_vars/<name>/vault.yml` | Secrets, ansible-vault encrypted | no |

Service credentials (database passwords and the InvoiceNinja `APP_KEY`) are
deliberately **not** defined in `group_vars/all/vars.yml` — see the block at the
bottom of that file for the list of variables to define in your vault.

## Development

Lint before committing (`ansible-lint` is not a runtime dependency; install it with
`pipx install ansible-lint`):

```bash
ansible-lint
ansible-playbook run.yml --syntax-check
```

The repo passes ansible-lint's `production` profile; see `.ansible-lint` for the
two rules that are deliberately skipped and why.
