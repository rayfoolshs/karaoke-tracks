# Karaoke Tracks

Turn any song into an instrumental (karaoke) version on Windows, by removing
the vocals with [Demucs](https://github.com/adefossez/demucs).

Double-click a file, drag a folder of songs onto it, and get a `Karaoke`
folder next to your music containing 320 kbps MP3 instrumentals.

```
D:\Music\Album A\  Highway to AI.mp3        ->  Karaoke\Highway to AI (Instrumental).mp3
```

## What is in here

| File | Purpose |
| --- | --- |
| `Make Karaoke Tracks.bat` | Everyday launcher. Loads the environment, then runs the script. |
| `Make Karaoke Tracks.ps1` | The conversion script (Demucs, one fresh temp folder per track). |
| `Setup Karaoke Tracks.bat` | One-time installer: Python, Demucs, PyTorch, ffmpeg. |
| `Setup Karaoke Tracks.ps1` | The install logic. |
| `readme.txt` | **The full manual** - start here. |

## Quick start

1. Double-click `Setup Karaoke Tracks.bat` (once per PC).
2. Drag a folder of songs onto `Make Karaoke Tracks.bat`.
3. Open the new `Karaoke` folder when the window says Finished.

Setup asks one question if it finds an NVIDIA GPU: whether to install the
CUDA build of PyTorch (2-3 GB, roughly 5-10x faster than the CPU). Without a
GPU, expect 10-25 minutes per song; with one, a minute or two.

Requirements: Windows 10/11 (64-bit), internet for the first run, about 6 GB
of free disk space.

## Options

```bat
"Make Karaoke Tracks.bat" "D:\Music\Album A"          :: process a folder
"Make Karaoke Tracks.bat" "D:\Music\Album A" -DryRun   :: show what would happen
"Make Karaoke Tracks.bat" "D:\Music\Album A" -Device cuda
```

Also: `-OutputPath`, `-Reconvert`.

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

## Requirements

Python 3.9+, `demucs`, `ffmpeg`. Setup installs all of these into a private
`venv` folder, so nothing else on the machine is affected. `venv/` and
`tools/` are ignored by git - they are rebuilt per machine.

## Licence

Provided as-is for personal use. Karaoke tracks made from a recording you do
not own the rights to may breach those rights - check before publishing.

Demucs is by Alexandre Défossez and contributors, MIT licensed.
