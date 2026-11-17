# Karaoke Tracks

Turn any song into an instrumental (karaoke) version by removing the vocals
with [Demucs](https://github.com/adefossez/demucs).

Double-click a file, drag a folder of songs onto it, and get a `Karaoke`
folder next to your music containing 320 kbps MP3 instrumentals.

```
D:\Music\Album A\  Highway to AI.mp3        ->  Karaoke\Highway to AI (Instrumental).mp3
```

## Windows or macOS?

| Platform | Where | Start with |
| --- | --- | --- |
| Windows 10/11 | repository root | `Setup Karaoke Tracks.bat`, then `Make Karaoke Tracks.bat` |
| macOS 11+ | [`macos/`](macos/) | `Setup Karaoke Tracks.command`, then `Make Karaoke Tracks.command` |

Both do the same job and share the same behaviour; only the shell differs
(batch + PowerShell versus bash 3.2 and `.command` files). Each folder has
its own `readme.txt` with the full instructions - start there.

## What is in each folder

| File | Purpose |
| --- | --- |
| `Make Karaoke Tracks.*` | Everyday launcher. Loads the environment, then runs the script. |
| `Setup Karaoke Tracks.*` | One-time installer: Python, Demucs, PyTorch, ffmpeg. |
| `readme.txt` | **The full manual** - start here. |

On Windows the launcher and script are separate files (`.bat` + `.ps1`); on
macOS a single `.command` file does both.

## Quick start

1. Double-click `Setup Karaoke Tracks` (once per PC).
2. Windows: drag a folder of songs onto `Make Karaoke Tracks.bat`.
   macOS: double-click `Make Karaoke Tracks.command` and drag the folder into
   the Terminal window it opens.
3. Open the new `Karaoke` folder when it says Finished.

Setup asks one question if it finds a suitable GPU: whether to install the
accelerated build of PyTorch (2-3 GB, roughly 5-10x faster than the CPU).
Without one, expect several minutes per song; with one, a minute or two.

Requirements: Windows 10/11 (64-bit) or macOS 11+, internet for the first
run, about 6 GB of free disk space.

## Options

```bat
:: Windows
"Make Karaoke Tracks.bat" "D:\Music\Album A"           :: process a folder
"Make Karaoke Tracks.bat" "D:\Music\Album A" -DryRun    :: show what would happen
"Make Karaoke Tracks.bat" "D:\Music\Album A" -Device cuda
```

```bash
# macOS
./"Make Karaoke Tracks.command" -i ~/Music/Album -n     # dry run
./"Make Karaoke Tracks.command" -i ~/Music/Album -d mps # Apple Silicon GPU
```

Also: `-OutputPath` / `-o`, `-Reconvert` / `-r`.


## Design notes

- **Nothing is destructive.** Source files are only read; outputs are new
  MP3s. Re-running skips tracks that already have an output file.
- **One temp folder per track**, deleted afterwards, so an interrupted run
  cannot leave a stale result that looks like a success.
- **The output folder is excluded from the scan**, so it never converts its
  own output.
- **Duplicate song names** across subfolders get a `(2)` suffix instead of
  overwriting each other.
- **The model folder is discovered, not assumed**, so it works with
  `htdemucs_ft` and the other Demucs models.
- Filtering is done on the file extension, because `Get-ChildItem -Include`
  is silently ignored when combined with `-LiteralPath`.
- **macOS keeps bash 3.2 compatibility** (the version Apple ships): no
  associative arrays, so duplicate detection uses a newline-separated string
  plus a quoted `case` pattern - which also means song names containing
  `[ ] * ?` are matched literally.
- **The macOS scripts skip `/usr/bin/python3` unless the Command Line Tools
  are installed**, because that stub pops a GUI installer dialog when run.

## Requirements

Python 3.9+, `demucs`, `ffmpeg`. Setup installs all of these into a private
`venv` folder, so nothing else on the machine is affected. `venv/` and
`tools/` are ignored by git - they are rebuilt per machine.

On macOS, Setup prefers Homebrew for ffmpeg and falls back to a
self-contained `imageio-ffmpeg` binary inside the venv, so no administrator
password or Homebrew is strictly required.

## Licence

Provided as-is for personal use. Karaoke tracks made from a recording you do
not own the rights to may breach those rights - check before publishing.

Demucs is by Alexandre Défossez and contributors, MIT licensed.
