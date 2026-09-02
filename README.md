# Dan's Omarchy dotfiles

My personal [Omarchy](https://omarchy.org/) workstation configuration,
managed with [Chezmoi](https://www.chezmoi.io/). I share it as a reference for
other Omarchy users; it is not a turnkey distribution and several pieces are
tied to my hardware and installed applications.

The current snapshot was last validated with Omarchy `4.0.1-1`.

## Highlights

- Hyprland display, input, window, and autostart overrides.
- A customized Agents panel for Claude, Codex, and Grok subscription and usage
  information.
- A customized notification service with persistent reminder behavior.
- Guarded OpenRGB controls and an Omarchy RGB panel for an MSI MS-7E49 system.
- One-click switching between SteelSeries speaker and headset routing.
- A searchable command palette plus small workstation helper scripts.

## Repository map

| Path | Contents |
|---|---|
| `dot_config/hypr/` | Hyprland and display overrides |
| `dot_config/omarchy/` | Shell layout, hooks, extensions, and custom plugins |
| `dot_local/bin/` | Personal command-line helpers |
| `dot_local/share/cmds/` | Searchable command recipes |
| `packages/` | Arch and AUR recovery inventories; not applied by Chezmoi |
| `state/` | Omarchy version and service snapshots; not applied by Chezmoi |

Chezmoi encodes destination attributes in source names. For example,
`dot_bashrc` becomes `~/.bashrc`, `executable_foo` becomes an executable named
`foo`, and `private_state.json` becomes `state.json` with group and world
permissions removed. `private_` controls destination permissions; it does not
hide or encrypt repository content.

## Inspect or try it

Install Chezmoi, clone the source state, and inspect the proposed changes
before applying anything:

```bash
sudo pacman -S chezmoi
chezmoi init https://github.com/bandoyer/dotfiles.git
chezmoi diff
```

Only after reviewing and adapting the files for your machine:

```bash
chezmoi apply -v
```

Applying another person's dotfiles can overwrite existing configuration. A
fork or disposable test account is the safest place to experiment.

## Machine-specific pieces

- The OpenRGB launchers expect a locally installed, checksum-pinned build under
  `~/.local/opt/openrgb-msi7e49/`. The binary is intentionally not committed,
  and the launchers refuse to run if it is absent or does not match.
- The ASUS PG32UCDM ICC profile is not redistributed here. The monitor config
  uses it only when the profile has been installed separately at
  `~/.local/share/color/icc/PG32UCDM-Standard.icm`.
- The RGB controls are allowlisted for the specific MSI motherboard and ENE
  memory devices documented in the plugin.
- The audio widget and systemd service require Arctis Sound Manager commands
  installed separately as `asm-output-toggle`, `asm-gui`, and `asm-daemon`.
- The package and service lists are recovery inventories, not installation
  scripts. Review them against the current Omarchy release and your own
  hardware before using them.

Custom systemd units are restored but are not enabled automatically. Enable
them only after their applications and dependencies have been installed.

## Save later changes

Omarchy edits live files under the home directory. Copy changes to Chezmoi's
source state, review both unstaged and staged content, then push:

```bash
chezmoi re-add
chezmoi cd
git status --short
git diff
git add -p
git diff --cached --check
git diff --cached
git commit
git push
exit
```

`chezmoi re-add` updates files that are already managed. Use
`chezmoi add PATH_TO_FILE` when intentionally adding a new file. Run a secret
scanner such as Gitleaks against the worktree and Git history before publishing
newly added configuration.

Use `chezmoi update -v` to pull and apply changes already pushed from another
machine.

## Secrets and private data

Credentials, sessions, caches, browser profiles, downloaded binaries, and
files owned by `/usr/share/omarchy` do not belong in this repository. In
particular, never commit SSH private keys, GitHub or cloud credentials, Codex,
Claude, or Grok authentication files, password-manager data, browser cookies,
keyrings, or the complete `.codex-remote-lab` directory.

Recreate credentials through their installers and authentication flows, use a
password-manager template, or store encrypted Chezmoi source files. Treat
`.gitignore` as defense in depth rather than as a substitute for reviewing the
staged diff and history.

The Agents collectors read local provider authentication only when requesting
the signed-in account's usage or subscription metadata. They do not commit
credentials or generated usage records; runtime output stays under
`~/.local/state/omarchy/agents/usage/`.

## License

My original code and configuration are available under the [MIT License](LICENSE).
Derived and third-party material retains its original ownership and license;
see [Third-party notices](THIRD_PARTY_NOTICES.md).
