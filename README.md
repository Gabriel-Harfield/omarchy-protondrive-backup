# Proton Drive Backup

A two-tab Omarchy bar panel for Proton Drive, using the official Proton
Drive CLI as the transfer backend.

- **Backup** — Déjà Dup-style manual backup of one file or folder at a
  time. No sync, no file comparison — every backup is a brand-new, dated
  copy uploaded to `/my-files/Backups`.
- **Browse** — breadcrumb navigation of your whole Proton Drive, starting
  at `/my-files`, to download anything or upload into whatever folder
  you're currently viewing.

The two tabs are fully separate components (`BackupTab.qml` /
`BrowseTab.qml`) with their own state and their own scripts — see
"Tab isolation" below.

This is a separate, much simpler plugin than
`io.github.gabrielharfield.protondrive-sync` (folder sync + Syncthing),
which is currently parked.

## Backup tab

1. Click the bar icon (cloud glyph, right section) to open the panel.
2. **+ New backup** opens the native picker (`omarchy-file-select`). Pick
   a file or a folder — the picker itself doesn't force a choice between
   the two, so a plain "open file" dialog already lets you select either;
   the plugin detects which one you picked afterwards (`stat-kind.sh`).
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

## Requirements

- Proton Drive CLI (`proton-drive`) installed and logged in
  (`proton-drive auth login`) — same CLI as the sync plugin, auto-detected
  via `find-cli.sh`.
- `jq` (JSON reshaping in `list-backups.sh` / `list-path.sh`).
- `omarchy-file-select` (ships with Omarchy) for the file/folder picker.

## Files

- `BarWidget.qml` — bar icon, toggles the panel.
- `Panel.qml` — orchestration only: finds the CLI once, hosts the tab
  switcher, passes `cliPath` and a few constants down to both tabs.
- `BackupTab.qml` / `BrowseTab.qml` — the two tabs. Self-contained: own
  state, own `Process` calls into the scripts below. Neither reaches into
  the other.
- `Format.js` — the only thing shared between the tabs: pure formatting
  helpers (byte sizes, dates, the backup timestamp suffix). No CLI paths,
  no state, so importing it doesn't couple the tabs' actual behavior.
- `find-cli.sh` — locates the `proton-drive` binary.
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
