# bable

Crewship for macOS: run a fleet of coding agents on a Mac mini or MacBook.

bable installs the [omp](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent) agent harness, [Firstmate](https://github.com/kunchenguid/firstmate) (one supervisor agent that runs many coding agents) and [Herdr](https://herdr.dev) (the terminal workspace they run in), and keeps Herdr running in the background with launchd.

Derived from [i098/Crewship](https://github.com/i098/Crewship) under FSL-1.1-ALv2 (see [LICENSE](LICENSE)).

## Install

You need macOS 14 or newer (Apple silicon or Intel), a normal (non-root) account, and the Xcode Command Line Tools (`xcode-select --install`). If git, gh, node or jq is missing and Homebrew is not installed, the installer sets up Homebrew first; Homebrew asks for your password and needs an admin account.

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
  todo  gh sign-in    run: gh auth login --web
  todo  omp sign-in   run: omp, then /login
```

When the installer adds `~/.local/bin` and `~/.bun/bin` to `PATH` in `~/.zprofile`, open a new terminal (or run `source ~/.zprofile`) before running `bable`, `omp` or `herdr`.

`ok` is ready, `todo` is a step only you can do, `miss` means `bable setup` has something left to install, and `note` is advice. Run the command after `run:`. Running `./install.sh` or `bable setup` again is safe: a second run changes nothing.

## Sign in

1. GitHub: `gh auth login --web`. Open the printed URL on any device and enter the code.
2. omp: start `omp`, finish the first-run screens, then type `/login` (for Anthropic, `/login anthropic`) and follow the provider link. Check with `omp models --json`.

## Start Firstmate

Herdr already runs as the launch agent `dev.bable.herdr`. Attach to it, open a pane, and start the main Firstmate there:

```bash
herdr
cd ~/firstmate && exec omp
```

Then type your request in that omp pane, for example `look at my GitHub project xyz and fix its failing tests`. `exec` makes quitting omp close the pane. Herdr does not resume agents after its server restarts (`resume_agents_on_restore = false`), so start main again the same way. Every 15 seconds `dev.bable.stall-nudge` checks whether main has stalled with a waiting note or wake, and types a nudge into its pane.

## Mac mini

A Mac mini usually runs headless. Launch agents need a logged-in user session: log in at the console once (or turn on automatic login) before installing over SSH, otherwise setup writes the launch agents without loading them and asks you to run `bable setup` again after that login. Set these once; `bable status` prints a `note` for Remote Login, sleep, autorestart and FileVault. bable never changes them for you:

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
| `bable update` | The only command that upgrades: what bable installed, Firstmate (when it has no local changes) and bable itself (for one-line installs). It prints the `launchctl` command when Herdr needs a restart or reload and never restarts it for you, because a restart ends Herdr's sessions. |
| `bable uninstall` | Removes the launch agents, release binaries, unedited configs (and their folders when empty), its logs and the `.zprofile` lines bable added. It prints the commands for the rest (Homebrew formulas, the uv, Herdr and bun installs, bun packages, `~/firstmate`) and does not run them. |

Logs are in `~/Library/Logs/bable`.

## What gets installed

Only what is missing from your `PATH`:

- git, gh, node, jq from Homebrew.
- uv, Herdr and bun from their official installers (`~/.local/bin`, `~/.bun`). Homebrew has no Intel bottles for them.
- omp and acpx with `bun add -g`.
- no-mistakes and treehouse from their GitHub releases, checked against the release `checksums.txt`.
- Firstmate cloned to `~/firstmate` on `main`, with Herdr as its backend.
- Configs, only where no file exists yet: `~/.omp/agent/config.yml`, `~/.omp/agent/lsp.json`, `~/.acpx/config.json`, `~/.no-mistakes/config.yaml`, `~/.config/herdr/config.toml`.
- Launch agents `dev.bable.herdr` and `dev.bable.stall-nudge`.
- One `PATH` line in `~/.zprofile` (plus Homebrew's `shellenv` line when bable installed formulas from `/opt/homebrew` and it was not on your `PATH`).

bable records each item in `~/.local/state/bable/manifest`, so update and uninstall act only on what bable added.

## What bable never touches

- A tool already on your `PATH`. bable uses it and never installs a second copy. Only `bable update` upgrades, and only what bable installed.
- A config file that already exists.
- A Herdr server that bable did not start. bable reports it and writes no Herdr launch agent.
- Launch agents outside `dev.bable.*`.
- System settings (`pmset`, sharing, login items) and anything needing `sudo`.

## Config notes

The seeded configs come from Crewship, without their comments:

- `omp.yml` uses no routers: model ids reach the providers directly, and omp pools several accounts of one provider itself. The advisor is off globally. Every session compacts at 200k tokens, and tool output above 20 KB spills to an artifact.
- `no-mistakes.yaml` sets the pipeline agent to omp over ACP: acpx runs `omp acp`, as `acpx.json` maps it.
- `herdr.toml` keeps Crewship's theme, sidebar width, toast and headless size, and leaves out the sidebar row layouts, whose data came from Crewship add-ons bable does not ship.

## Test

```bash
tests/e2e.sh
```

It runs the real installer in throwaway home folders with `BABLE_NO_SERVICES=1`, which writes and lints the launch agents but never loads them. CI runs it on macOS, then installs for real: it checks every tool runs and the seeded omp, acpx, no-mistakes and Herdr configs load, talks to the `dev.bable.herdr` server, starts Firstmate in a Herdr pane, makes `dev.bable.stall-nudge` nudge it, runs `bable update`, uninstalls and installs again. Pushes to `main` and pull requests use one Apple silicon runner. The nightly run and manual runs (`workflow_dispatch`) cover macOS 15 and 26 on Apple silicon and Intel against the latest upstream releases.

On `main` (pushes, the nightly run and manual runs), a separate job also installs with the public one-line command. With an `ANTHROPIC_API_KEY` repository secret, CI also asks omp for a reply; without it that step is skipped.
