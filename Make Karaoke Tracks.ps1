<#
    Make Karaoke Tracks
    -------------------
    Strips vocals with Demucs and writes 320 kbps MP3 instrumentals into a
    "Karaoke" folder.

    Normal use:
        Double-click "Make Karaoke Tracks.bat"  (it activates the environment,
        then runs this script).  Or drag a music folder onto the .bat file.

    Manual use:
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\Make Karaoke Tracks.ps1"
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\Make Karaoke Tracks.ps1" -InputPath "D:\Music\Album"
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\Make Karaoke Tracks.ps1" -Device cuda

    Switches:
        -InputPath    Folder (or single file) to scan.
                      Default: the folder this script lives in.
        -OutputPath   Where the MP3s go. Default: <InputPath>\Karaoke
        -Device       cpu | cuda | mps.  Omit to let Demucs pick.
        -Reconvert    Redo files that already exist in the Karaoke folder.
        -DryRun       Show what would happen without running Demucs.
#>
[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$OutputPath,
    [ValidateSet('', 'cpu', 'cuda', 'mps')]
    [string]$Device = '',
    [switch]$Reconvert,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Make a portable ffmpeg installed by Setup visible without touching PATH.
$portableFfmpeg = Join-Path $PSScriptRoot 'tools\ffmpeg\bin'
if ((Test-Path -LiteralPath $portableFfmpeg) -and ($env:PATH -notlike "*$portableFfmpeg*")) {
    $env:PATH = "$portableFfmpeg;$env:PATH"
}

$script:LogFile = $null
$script:Failed  = New-Object System.Collections.Generic.List[string]
$startedAt      = Get-Date

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    if ($script:LogFile) {
        try {
            Add-Content -LiteralPath $script:LogFile -Encoding UTF8 `
                -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
        } catch { }
    }
}

function Get-CleanPath($prompt) {
    $p = Read-Host $prompt
    return $p.Trim().Trim('"').Trim("'")
}

function Stop-WithMessage($msg) {
    Write-Log $msg 'Red'
    Write-Host ''
    exit 1
}

function Get-AudioFiles {
    param([string]$Root, [string]$ExcludePrefix)

    # NOTE: -Include is ignored when combined with -LiteralPath, so filter by
    # extension explicitly instead of trusting the wildcard.
    $wanted = @('.mp3', '.wav', '.flac', '.m4a', '.ogg')
    $items = @(Get-ChildItem -LiteralPath $Root -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $wanted -contains $_.Extension.ToLowerInvariant() })

    if ($ExcludePrefix) {
        $items = @($items | Where-Object {
                -not $_.FullName.StartsWith($ExcludePrefix, [StringComparison]::OrdinalIgnoreCase)
            })
    }
    return @($items | Sort-Object -Property FullName)
}

# ------------------------------------------------------------------ tools ----
$demucsExe = $null
$demucsPre = @()

if (-not $DryRun) {
    $cmd = Get-Command demucs -ErrorAction SilentlyContinue
    if ($cmd) {
        $demucsExe = $cmd.Source
    }
    else {
        # demucs not on PATH: try the installed Python module instead.
        $candidates = @(
            @{ Exe = 'python'; Launcher = @() }
            @{ Exe = 'py'; Launcher = @('-3') }
        )
        foreach ($cand in $candidates) {
            $e = Get-Command $cand.Exe -ErrorAction SilentlyContinue
            if (-not $e) { continue }
            if ($e.Source -like '*\WindowsApps\*') { continue }   # Microsoft Store stub
            $probe = @($cand.Launcher) + @('-c', 'import demucs')
            & $e.Source @probe *> $null
            if ($LASTEXITCODE -eq 0) {
                $demucsExe = $e.Source
                $demucsPre = @($cand.Launcher) + @('-m', 'demucs.separate')
                break
            }
        }
    }

    if (-not $demucsExe) {
        Stop-WithMessage @"
Demucs was not found.

  Current Python : $((Get-Command python -ErrorAction SilentlyContinue).Source)
  Current PATH   : $env:PATH

Easiest: double-click "Setup Karaoke Tracks.bat" in this folder - it installs Python, Demucs and ffmpeg.
  1. Install it:            pip install -U demucs
  2. Use a venv:            put a "venv" or ".venv" folder next to the .bat file
  3. Use conda:             edit the .bat file and set  CONDA_ENV=your_env_name

See readme.txt for the full setup.
"@
    }

    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        Stop-WithMessage @"
ffmpeg was not found on PATH.

Demucs needs ffmpeg to write MP3 files.
  - install it:   winget install Gyan.FFmpeg     (then reopen the window)
  - or point at it: edit the .bat file and set  EXTRA_PATH=C:\path\to\ffmpeg\bin
"@
    }

    Write-Log ('Demucs  : ' + ((@($demucsExe) + $demucsPre) -join ' ')) 'DarkGray'
    if ($Device) { Write-Log ("Device  : {0}" -f $Device) 'DarkGray' }
}

# ------------------------------------------------------------------ input ----
if (-not $InputPath) {
    if ($PSScriptRoot -and (Test-Path -LiteralPath $PSScriptRoot -PathType Container)) {
        $InputPath = $PSScriptRoot
    }
    else {
        $InputPath = (Get-Location).Path
    }
}

# A dropped file means "process the folder it lives in".
if (Test-Path -LiteralPath $InputPath -PathType Leaf) {
    $InputPath = Split-Path -Parent (Resolve-Path -LiteralPath $InputPath).Path
}

while (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
    Write-Warning "Not a folder: $InputPath"
    $InputPath = Get-CleanPath "Paste the INPUT folder path (your source songs)"
    if (-not $InputPath) { Stop-WithMessage 'Cancelled.' }
}
$inFull = (Resolve-Path -LiteralPath $InputPath).Path

# ----------------------------------------------------------------- output ----
if (-not $OutputPath) { $OutputPath = Join-Path $inFull 'Karaoke' }
if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
    Stop-WithMessage "Output path is a file, not a folder: $OutputPath"
}
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
$outFull = (Resolve-Path -LiteralPath $OutputPath).Path

if ($outFull -eq $inFull) {
    Stop-WithMessage "Output folder must be different from the input folder."
}

$script:LogFile = Join-Path $outFull '_karaoke log.txt'
Add-Content -LiteralPath $script:LogFile -Encoding UTF8 `
    -Value ("`r`n===== run {0} | input: {1} =====" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $inFull)

# Never re-scan our own output (it is usually inside the input folder).
$outPrefix = $outFull.TrimEnd('\') + '\'
if (-not $outPrefix.StartsWith($inFull, [StringComparison]::OrdinalIgnoreCase)) {
    $outPrefix = $null
}

Write-Log "Input   : $inFull" 'DarkGray'
Write-Log "Output  : $outFull" 'DarkGray'
Write-Log 'Scanning...' 'DarkGray'
$files = Get-AudioFiles -Root $inFull -ExcludePrefix $outPrefix

while ($files.Count -eq 0) {
    Write-Warning "No audio files (.mp3 .wav .flac .m4a .ogg) found in $inFull"
    $InputPath = Get-CleanPath "Paste a different INPUT folder path (Enter to cancel)"
    if (-not $InputPath) { Stop-WithMessage 'Cancelled.' }
    $inFull = (Resolve-Path -LiteralPath $InputPath).Path
    $files = Get-AudioFiles -Root $inFull
}

Write-Log "Found $($files.Count) audio file(s)." 'White'
Write-Host ''

$dupes = $files | Group-Object -Property BaseName | Where-Object { $_.Count -gt 1 }
if ($dupes) {
    Write-Warning 'Same file name in different folders - later copies get a (2), (3)... suffix:'
    foreach ($d in $dupes) { Write-Warning ("  {0}  x{1}" -f $d.Name, $d.Count) }
    Write-Host ''
}

# ------------------------------------------------------------------- loop ----
$used    = @{}
$i        = 0
$ok       = 0
$skipped  = 0
$tmpRoot  = Join-Path $env:TEMP 'demucs_karaoke'

foreach ($f in $files) {
    $i++
    $stem = $f.BaseName

    Write-Log ''
    Write-Log ("[{0}/{1}] {2}" -f $i, $files.Count, $f.Name) 'Cyan'

    # Pick a free output name (handles duplicate stems in one run).
    $base = "$stem (Instrumental)"
    $name = "$base.mp3"
    $d = 1
    while ($used.ContainsKey($name.ToLowerInvariant())) {
        $d++
        $name = "$base ($d).mp3"
    }
    $used[$name.ToLowerInvariant()] = $true
    $target = Join-Path $outFull $name

    if (-not $Reconvert -and (Test-Path -LiteralPath $target)) {
        Write-Log '    already done, skipping' 'DarkGray'
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Log "    would write -> $name" 'Yellow'
        $ok++
        continue
    }

    # Fresh temp folder per file: no stale results, no name clashes.
    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
    $tmp = Join-Path $tmpRoot ([guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null

    try {
        $cliArgs = @($demucsPre) + @('--two-stems=vocals', '--mp3', '--mp3-bitrate', '320', '-o', $tmp)
        if ($Device) { $cliArgs += @('-d', $Device) }
        $cliArgs += $f.FullName

        & $demucsExe @cliArgs
        $code = $LASTEXITCODE

        # Do not assume the model folder is called "htdemucs".
        $result = Get-ChildItem -LiteralPath $tmp -Recurse -File -Filter 'no_vocals.mp3' `
            -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($code -ne 0 -or -not $result -or $result.Length -le 0) {
            Write-Log "    FAILED: $($f.FullName)" 'Red'
            $script:Failed.Add($f.FullName)
            continue
        }

        Move-Item -LiteralPath $result.FullName -Destination $target -Force
        Write-Log "    -> $name" 'Green'
        $ok++
    }
    catch {
        Write-Log "    FAILED: $($f.FullName)`n    $($_.Exception.Message)" 'Red'
        $script:Failed.Add($f.FullName)
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- summary ----
Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

$elapsed = (Get-Date) - $startedAt
Write-Host ''
Write-Log ('-' * 60) 'DarkGray'
Write-Log ("Converted : {0}" -f $ok) 'Green'
if ($skipped) { Write-Log ("Skipped   : {0} (already existed)" -f $skipped) 'DarkGray' }
Write-Log ("Failed    : {0}" -f $script:Failed.Count) $(if ($script:Failed.Count) { 'Red' } else { 'Green' })
Write-Log ("Time      : {0:mm\:ss}" -f $elapsed) 'DarkGray'
Write-Log "Folder    : $outFull"

if ($script:Failed.Count -gt 0) {
    Write-Host ''
    Write-Log 'These files failed:' 'Red'
    foreach ($bad in $script:Failed) { Write-Log "  $bad" 'DarkYellow' }
    exit 1
}

if ($DryRun) {
    Write-Host ''
    Write-Log 'Dry run only - nothing was converted.' 'Yellow'
}
exit 0
