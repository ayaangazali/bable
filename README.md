# bable

Crewship for macOS: run a fleet of coding agents on a Mac mini or MacBook.

bable installs the [omp](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent) agent harness, [Firstmate](https://github.com/kunchenguid/firstmate) (one supervisor agent that runs many coding agents) and [Herdr](https://herdr.dev) (the terminal workspace they run in), and keeps Herdr running in the background with launchd.

Derived from [i098/Crewship](https://github.com/i098/Crewship) under FSL-1.1-ALv2 (see [LICENSE](LICENSE)).

## Install

You need macOS 14 or newer (Apple silicon or Intel), a normal (non-root) account, and the Xcode Command Line Tools (`xcode-select --install`). If git, gh, node or jq is missing (or, on Apple silicon, Neovim, btop or mosh) and Homebrew is not installed, the installer sets up Homebrew first; Homebrew asks for your password and needs an admin account.

From a checkout:

```bash
git clone https://github.com/ayaangazali/bable.git
cd bable
./install.sh
```

Or in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/ayaangazali/bable/main/install.sh | bash
```

The one-line form clones bable into `~/.local/share/bable/src`.

The installer ends with `bable status`. Run it again any time:

```text
  ok    herdr         loaded, running
  todo  gh sign-in    run: gh auth login --hostname github.com --git-protocol https --web
  todo  omp sign-in   run: omp, then /login
```

When the installer adds `~/.local/bin` and `~/.bun/bin` to `PATH` in `~/.zprofile`, `~/.zshenv` and `~/.zshrc`, open a new terminal (or run `source ~/.zprofile`) before running `bable`, `omp` or `herdr`.

`ok` is ready, `todo` is a step only you can do (or a service to look at), `miss` means `bable setup` has something left to install, and `note` is advice. Run the command after `run:`. Running `./install.sh` or `bable setup` again is safe: a second run changes nothing.

## Sign in

1. GitHub: `gh auth login --hostname github.com --git-protocol https --web`. Open the printed URL on any device and enter the code.
2. omp: start `omp`, finish the first-run screens, then type `/login` (for Anthropic, `/login anthropic`) and follow the provider link. Check with `omp models --json`.

## Start Firstmate

Herdr already runs as the launch agent `dev.bable.herdr`. Attach to it, open a pane, and start the main Firstmate there:

```bash
herdr
cd ~/firstmate && exec omp
```

Then type your request in that omp pane, for example `look at my GitHub project xyz and fix its failing tests`. `exec` makes quitting omp close the pane. Herdr does not resume agents after its server restarts (`resume_agents_on_restore = false`), so start main again the same way. Every 15 seconds `dev.bable.stall-nudge` checks whether main has stalled with a waiting note or wake, and types a nudge into its pane.

## Mac mini

A Mac mini usually runs headless. Launch agents need a logged-in user session: log in at the console once (or turn on automatic login) before installing over SSH, otherwise setup skips the launch agents and asks you to run `bable setup` again after that login. Do not start `herdr` by hand before then, or the launch agent's server finds it running and keeps restarting. Set these once; `bable status` prints a `note` for Remote Login, sleep, autorestart and FileVault. bable never changes them for you:

- Remote Login: System Settings > General > Sharing > Remote Login.
- Automatic login for this user (System Settings > Users & Groups), so launch agents start after a reboot. With FileVault on, a power cut stops at the unlock screen until someone logs in.
- `sudo pmset -a sleep 0` so the Mac never sleeps, and `sudo pmset -a autorestart 1` so it starts again after a power cut.

## MacBook

A sleeping laptop pauses every agent. Keep `caffeinate -ims` running in a terminal while agents work. Closing the lid without an external display still sleeps the Mac.

## Commands

| Command | What it does |
| --- | --- |
| `bable setup` | Installs what is missing and prints `bable status`. |
| `bable status` | Read-only checklist. Exits 1 while anything is `miss`. |
| `bable update` | The only command that upgrades: what bable installed (including its own omp plugins and skills, and nothing of yours), Firstmate (when it has no local changes) and bable itself (for one-line installs). It prints the `launchctl` command when Herdr needs a restart or reload and never restarts it for you, because a restart ends Herdr's sessions. |
| `bable uninstall` | Removes the launch agents, release binaries, the gh guard, the omp extensions, plugins (and the marketplaces bable added) and Herdr integration, unedited configs and managed files (and their folders when empty), its logs and the shell lines bable added. It prints the commands for the rest (Homebrew formulas, the uv, Herdr and bun installs, bun packages, skills, `~/firstmate`, the `mate-archive` index) and does not run them, and remembers them so a reinstall still owns them. It stops Herdr last, so it is safe to run from a Herdr pane. |

Logs are in `~/Library/Logs/bable`.

## What gets installed

bable installs Crewship's default host, the `agents` and `firstmate` profiles. Tools are installed only when they are missing from your `PATH`:

- git, gh, node and jq from Homebrew, and on Apple silicon also Neovim, btop and mosh. Homebrew no longer ships Intel bottles, so on Intel bable skips those three (building them from source takes too long) and `bable status` prints the `brew install` command.
- uv, Herdr and bun from their official installers (`~/.local/bin`, `~/.bun`). Homebrew has no Intel bottles for them.
- With `bun add -g`: omp, acpx, the AXI agent CLIs (tasks-axi, gh-axi, quota-axi, lavish-axi, chrome-devtools-axi, forgejo-axi), chrome-devtools-mcp, backpass and ondine. omp and acpx are also linked into `~/.local/bin`, where the no-mistakes daemon looks for them.
- From GitHub releases, each checked against the SHA-256 digest GitHub publishes for the asset: ripgrep, no-mistakes, treehouse, fallow, gws (Google Workspace CLI), pyrefly and sentrux with its grammars (sentrux has no Intel build).
- Firstmate cloned to `~/firstmate` on `main`, with Herdr as its backend.

From [Crewship](https://github.com/i098/Crewship) at a pinned commit, which bable downloads into `~/.local/share/bable/crewship`:

- Configs, only where no file exists yet, readable only by you: `~/.omp/agent/config.yml`, `~/.omp/agent/lsp.json`, `~/.acpx/config.json`, `~/.no-mistakes/config.yaml`, `~/.config/btop/btop.conf`, and LazyVim in `~/.config/nvim` when that folder is missing or empty. `~/.config/herdr/config.toml` comes from bable. In an omp config you already had, bable adds only the status row Crewship needs (under the `custom` preset), and in an acpx config it changes `defaultAgent` from the retired `codex` to `omp`.
- `~/.omp/agent/models.yml`: Crewship's model overrides, merged on every setup into your `models.yml` (or your `models.yaml` or `models.json`, which omp reads when there is no `models.yml`). Your own providers stay, and bable rewrites the file only when the merge changes something.
- omp extensions, updated on every setup unless the file was there before bable or you edited it, in `~/.omp/agent/extensions`: the Herdr sidebar feed, mode icons, the `pkill`/`killall` block, the Opus effort cap, the turn-end quality gate (sentrux and fallow), unii memory and gluttony.
- The omp plugins ponytail, i-have-adhd and caveman, and Herdr's omp integration, so Herdr shows each omp pane's real state.
- `ponytail-review` (runs the ponytail plugin's review on a diff from any harness, and fails closed) and `mate-archive` (searches omp chat that compaction removed) in `~/.local/bin`.
- A guard in front of `gh` and `gh-axi` that blocks issue and API writes without an explicit repository, also through gh aliases. bable does not add it if a `~/.local/bin/gh` of your own exists, and `bable status` reports `miss` when an interactive zsh would run another `gh` or `gh-axi` first.
- Firstmate's dispatch settings in `~/firstmate/config` (crew harness, the second mate harness, `crew-dispatch.json` model routing, the crew brief, the startup memory budget, the flat Herdr layout and the churn flag), plus the stuck-composer check, registered with Firstmate.
- The vision and security-audit skills for omp and Claude Code, and the kun skill.

Also:

- Launch agents `dev.bable.herdr` (with a 10240 open-file limit) and `dev.bable.stall-nudge`, which runs a copy of its script in `~/.local/share/bable`, so a checkout in `~/Documents` or `~/Desktop` (which macOS privacy protection blocks for launch agents) still works. Over SSH before anyone has logged in at the console, setup writes neither and `bable status` says to log in first.
- The `PATH` line in `~/.zprofile`, `~/.zshenv` and `~/.zshrc`, so SSH and mosh commands find `herdr` and `mosh-server` too and the gh guard stays first in interactive shells. The `CHROME_DEVTOOLS_AXI_MCP_PATH` line, when bable's chrome-devtools-mcp is there, goes in `~/.zprofile` and `~/.zshenv`. Homebrew's `shellenv` line goes in `~/.zprofile` only, when bable installed formulas from `/opt/homebrew` and it was not on your `PATH`.

bable records each item in `~/.local/state/bable/manifest`, so update and uninstall act only on what bable added.

## What bable never touches

- A tool already on your `PATH`. bable uses it and never installs a second copy. Only `bable update` upgrades, and only what bable installed.
- A config, extension, `~/.local/bin` script or Firstmate setting file that already exists, or that you edited after bable wrote it.
- A `~/firstmate` that is not a Firstmate checkout. `bable status` reports it.
- A Herdr server that bable did not start. bable reports it and writes no Herdr launch agent.
- Launch agents outside `dev.bable.*`.
- System settings (`pmset`, sharing, login items) and anything needing `sudo`.

## Config notes

- `omp.yml` uses no routers: model ids reach the providers directly, and omp pools several accounts of one provider itself. The advisor is off globally. Every session compacts at 200k tokens, and tool output above 20 KB spills to an artifact.
- `no-mistakes.yaml` sets the pipeline agent to omp over ACP: acpx runs `omp acp`, as `acpx.json` maps it.
- `herdr.toml` keeps Crewship's theme, sidebar width, toast, headless size and agent sidebar rows. It leaves out the Spaces rows, whose data comes from the Spaces reporter that bable does not ship.

## Not ported

These parts of Crewship's default host are not in bable yet:

- The Firstmate patch layer (faster wake on inbox notes, closing a pane when its agent exits). Its first patch no longer applies to Firstmate `main`, in Crewship too, so bable runs Firstmate unpatched.
- The Herdr Spaces reporter, the `machine` workspace with its schedules, usage, crew board and browser tabs, the TUIs behind them and the `crewship` CLI. They read Linux `/proc` and run on systemd timers.
- `herdr-patch` (Herdr over mosh with images) and the btop pane launcher.
- The Chrome AXI browser pruner.
- The no-mistakes `omp-as-pi` adapter. Its checker needs bash 4, and macOS ships bash 3.2, so no-mistakes keeps omp over ACP.
- Linux-only steps: the CA store changes, inotify limits and `/usr/local/bin` links.

## Test

```bash
tests/e2e.sh
```

It runs the real installer in throwaway home folders with `BABLE_NO_SERVICES=1`, which writes and lints the launch agents but never loads them. CI runs it on macOS, then installs for real: it checks every tool runs, the gh guard blocks an untargeted write, the omp plugins, extensions, models and Herdr integration are in place, the seeded omp, acpx, no-mistakes and Herdr configs load, talks to the `dev.bable.herdr` server, starts Firstmate in a Herdr pane, makes `dev.bable.stall-nudge` nudge it, runs `bable update`, uninstalls and installs again. Pushes to `main` and pull requests use one Apple silicon runner. The nightly run and manual runs (`workflow_dispatch`) cover macOS 15 and 26 on Apple silicon and Intel against the latest upstream releases.

On `main` (pushes, the nightly run and manual runs), a separate job also installs with the public one-line command. With an `ANTHROPIC_API_KEY` repository secret, CI also asks omp for a reply; without it that step is skipped.
