================================================================================
 KARAOKE TRACKS  (macOS)
 Makes instrumental (karaoke) versions of your songs by removing the vocals.

 Version 1.0   Requires: macOS 11 or newer, internet for the first run
================================================================================

It uses Demucs, an open source AI splitter. Each song is separated into
vocals and backing track; only the backing track is kept, saved as a 320 kbps
MP3 called "Song (Instrumental).mp3".


--------------------------------------------------------------------------------
 1. THE FILES - keep them together
--------------------------------------------------------------------------------

  Make Karaoke Tracks.command    the one you use every day
  Setup Karaoke Tracks.command   one-time installer - run this first
  readme.txt                     this file

On a Mac a ".command" file is a double-clickable script. Keep all three in
the same folder.


--------------------------------------------------------------------------------
 2. QUICK START
--------------------------------------------------------------------------------

  1. Double-click "Setup Karaoke Tracks.command"   (once per Mac)
  2. Double-click "Make Karaoke Tracks.command" and drop a folder of songs
     into the Terminal window when it asks
  3. The finished MP3s appear in a "Karaoke" folder and open automatically

Read on if anything asks you a question.

IMPORTANT - if macOS refuses to run it
  Files that came from the internet or a USB stick are often blocked, and
  copying can strip the permission that makes them double-clickable. Open
  Terminal, type  cd  then a space, drag this folder into the window, press
  Return, then paste this and press Return:

      chmod +x *.command && xattr -dr com.apple.quarantine .

  That is safe: it only marks these two files as runnable and removes the
  "downloaded" flag. Then double-click Setup again.

  If macOS still says the developer cannot be verified, go to
  System Settings - Privacy & Security and click "Open Anyway".


--------------------------------------------------------------------------------
 3. FIRST TIME ONLY: SETUP
--------------------------------------------------------------------------------

Double-click "Setup Karaoke Tracks.command". A check first, if you prefer -
this changes nothing:

      ./"Setup Karaoke Tracks.command" -c

What Setup does:

  * Looks for Python 3.9 or newer. macOS no longer includes a usable Python,
    so if it is missing you get three options: the free Command Line Tools
    (xcode-select --install), the python.org installer, or Homebrew.
  * Creates a private "venv" folder next to these files and installs Demucs
    and PyTorch into it. Your system Python is left alone, and no admin
    password is needed.
  * Installs ffmpeg. It uses Homebrew if you have it; otherwise it fetches a
    self-contained copy into the venv.
  * Runs a self test with a 6 second tone and tells you whether a karaoke
    file came out.

Download size is roughly 1-2 GB and it takes 5-15 minutes, mostly waiting.
You need about 5 GB free.

Other switches
      -c   check only, change nothing
      -f   force a reinstall
      -s   skip the self test

Setup is safe to run repeatedly; it only installs what is missing.


--------------------------------------------------------------------------------
 4. EVERYDAY USE
--------------------------------------------------------------------------------

  Double-click "Make Karaoke Tracks.command". Terminal opens and asks:

      Where are your songs?
      (tip: drag the folder into this window and press Return)
      Folder [~/Music]:

  Drag the folder of songs into the Terminal window - the path is typed in for
  you - then press Return. Press Return on its own to use ~/Music, or press
  Control-C to cancel.

  You can also start it with the folder in advance:

      ./"Make Karaoke Tracks.command" -i ~/Music/Album

WHAT YOU GET
  A folder named "Karaoke" next to your songs:

      ~/Music/Album/  Some Song.mp3
      ~/Music/Album/  Another Song.flac

      becomes

      ~/Music/Album/Karaoke/  Some Song (Instrumental).mp3
      ~/Music/Album/Karaoke/  Another Song (Instrumental).mp3

  Your originals are never modified, renamed or deleted. Subfolders are
  included, and every result lands in the one Karaoke folder at the top.

  While it runs the Mac is kept awake automatically, and the folder opens
  with a notification when it finishes.

INPUT FORMATS
  .mp3  .wav  .flac  .m4a  .ogg      (anything else is ignored)


--------------------------------------------------------------------------------
 5. OPTIONS
--------------------------------------------------------------------------------

  -i DIR    input folder (default: asks, offering ~/Music)
  -o DIR    output folder (default: INPUT/Karaoke)
  -d DEV    cpu or mps    (mps = Apple Silicon graphics chip/GPU)
  -r        reconvert tracks that already exist
  -n        dry run: list what would happen, convert nothing
  -q        quiet: do not open the Karaoke folder at the end
  -h        help

Examples

      ./"Make Karaoke Tracks.command" -i ~/Music/Album -n
      ./"Make Karaoke Tracks.command" -i ~/Music/Album -d mps
      ./"Make Karaoke Tracks.command" -i ~/Music/Album -o ~/Desktop/Karaoke

Running again is cheap: tracks that already have a matching file in the
Karaoke folder are skipped, so an interrupted batch can be restarted without
redoing finished work. Use -r to force everything again.


--------------------------------------------------------------------------------
 6. SPEED
--------------------------------------------------------------------------------

  Apple Silicon (M1 and later): try  -d mps  first. If a track fails with an
  MPS error, that song is not supported on the GPU - rerun it with -d cpu.

  Rough guide:
      Apple Silicon GPU (mps)   a minute or two per song
      Apple Silicon CPU         several minutes per song
      Intel Mac CPU             10 to 25 minutes per song

  Try two songs before committing to a whole library, and know that a 2015
  MacBook Air will not enjoy this job.

  Plug the laptop in, and leave "Prevent automatic sleeping" alone - the
  script uses caffeinate to hold the Mac awake while it works.


--------------------------------------------------------------------------------
 7. GOOD TO KNOW
--------------------------------------------------------------------------------

  * A log is written to "Karaoke/_karaoke log.txt", and setup writes
    "setup log.txt" in this folder. Use them if a window closed too soon.

  * Two songs with the same name in different subfolders both survive: the
    second becomes "Name (Instrumental) (2).mp3".

  * Each song is processed in a temporary folder that is deleted afterwards,
    so a crash never leaves a half-finished file looking like a success.

  * The Karaoke folder is never scanned as input, so it cannot convert its
    own output twice.

  * A crash or Control-C in the middle of a song wastes only that song.

  * Best quality comes from WAV or FLAC. Heavy reverb, a cappella passages
    and solo voices with lots of echo can leave ghostly artefacts; that is a
    limit of the AI model, not of this script.

  * To keep it handy, drag "Make Karaoke Tracks.command" to the right side of
    the Dock. Clicking it opens Terminal; then drag a folder of songs into
    that window.

  * Path length matters less than on Windows, but very long folder names can
    still upset ffmpeg; keep paths reasonable.


--------------------------------------------------------------------------------
 8. TROUBLESHOOTING
--------------------------------------------------------------------------------

"Demucs is not installed yet"
    Run "Setup Karaoke Tracks.command" first.

"ffmpeg was not found"
    Run Setup again - it installs ffmpeg. If you prefer Homebrew:
        brew install ffmpeg

"zsh: permission denied" or double-click does nothing
    chmod +x *.command     (see section 2 for the full one-liner)

"cannot be opened because it is from an unidentified developer"
    System Settings - Privacy & Security - Open Anyway. Or:
        xattr -dr com.apple.quarantine .

"xcrun: error: invalid active developer path"
    Your Command Line Tools are missing or broken:
        xcode-select --install

pip fails while building a wheel
    Usually a Python version newer than PyTorch supports. Install python@3.12
    with Homebrew, then run Setup again:
        brew install python@3.12

It looks stuck on the first song
    It is downloading the Demucs model, a few hundred MB, once per Mac. Give
    it a few minutes, or run it again later - the model is cached.

Every song says FAILED
    Open "Karaoke/_karaoke log.txt" and scroll up in Terminal: the real
    Python error is there. Usual causes: Setup was never run, the model
    download was blocked by a firewall, or the file is not real audio.

MPS errors on an Apple Silicon Mac
    Not every track works on the GPU. Rerun with -d cpu, or just leave -d out
    and it uses the processor.

The Mac went to sleep and the job stalled
    Keep the lid open and stay plugged in. Rerun the same command: finished
    tracks are skipped.


--------------------------------------------------------------------------------
 9. GIVING IT TO SOMEONE ELSE
--------------------------------------------------------------------------------

Send the folder without "venv", "tools" and "setup log.txt" - those are
rebuilt on their machine. On a Mac, zip it with Finder (right-click,
Compress) so permissions survive, and tell them to read section 2 about the
chmod/xattr one-liner, then run Setup.

They need about 5 GB free and an internet connection.


--------------------------------------------------------------------------------
 10. WHAT IT IS MADE OF
--------------------------------------------------------------------------------

Bash 3.2 (the version macOS ships) calling Demucs
(https://github.com/adefossez/demucs), an open source source-separation
model. No songs or audio are included. Removing vocals from a recording you
do not own the rights to may breach those rights - check before publishing
anything you make.

================================================================================
 Still stuck? In Terminal, in this folder:

      ./"Setup Karaoke Tracks.command" -c

 and read the report it prints.
================================================================================
