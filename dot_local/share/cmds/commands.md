# Personal Command Recipes

Search this catalog with `cmds`, or press `Alt-S` in an interactive Bash
terminal to insert a selected command at the prompt. Commands are never run by
the picker. Replace uppercase placeholders before executing them, and never
store passwords, tokens, or other secrets here.

## Codex Remote: Start the shared host

Tags: codex remote phone mobile shared host daemon start reboot

Run this after a reboot before opening a shared session from the phone or CLI.
It starts from the home directory so the daemon does not inherit a project.

```bash
(cd "$HOME" && CODEX_HOME="$HOME/.codex-remote-lab" codex remote-control start)
```

## Codex Remote: Choose a shared session

Tags: codex remote phone mobile shared session resume picker choose

Run from the project directory. Opens a picker containing shared sessions for
that project.

```bash
CODEX_HOME="$HOME/.codex-remote-lab" codex resume --remote unix:// -C "$PWD"
```

## Codex Remote: Resume the latest shared session

Tags: codex remote phone mobile shared session resume latest last

Run from the project directory. Resumes its most recent shared session without
opening the picker.

```bash
CODEX_HOME="$HOME/.codex-remote-lab" codex resume --remote unix:// -C "$PWD" --last
```

## Codex Remote: Start a new shared session

Tags: codex remote phone mobile shared session new start

Run from the project directory. The new session will be available from both
the phone and CLI.

```bash
CODEX_HOME="$HOME/.codex-remote-lab" codex --remote unix:// -C "$PWD"
```

## DigitalOcean — Check account balance

Tags: do digitalocean billing balance account money

```bash
doctl balance get
```

## DigitalOcean — List droplets

Tags: do digitalocean droplets servers vms compute list

```bash
doctl compute droplet list
```

## DigitalOcean — Show droplet details

Tags: do digitalocean droplet server vm details inspect get

```bash
doctl compute droplet get DROPLET_NAME_OR_ID
```

## DigitalOcean — SSH into a droplet

Tags: do digitalocean droplet server vm ssh connect login

```bash
doctl compute ssh DROPLET_NAME_OR_ID
```

## DigitalOcean — List App Platform apps

Tags: do digitalocean apps app-platform list

```bash
doctl apps list
```

## DigitalOcean — Follow App Platform logs

Tags: do digitalocean apps app-platform logs follow tail

```bash
doctl apps logs APP_NAME_OR_ID COMPONENT --follow
```

## Docker — List running containers

Tags: docker containers running list ps

```bash
docker ps
```

## Docker Compose — Show service status

Tags: docker compose containers services status ps

```bash
docker compose ps
```

## Docker Compose — Follow service logs

Tags: docker compose logs follow tail service

```bash
docker compose logs --follow SERVICE
```

## Docker Compose — Start in the background

Tags: docker compose start up detach background

```bash
docker compose up --detach
```

## Docker — Show disk usage

Tags: docker disk storage usage images volumes

```bash
docker system df
```

## Rails — Start the development server

Tags: ruby rails server start development

```bash
bin/rails server
```

## Rails — Open the console

Tags: ruby rails console repl

```bash
bin/rails console
```

## Rails — List routes

Tags: ruby rails routes endpoints urls

```bash
bin/rails routes
```

## Rails — Show migration status

Tags: ruby rails database db migrations status

```bash
bin/rails db:migrate:status
```

## Rails — Run migrations

Tags: ruby rails database db migrations migrate

```bash
bin/rails db:migrate
```

## Rails — Run tests

Tags: ruby rails tests test suite

```bash
bin/rails test
```

## Rails / Kamal — Deploy application

Tags: ruby rails kamal deploy deployment production release

Run from the Rails application root.

```bash
kamal deploy
```

## PC RGB — Turn all lights off

Tags: rgb lights lighting openrgb pc off dark blackout

Turns off the RGB memory, MSI motherboard and ARGB headers, SteelSeries
keyboard and mouse, and NVIDIA RTX 5090 FE lighting.

```bash
pc-rgb off
```

## PC RGB — Turn all lights on

Tags: rgb lights lighting openrgb pc on white color

Defaults to white. Add a six-digit RGB hex value for another color, such as
`pc-rgb on 7AA2F7`.

```bash
pc-rgb on
```

## Dotfiles: Capture current settings

Tags: dotfiles chezmoi backup settings config capture re-add save

Copies the current versions of every managed live file into the local
Chezmoi source repository. Review the resulting Git changes before committing.

```bash
chezmoi re-add
```

## Dotfiles: Review captured changes

Tags: dotfiles chezmoi backup settings config review diff status git

Shows files changed in the local dotfiles repository and their unstaged diff.

```bash
dotfiles_source="$(chezmoi source-path)" && git -C "$dotfiles_source" status --short && git -C "$dotfiles_source" diff
```

## Dotfiles: Commit and push backup

Tags: dotfiles chezmoi backup settings config commit push github save

Shows the complete unstaged changes, lets you stage them selectively, checks
the staged patch, shows it in full, opens the commit-message editor, and pushes
to GitHub. Exit the interactive staging prompt without selecting a file that
does not belong in the public repository.

```bash
dotfiles_source="$(chezmoi source-path)" && git -C "$dotfiles_source" status --short && git -C "$dotfiles_source" diff && git -C "$dotfiles_source" add -p && git -C "$dotfiles_source" diff --cached --check && git -C "$dotfiles_source" diff --cached && git -C "$dotfiles_source" commit && git -C "$dotfiles_source" push
```

## Dotfiles: Preview applying the repository

Tags: dotfiles chezmoi restore settings config preview diff apply

Shows what Chezmoi would change in the live home directory. It does not apply
anything.

```bash
chezmoi diff
```

## Dotfiles: Apply the local repository

Tags: dotfiles chezmoi restore settings config apply local

Applies the local Chezmoi source state to the live files.

```bash
chezmoi apply -v
```

## Dotfiles: Pull and apply the latest backup

Tags: dotfiles chezmoi restore settings config update pull github sync

Pulls the latest committed version from GitHub and applies it to the live
files. Preview with `chezmoi diff` first when this machine has local changes.

```bash
chezmoi update -v
```

## Dotfiles: Open the local repository

Tags: dotfiles chezmoi settings config source repository repo open cd

```bash
cd "$(chezmoi source-path)"
```

## Dotfiles: Start tracking another file

Tags: dotfiles chezmoi settings config add track file

Replace the placeholder with the live file or directory to begin managing.

```bash
chezmoi add PATH_TO_FILE
```

## Dotfiles: Stop tracking a file

Tags: dotfiles chezmoi settings config forget unmanage stop tracking file

Replace the placeholder with a managed live file. Chezmoi removes its source
copy after confirmation but leaves the live file in place.

```bash
chezmoi forget PATH_TO_FILE
```

## Neru — Exit navigation mode

Tags: neru mouse mouseless navigation scroll grid hints exit escape idle recover stuck

Exits Neru's current scroll, grid, recursive-grid, or hints mode without
stopping the background daemon.

```bash
/usr/bin/neru idle
```

## Neru — Rescan keyboards after flashing

Tags: neru moonlander keyboard flash firmware rescan restart recover stuck input keys events

Use this when a Neru mode opens but ignores keyboard input after the Moonlander
has been flashed or reconnected. It restarts only Neru and waits for a fresh
input-device scan.

```bash
neru-rescan
```

## Omarchy — Swap two workspaces

Tags: omarchy hyprland workspace desktop move swap exchange renumber all windows from to

Exchanges the IDs of `FROM` and `TO`, keeping each workspace's windows, focus,
and tiling layout together. If one side is empty, the existing workspace simply
moves to that number.

```bash
workspace-swap FROM TO
```
