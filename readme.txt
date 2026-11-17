================================================================================
 KARAOKE TRACKS
 Makes instrumental (karaoke) versions of your songs by removing the vocals.

 Version: 1.0    Requires: Windows 10 or 11 (64 bit), internet for first run
================================================================================

It uses Demucs, an AI splitter, on each song: vocals go one way, the backing
band the other. Only the backing track is kept, saved as a 320 kbps MP3 named
"Song (Instrumental).mp3".


--------------------------------------------------------------------------------
 1. THE FILES - keep them all in this folder
--------------------------------------------------------------------------------

  Make Karaoke Tracks.bat    the one you use every day
  Make Karaoke Tracks.ps1    the script behind it
  Setup Karaoke Tracks.bat   one-time installer - run this first
  Setup Karaoke Tracks.ps1   the script behind it
  readme.txt                 this file

Do not separate them. The .bat files run the .ps1 files in the same folder.


--------------------------------------------------------------------------------
 2. QUICK START
--------------------------------------------------------------------------------

  1. Double-click "Setup Karaoke Tracks.bat"  (once, on this computer)
  2. Drag a folder of songs onto "Make Karaoke Tracks.bat"
  3. Open the new "Karaoke" folder when the window says Finished

That is all. Details below, in case step 1 asks you something.


--------------------------------------------------------------------------------
 3. FIRST TIME ONLY: SETUP
--------------------------------------------------------------------------------

Double-click "Setup Karaoke Tracks.bat". Read-only check first, if you like:

      "Setup Karaoke Tracks.bat" -Check

What Setup does:

  * Looks for Python 3.9 or newer. If there is none it offers to install
    Python 3.12 with winget.
  * Looks for a working Demucs + PyTorch. If there is none it creates a
    private "venv" folder inside this folder and installs them there, so
    nothing else on the computer is touched.
  * Looks for ffmpeg (needed for MP3). Installs it with winget, or downloads
    a portable copy into ".\tools\ffmpeg".
  * Asks ONE question if you have an NVIDIA graphics card:

        Use the graphics card for separation (faster)?  [Y/n]

  * Finishes with a self test: it makes a 6 second test tone, runs it through
    the real script, and tells you if a karaoke file came out.

About the graphics card question
  Answer YES if you have an NVIDIA card and at least 4 GB to spare. Measured
  on a laptop without GPU acceleration, this tool ran at about nine times the
  length of the audio: a 3 minute song took roughly 25 minutes. A GPU normally
  cuts that to a minute or two. If you already have Python with a CPU-only
  PyTorch, Setup notices that and asks whether to build a separate
  GPU-enabled environment instead - that is the one to say yes to.

Space and time needed
  About 4-6 GB of disk (up to 8 GB with the CUDA download) and 5-20 minutes,
  mostly downloading. Do it on wifi, not on a metered connection.

Other Setup switches
      -Check        only report what is present or missing, change nothing
      -Force        reinstall even if it looks fine
      -Flavor cpu   or  -Flavor gpu    (skips the GPU question)
      -SkipTest     skip the self test

Setup is safe to run repeatedly; it only installs what is missing. If
something goes wrong, run it again - or look at "setup log.txt".


--------------------------------------------------------------------------------
 4. EVERYDAY USE
--------------------------------------------------------------------------------

WAY A - drag and drop (fastest)
  Drag a folder of songs, or a single song file, from Explorer and drop it
  onto "Make Karaoke Tracks.bat". That folder is processed where it is.

WAY B - double-click and type
  Double-click "Make Karaoke Tracks.bat". It asks for the folder that holds
  your songs; type or paste the path (right-click inside the window pastes).
  Press Enter with nothing typed to cancel.

WHAT YOU GET
  A folder named "Karaoke" appears next to your songs:

      D:\Music\Album A\  Highway to AI.mp3
      D:\Music\Album A\  Ball and Bar Chain.mp3

      becomes

      D:\Music\Album A\Karaoke\  Highway to AI (Instrumental).mp3
      D:\Music\Album A\Karaoke\  Ball and Bar Chain (Instrumental).mp3

  Your originals are never changed, renamed or deleted. Only new MP3s are
  written. If you drop a folder with subfolders, everything inside is picked
  up and the results all land in one "Karaoke" folder at the top.

INPUT FORMATS
  .mp3  .wav  .flac  .m4a  .ogg      (anything else is ignored)


--------------------------------------------------------------------------------
 5. OPTIONS
--------------------------------------------------------------------------------

Put these after the folder in a command prompt, or in a shortcut's target:

  -InputPath "D:\Music\Album A"    which folder to scan
  -OutputPath "E:\Out"             where the MP3s go (default: .\Karaoke)
  -Device cuda                     force the GPU - or -Device cpu
  -Reconvert                       redo songs that already have an output
  -DryRun                          only print what would happen

Example:

      cd /d "%USERPROFILE%\Downloads\Karaoke Tracks"
      "Make Karaoke Tracks.bat" "D:\Music\Album A" -Device cuda
      "Make Karaoke Tracks.bat" "D:\Music\Album A" -DryRun

Two useful habits:
  * Run -DryRun on a big library first to see the names and the count.
  * Running again is cheap: songs that already have a matching file in the
    Karaoke folder are skipped, so an interrupted batch can be restarted
    without redoing finished work.


--------------------------------------------------------------------------------
 6. GOOD TO KNOW
--------------------------------------------------------------------------------

  * Speed guide: a minute or two per song on a decent GPU (typically 5-10
    times faster than the processor); 10 to 25 minutes per song on a
    processor. Try two songs before committing to a library.

  * A log is written to "Karaoke\_karaoke log.txt". Use it if the window
    closed before you could read it.

  * Two songs with the same name in different subfolders both survive: the
    second is saved as "Name (Instrumental) (2).mp3".

  * Each song is worked on in a temporary folder that is deleted afterwards,
    so a crash never leaves a half-finished file pretending to be done.

  * The Karaoke folder is never scanned as input, so it cannot convert its
    own output a second time.

  * Very long paths can hit the 255 character Windows limit, because
    " (Instrumental)" adds 16 characters. Move the music nearer the drive
    root if that happens.

  * Best quality comes from WAV or FLAC sources. Heavy reverb, a cappella
    sections and solo voices with lots of echo can still leave ghostly
    artefacts - that is a limit of the AI model, not a bug here.

  * Close the window when it is idle, not while it is working; killing it
    mid-song wastes that song's work.

  * To make a shortcut on the desktop: right-click "Make Karaoke Tracks.bat"
    - Send to - Desktop. Drag songs onto that shortcut from anywhere.


--------------------------------------------------------------------------------
 7. TROUBLESHOOTING
--------------------------------------------------------------------------------

"Demucs was not found" or "ffmpeg was not found"
    Run "Setup Karaoke Tracks.bat" first. If you keep your own Python
    environment instead, edit the CONFIG block at the top of
    "Make Karaoke Tracks.bat":
        set "CONDA_ENV=name_of_your_env"
        set "VENV_DIR=C:\path\to\venv"
        set "EXTRA_PATH=C:\path\to\ffmpeg\bin"

"execution of scripts is disabled on this system"
    Use the .bat files - they already bypass that. Or once only, in
    PowerShell as Administrator:
        Set-ExecutionPolicy -Scope CurrentUser Bypass

Windows says the files came from another computer
    Right-click each file, Properties, tick Unblock. Or, in PowerShell run
    from inside this folder:
        Unblock-File ".\Make Karaoke Tracks.*", ".\Setup Karaoke Tracks.*"

Virus warning about the .bat file
    It only runs the few lines you can read in the file: it locates Python
    and calls the script. Excluding this folder from the scan is fine if you
    trust the source.

"CUDA out of memory", or it dies on long songs
    Use -Device cpu.

It looks stuck on the first song
    It is downloading the Demucs model, a few hundred MB, which happens once
    per machine. Try a second run: it should start working immediately.

Every song says FAILED
    Open "Karaoke\_karaoke log.txt" and scroll up in the window - the real
    Python error is there. The usual causes are that Setup was never run,
    the model download was blocked, or the file is not real audio.

Output sounds thin, or the vocals are still faintly there
    Normal for difficult material. To try the higher-quality model, open
    "Make Karaoke Tracks.ps1" and find the line that begins

        $cliArgs = @($demucsPre) + @('--two-stems=vocals', ...

    Insert the two extra items right after @($demucsPre):

        $cliArgs = @($demucsPre) + @('-n', 'htdemucs_ft',
            '--two-stems=vocals', '--mp3', '--mp3-bitrate', '320',
            '-o', $tmp)

    htdemucs_ft is slower and needs more memory - if the GPU runs out, launch
    with -Device cpu. Some mixes simply will not separate cleanly: that is the
    model, not the script. Undo the change by deleting the two added items.

Nothing happened when you double-clicked
    Look at the taskbar first - the black window sometimes opens behind other
    windows. If it really did nothing, right-click the .bat and choose Run as
    administrator, and if a blue "Windows protected your PC" box appears,
    click More info then Run anyway. See also the Unblock note above.


--------------------------------------------------------------------------------
 8. GIVING IT TO SOMEONE ELSE
--------------------------------------------------------------------------------

Zip this folder WITHOUT the "venv" and "tools" folders (they are the big
parts and are rebuilt on the other machine). Unzip anywhere - Desktop or
Documents is fine - and have them run "Setup Karaoke Tracks.bat" once, then
drag songs onto "Make Karaoke Tracks.bat". They need Python, which Setup can
install, and about 6 GB of free space.

--------------------------------------------------------------------------------
 9. WHAT IT IS MADE OF
--------------------------------------------------------------------------------

PowerShell and batch files that call Demucs (https://github.com/adefossez/
demucs), an open source source-separation model. No songs, lyrics or audio
are included. Removing vocals from a track you do not own the rights to may
breach those rights - check before publishing anything you make.

================================================================================
 Still stuck? Open a command prompt in this folder and run:
     "Setup Karaoke Tracks.bat" -Check
 and read the report it prints.
================================================================================
