# Proton Drive Backup

An Omarchy bar panel for Proton Drive, using the official Proton Drive
CLI as the transfer backend.

Built around one priority, ahead of every other feature: **never lose or
corrupt a file.** Everything below — the explicit, one-shot actions
instead of a background sync daemon, the pinned CLI version, even which
picker button does what — follows from that, including the features this
plugin deliberately doesn't have yet. See "Why reliability comes before
real-time sync" below for the reasoning in full.

- **Backup** — Déjà Dup-style manual backup of one file or folder at a
  time. No sync, no file comparison — every backup is a brand-new, dated
  copy uploaded to `/my-files/Backups`.
- **Browse** — breadcrumb navigation of your whole Proton Drive, starting
  at `/my-files`, to download anything or upload into whatever folder
  you're currently viewing.
- **Settings** (gear icon, top right) — log in. CLI setup is fully
  automatic; see "A pinned Proton Drive CLI" below.

Backup, Browse, and Settings are fully separate components (`BackupTab.qml`
/ `BrowseTab.qml` / `SettingsView.qml`) with their own state and their own
scripts — see "Files" below.

This is a separate, much simpler plugin than
`io.github.gabrielharfield.protondrive-sync`, which is now a private
testbed for exploring real sync approaches — not something this plugin
depends on or shares code with. If that ever produces a satisfying
result, it would be ported in here as a third tab, not merged wholesale.

## Why reliability comes before real-time sync

This plugin does one-shot uploads and downloads, on demand — it doesn't
try to keep two machines continuously in sync the way Dropbox or
Syncthing do. That's a deliberate choice, not a missing feature, and it
comes down to one question: when a tool might be the only thing standing
between someone and their work, is it more important that it does
everything, or that everything it does is trustworthy? This project
picked the second answer, on purpose, even where that costs convenience.

- **Proton Drive's CLI has no push/notification channel at all.** There
  is no way for one machine to be told the instant another machine
  changes something — the only option is polling, and Dropbox/Syncthing
  don't work by polling: Dropbox pushes over a persistent connection to
  its servers, Syncthing pushes directly between paired devices. Neither
  mechanism exists for Proton Drive.
- **Polling fast enough to feel "instant" runs straight into rate
  limiting.** Proton's API rate-limits at volume, confirmed directly: a
  568-file listing pass triggered 141 HTTP 429s in under four minutes.
  Cross-device propagation fast enough to feel instant would need
  polling every few seconds, on every synced machine, which reproduces
  that same wall from a different angle — and a sync engine that starts
  missing or delaying updates under its own load is exactly the kind of
  quietly-degraded reliability this project won't ship.
- **A real two-way sync engine is possible on top of `filesystem list`'s
  per-revision metadata** (`claimedDigests.sha1`, `claimedModificationTime`,
  `claimedSize`) — at least one other Proton Drive plugin has built
  exactly that, competently, with a test suite that holds up under
  review. That's a legitimate engineering achievement, and it's also a
  bet this project won't make: those fields aren't part of the CLI's
  documented contract. If a future CLI version changes what they mean,
  or ships its own content-aware download logic that quietly disagrees
  with a hand-rolled diff built on top of it, the failure mode is a
  *silently wrong* sync state, not a loud crash — the worst possible
  failure mode for something holding real files, because nothing tells
  you it happened. Depending on undocumented behavior to sync someone's
  only copy of a document is a trade this plugin isn't willing to make,
  no matter how well the code around that trade is written. See the
  CLI-pinning section below for the same "silent drift is worse than a
  loud break" reasoning applied to version control in general — it's the
  same principle both times, not two unrelated decisions.

If Proton ships a real Linux sync client, or the CLI gains an actual
change-feed / push primitive, this calculus changes — the objection is to
depending on an undocumented workaround, not to sync as a goal. Until
then: back up explicitly, on your own schedule, and know exactly what got
uploaded and when. Slower and certain beats fast and occasionally wrong,
for this kind of tool — that's the whole design philosophy in one line.

## Backup tab

1. Click the bar icon (cloud glyph, right section) to open the panel.
2. **+ Backup file** or **+ Backup folder** opens the native picker
   (`omarchy-file-select`, with `--directory` for the folder case). Two
   buttons, not one: verified live that a plain "open file" dialog lists
   folders in the GTK/Nautilus chooser used here but won't let one be
   *chosen*, only navigated into — `--directory` is the only reliable way
   to put the chooser into folder-selection mode, so which button you
   press has to decide that up front. `stat-kind.sh` still double-checks
   the result afterwards, as a cheap defensive backstop.
3. The panel shows every existing Proton Drive backup of that same item
   — same kind (file/folder) and same name, matched by name, not content
   — and lets you tick old ones to trash before the new upload, or leave
   them all alone.
4. **Confirm backup** trashes whatever you ticked, then uploads the
   picked item as `<name>_<DD-MM-YY>_<HHhMM>` (plus the original
   extension, for files; folders keep just the name).
5. Back on the list, every backup on Proton Drive is shown — folders
   marked with 📁 — with a download (⤓) and a trash (✕) button per row.
   Downloads land in `~/Downloads/ProtonDriveBackups/`.

Trashing goes through Proton Drive's own trash (reversible from
proton.me/drive), never a hard delete.

## Browse tab

1. Starts at `/my-files`. The path is shown as a breadcrumb — click any
   earlier segment to jump back to it, or **↑ Up** for one level.
2. Click a folder's name to navigate into it. Every row (file or folder)
   has its own download (⤓) button, independent of navigating in.
   Downloads land in `~/Downloads/ProtonDrive/`.
3. **Upload here** opens the native picker and uploads whatever you pick
   straight into the folder you're currently viewing, keeping its
   original name (conflict strategy: rename, never silently overwrites
   or merges into something already there).

There is deliberately no delete in this tab — Browse only ever downloads
or uploads, so navigating around Proton Drive can never destroy anything
by accident. Deleting stays a Backup-tab-only action, on backups the
plugin itself created.

## A pinned Proton Drive CLI

This plugin never uses a system-wide or AUR-installed `proton-drive` —
not because those are bad, but because their version isn't under this
plugin's control. `proton-drive-cli-bin` on the AUR, for instance, gets
silently updated by an ordinary `omarchy update`, with no correlation to
whether anyone has checked that the new version still behaves the way
this plugin expects. A CLI update that quietly changes behavior — rather
than breaking loudly — is the failure mode that actually matters for a
tool moving real files.

So instead, `ensure-cli.sh` runs once per panel session and:

1. Checks whether this plugin's own pinned copy is already sitting at
   `~/.local/share/omarchy-protondrive-backup/bin/proton-drive` and
   reports the exact version this plugin was built and tested against
   (`proton-drive --version` — fast, no re-hash needed on the common
   path).
2. If it's missing, or reports a different version — including a version
   that's *newer* than the one this plugin expects, since that's still a
   behavior nobody has verified yet — downloads the **specific pinned
   build** from Proton's own official CDN (the version, URL, and SHA-512
   checksum are hardcoded in the script, not fetched from Proton's
   "current Stable" manifest), verifies the checksum, and installs it.
   That also means a corrupted or externally-tampered copy self-heals
   back to the known-good build on the next launch.

This happens automatically — no install button — but it isn't hidden:
the panel shows "Setting up Proton Drive CLI…" while it's in progress, so
a first run (a real ~118MB download) is visible, not a silent surprise.

Bumping the pinned version is a deliberate, manual edit to `ensure-cli.sh`
(new version string, URL, checksum) after actually testing the new
release against this plugin — never automatic, same reasoning as the "why
no sync" section above applied to the CLI itself rather than to Proton's
undocumented metadata fields.

## Settings

Click the gear icon (top right) to open it, click it again (now a ✕) or
press Escape to go back to whichever tab you were on. Settings shows the
pinned CLI's version (read-only — there's no path field, on purpose: no
setting in this UI can point the plugin at an untested build) and one
button:

- **Log in** runs `proton-drive auth login`, which opens your browser to
  sign in (can be completed on a different device) — the button stays
  disabled ("Opening browser…") until that finishes. This stays a manual
  button rather than firing automatically, since it opens a real browser
  window and shouldn't surprise anyone who was just curious what the bar
  icon does.

## Requirements

- `curl` and `sha512sum` (`ensure-cli.sh`'s pinned-download-and-verify step
  — no separate Proton Drive CLI install needed beforehand).
- `jq` (JSON reshaping in `list-backups.sh` / `list-path.sh`).
- `omarchy-file-select` (ships with Omarchy) for the file/folder picker.

## Files

- `BarWidget.qml` — bar icon, toggles the panel.
- `Panel.qml` — orchestration only: runs `ensure-cli.sh` once, hosts the
  tab switcher and the gear-icon Settings toggle, passes `cliPath` (and
  `cliVersion`/`cliError`) down to all three views, read-only.
- `BackupTab.qml` / `BrowseTab.qml` / `SettingsView.qml` — the three
  views. Self-contained: own state, own `Process` calls into the scripts
  below. None reaches into another, and none can change `cliPath` anymore
  — that's exclusively `Panel.qml`'s job now, via `ensure-cli.sh`.
- `Format.js` — the only thing shared between Backup/Browse: pure
  formatting helpers (byte sizes, dates, the backup timestamp suffix). No
  CLI paths, no state, so importing it doesn't couple their actual behavior.
- `ensure-cli.sh` — installs/verifies the pinned CLI build at this
  plugin's own path. See "A pinned Proton Drive CLI" above.
- `stat-kind.sh` — "file" or "folder" for a local path (Backup tab only;
  Browse tab's upload doesn't care which).
- `list-backups.sh` — ensures `/my-files/Backups` exists, lists its
  contents as JSON. Backup tab.
- `upload-backup.sh` — uploads a file or folder, then renames it to the
  timestamped name. Backup tab.
- `delete-backups.sh` — trashes one or more backups by bare name under
  `/my-files/Backups`. Backup tab.
- `download-backup.sh` — downloads one backup (file or folder) to
  `~/Downloads/ProtonDriveBackups/`. Backup tab.
- `list-path.sh` — read-only listing of an arbitrary Proton Drive path.
  Browse tab.
- `download-path.sh` — downloads a file or folder from an arbitrary path
  to `~/Downloads/ProtonDrive/`. Browse tab.
- `upload-to.sh` — uploads a file or folder into an arbitrary Proton
  Drive folder, keeping its original name. Browse tab.

## Notes

- `manageIpc` is off: the panel opens only by clicking the bar icon, not
  via `omarchy-shell <id> toggle`. This avoids duplicate-instance IPC
  target collisions when the bar is mounted on more than one monitor.
- "Related backups" (the ones offered for deletion before a new upload,
  Backup tab) are matched purely by name and kind — `<base>_*.<ext>`,
  same file/folder type — not by content. Two different local items that
  happen to share a base name, extension, and kind would be offered as
  if related.
- Browse tab's breadcrumb model only understands plain name segments
  under `/my-files`. Proton Drive's other top-level sections
  (`/shared-with-me`, …) address nodes by UID rather than by name and
  aren't reachable from this tab.
