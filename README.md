<p align="center">
  <img src="Assets/appIcon.png" alt="CodexAccount app icon" width="96" height="96">
</p>

# CodexAccount

> Switch Codex Desktop accounts from the macOS menu bar.

CodexAccount is a simple quick utility for switching between Codex Desktop
accounts from the menu bar. Capture each signed-in account once, then switch
between them without deleting projects, local chats, or Codex Desktop settings.

It is intentionally narrow: CodexAccount swaps file-backed Codex authentication
snapshots and restores the selected Codex config profile from
`~/.codex/config.toml`. Your Codex history and workspace state stay where Codex
already keeps them.

## Why

- **One-click account switching.** Pick any saved profile directly from the
  menu bar.
- **Codex profile aware.** Codex now supports named config profiles via
  `[profiles.<name>]` in `~/.codex/config.toml`. Each saved account can restore
  one of those profiles, or the default config.
- **Preserves local Codex state.** The app only replaces `~/.codex/auth.json`
  and the top-level `profile = "..."` selector in `~/.codex/config.toml`.
  It does not touch `~/.codex/state_*.sqlite`, local sessions, logs, memories,
  plugins, workspace metadata, or other Codex Desktop settings.
- **Recovery first.** Every switch creates timestamped backups before replacing
  auth or changing the selected Codex config profile.
- **Codex Desktop friendly.** By default, Codex Desktop is quit before the auth
  file changes, then reopened after the switch.
- **CodexBar aware.** If CodexBar is installed, CodexAccount refreshes Codex
  usage through the `codexbar` CLI after switching.
- **Menu-bar native.** No Dock icon during normal use. The Dock icon appears
  only while the management window is open, then disappears again when it closes.

## Install

### GitHub Releases

Download the latest build from:

<./releases/latest>

Unzip `CodexAccount.app.zip`, move `CodexAccount.app` to `/Applications`, and
open it once.

### Build From Source

Requirements:

- macOS 14 or newer
- Xcode Command Line Tools
- Python 3 with Pillow, used only to generate the app icon

```sh
git clone <your-fork-or-clone-url>
cd CodexAccount
python3 -m venv .venv
. .venv/bin/activate
python -m pip install Pillow
./script/build_and_run.sh --package
open dist/CodexAccount.app
```

To install locally:

```sh
cp -R dist/CodexAccount.app /Applications/CodexAccount.app
open /Applications/CodexAccount.app
```

## First Run

1. Sign in to Codex Desktop with the first account.
2. Open CodexAccount from the menu bar and choose `Manage Accounts...`.
3. Capture the current account with a clear name, for example `Personal`.
4. Use `Sign Out + Open Login` if Codex Desktop does not expose a logout button.
   CodexAccount runs `codex logout` first, then falls back to removing the
   file-backed auth snapshot if needed.
5. Sign in to Codex Desktop with the second account.
6. Capture it as another profile, for example `Enterprise`.
7. Switch later by clicking the CodexAccount menu bar icon and selecting the
   target profile.

During a switch, CodexAccount backs up the active auth file, restores the saved
auth snapshot, applies the associated Codex config profile when one is selected,
refreshes CodexBar usage when available, and reopens Codex Desktop.

## What It Stores

CodexAccount stores profile snapshots and backups in:

```text
~/Library/Application Support/CodexAccount
```

The active Codex auth file lives at:

```text
~/.codex/auth.json
```

Only that active auth file is replaced during account switching. Profile
snapshots are copies of `auth.json`, so treat them like credentials and keep the
Application Support folder private.

Codex config profiles are read from:

```text
~/.codex/config.toml
```

CodexAccount only changes the top-level `profile = "..."` selector and backs up
`config.toml` first. It does not rewrite individual `[profiles.*]` definitions.

If your Codex setup uses `cli_auth_credentials_store = "keyring"`, Codex stores
credentials in macOS Keychain instead of `auth.json`. CodexAccount intentionally
does not copy or mutate Keychain credentials; use file-backed auth for account
switching.

## Privacy And Safety

CodexAccount is local-only. It does not send account files to a server, sync
profiles, or read arbitrary project directories.

The app does:

- Read and copy `~/.codex/auth.json`.
- Read `~/.codex/config.toml` for named Codex config profiles.
- Backup `~/.codex/config.toml` and update only the top-level `profile`
  selector when switching.
- Write saved auth snapshots and backups under Application Support.
- Quit and reopen Codex Desktop during switches when that setting is enabled.
- Run `codex logout` during the explicit sign-out flow so Codex can clear its
  configured credential backend.
- Run `codexbar usage --provider codex --source oauth --format json` after a
  switch when CodexBar is installed.

The app does not:

- Modify Codex Desktop history databases.
- Delete local sessions, project metadata, or logs.
- Modify Codex memories, plugins, MCP settings, or profile definitions.
- Read or write macOS Keychain credentials.
- Store OpenAI passwords.
- Require Accessibility, Screen Recording, or Full Disk Access permissions.

## Launch At Login

The repository includes a LaunchAgent template:

```text
launchd/com.codexaccount.app.plist
```

Install it with:

```sh
mkdir -p ~/Library/LaunchAgents
cp launchd/com.codexaccount.app.plist ~/Library/LaunchAgents/
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.codexaccount.app.plist
launchctl kickstart -k "gui/$(id -u)/com.codexaccount.app"
```

## Development

Build and launch the local app bundle:

```sh
./script/build_and_run.sh
```

Build without launching:

```sh
./script/build_and_run.sh --package
```

Build, launch, and verify the process exists:

```sh
./script/build_and_run.sh --verify
```

Generated assets and bundles are intentionally ignored:

- `.build/`
- `build-assets/`
- `dist/`

## Releases

GitHub Actions builds the app on tag pushes matching `v*`.

```sh
git tag v0.2.1
git push origin v0.2.1
```

The workflow packages `dist/CodexAccount.app` as `CodexAccount.app.zip` and
attaches it to the GitHub release.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
