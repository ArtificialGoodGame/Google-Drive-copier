# Google Drive Folder Copier for Windows

Copy a Google Drive folder into your own Drive using a simple Windows menu. The
copier follows accessible folder shortcuts, copies their contents server-side,
checks every source file, and repeats the copy and verification for up to **three
total passes** when gaps remain. It uses copy operations, never move, sync, or
delete operations on the source.

**No Google credentials or account authorization are included.** Each recipient
uses their own Google Desktop OAuth client JSON and authorizes their own account.

## Requirements

- 64-bit Windows with Windows PowerShell 5.1 and a web browser.
- Internet access, a Google account, and sufficient destination Drive storage.
- Permission to read and copy the source files, including shortcut targets.

The package includes rclone v1.75.0 for Windows amd64 in `bin/rclone.exe`; no
separate rclone installation is required. Download this repository with
**Code > Download ZIP** and extract it, or clone it. Keep the scripts, launchers,
and `bin` folder together.

## First-time setup

1. In [Google Cloud Console](https://console.cloud.google.com/), create or select a project.
2. Enable the **Google Drive API**.
3. Configure **Google Auth Platform / OAuth consent**:
   - Use an **External** audience for a personal Gmail account.
   - Keep the app in **Testing** for private use.
   - Add the Google account that will run the copier as a **Test user**.
4. Create an OAuth client with application type **Desktop app**.
5. Download its JSON file and keep it private.
6. Double-click **Setup Google Account.cmd** and select your JSON file. If the
   file picker is unavailable, paste the file's full path when prompted.
7. Sign in to the Google account that should own the copies and approve access.
   Wait for the successful connection message.

Setup stores account authorization in `private/rclone.conf`. Reconnecting also
keeps a backup of the previous configuration inside `private/`.

## Copy a folder

1. Put shared-folder shortcuts somewhere inside **My Drive**.
2. Double-click **Google Drive Copier.cmd**.
3. Choose **1. Copy a folder and verify it**.
4. Enter paths as they appear inside My Drive, without a Drive URL:

   | Prompt | Example |
   | --- | --- |
   | Source folder | `School/Shared collection` |
   | Owned destination folder | `School/Owned collection` |

5. Keep the window open until **SUCCESS** appears. Copy and verification logs
   are written to `logs/`.

Use a new, separate destination folder. Neither path may contain the other.
Do not use a destination shortcut that points back into the source: different
text paths can refer to the same underlying Drive folder. The copier cannot
detect every shortcut alias. Existing destination files may be updated by
rclone when they differ; extra destination files are retained.

Folder shortcuts are followed, and file-shortcut contents are copied using
`--drive-copy-shortcut-content`. Google Drive permissions and copy restrictions
still apply. Keep the source stable while copying and verifying.

## Verification and retries

After each copy pass, a one-way, size-based check compares every source file
with the destination. Success means all source files were found at the
destination with matching sizes; it is **not a byte-for-byte or checksum
guarantee**. Extra destination files do not cause a failure.

If verification fails, the copier reruns copy and check, up to three total
passes (the initial pass plus two retries). If gaps remain, it reports that the
copy could not be fully verified and points to the logs. Resolve permission,
storage, or connection errors and run the copy again.

Menu option **2** verifies an existing copy without copying files. Menu option
**3** reconnects or changes the Google account. Apps left in Google's Testing
status may require reconnection after seven days; authorize again with your own
JSON. Menu option **4** exits.

## Keep your account information private

- Never share `private/`, `logs/`, your OAuth JSON, or an already-configured folder.
- To share the tool, send the repository link or a fresh download from GitHub.
- `.gitignore` excludes private configuration, logs, JSON files, credentials,
  tokens, key files, and distribution archives. Do not force-add those files.
- Log files can contain private Drive paths and filenames.

## Bundled software

rclone is distributed under the MIT License; see
[THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt).

Bundled `bin/rclone.exe` SHA-256:

```text
8be30f02266a6eaad9d481941ef287b9744bb7140034b097ad862a2ccff3e24c
```
