<#
    Setup for "Make Karaoke Tracks"
    -------------------------------
    Checks this PC for Python, Demucs/PyTorch and ffmpeg, and installs
    whatever is missing into a private "venv" folder next to these files
    (plus an optional portable ffmpeg in ".\tools\ffmpeg").

    Double-click "Setup Karaoke Tracks.bat" to run it.

    Switches:
        -Check      Only report what is present / missing. Changes nothing.
        -Force      Reinstall even if everything already looks fine.
        -Flavor     cpu  or  gpu   (skips the GPU/CPU question)
        -SkipTest   Do not run the end-of-setup self test.
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Force,
    [ValidateSet('', 'cpu', 'gpu')]
    [string]$Flavor = '',
    [switch]$SkipTest
)

$ErrorActionPreference = 'Continue'

$Root           = $PSScriptRoot
$venvDir        = Join-Path $Root 'venv'
$venvPy         = Join-Path $venvDir 'Scripts\python.exe'
$portableFfmpeg = Join-Path $Root 'tools\ffmpeg\bin'

# Make a portable ffmpeg (if present) visible without touching the system PATH.
if ((Test-Path -LiteralPath $portableFfmpeg) -and ($env:PATH -notlike "*$portableFfmpeg*")) {
    $env:PATH = "$portableFfmpeg;$env:PATH"
}

$logFile = Join-Path $Root 'setup log.txt'

function Say {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    if (-not $Check) {
        try {
            Add-Content -LiteralPath $logFile -Encoding UTF8 `
                -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
        } catch { }
    }
}

function Step { param([string]$Message) Write-Host ''; Say "=== $Message" 'Cyan' }

function Ask-Yes {
    param([string]$Question, [bool]$Default = $true)
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    $answer = (Read-Host "$Question $hint").Trim().ToLower()
    if ($answer -eq '') { return $Default }
    return ($answer -in @('y', 'yes'))
}

function Test-PythonHasDemucs {
    param([string]$Exe, [string[]]$Prefix = @())
    if (-not (Test-Path -LiteralPath $Exe)) { return $false }
    $probe = @($Prefix) + @('-c', 'import demucs, torch')
    & $Exe @probe *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-Ffmpeg {
    param([string]$Exe)
    if (-not $Exe -or -not (Test-Path -LiteralPath $Exe)) { return $false }
    & $Exe -version *> $null
    return ($LASTEXITCODE -eq 0)
}

# ============================================================ what do we have?
Say 'Make Karaoke Tracks - setup' 'White'
Say "Working folder: $Root"
if ($Check) { Say 'CHECK ONLY - nothing will be installed.' 'Yellow' }

$drive = ($Root -split ':')[0]
try {
    $freeGB = [math]::Round(((Get-PSDrive -Name $drive).Free / 1GB), 1)
    Say ("Free space on {0}: {1} GB" -f $drive, $freeGB)
    if ($freeGB -lt 6) {
        Say 'Less than 6 GB free. Demucs + PyTorch need roughly 4-6 GB. Make room first.' 'Red'
        exit 1
    }
} catch { }

# ---------------------------------------------------------------- interpreter
Step 'Python'

$usable = $null

if ((Test-Path -LiteralPath $venvPy) -and (Test-PythonHasDemucs $venvPy) -and -not $Force) {
    $usable = [pscustomobject]@{ Exe = $venvPy; Label = 'private venv (already set up)' }
}
else {
    $cands = @()
    $c = Get-Command demucs -ErrorAction SilentlyContinue
    if ($c -and $c.Source -and $c.Source -notlike '*\WindowsApps\*') { $cands += $c.Source }

    $searchDirs = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python')
        $env:ProgramFiles
        ${env:ProgramFiles(x86)}
        (Join-Path $env:USERPROFILE 'miniconda3')
        (Join-Path $env:USERPROFILE 'anaconda3')
        (Join-Path $env:LOCALAPPDATA 'miniconda3')
        (Join-Path $env:LOCALAPPDATA 'anaconda3')
        'C:\'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

    foreach ($dir in $searchDirs) {
        Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(Python|miniconda|anaconda|miniforge)' } |
            ForEach-Object {
                $p = Join-Path $_.FullName 'python.exe'
                if (Test-Path -LiteralPath $p) { $cands += $p }
            }
    }

    $cands = @($cands | Where-Object { $_ -notlike '*\Scripts\demucs.exe' } | Select-Object -Unique)

    if ($c.Count -gt 0) {
        # A demucs.exe exists somewhere: ask the python next to it.
        $sidePy = Join-Path (Split-Path -Parent $c.Source) 'python.exe'
        if (Test-Path -LiteralPath $sidePy) { $cands = @($sidePy) + $cands }
    }

    foreach ($cand in $cands) {
        if (Test-PythonHasDemucs $cand) {
            $usable = [pscustomobject]@{ Exe = $cand; Label = 'system Python (Demucs already installed)' }
            break
        }
    }
}

if ($usable) {
    Say "Found a working setup: $($usable.Exe)" 'Green'
    Say "  ($($usable.Label))"
    $script:UseVenv = $false
}
else {
    Say 'No Python with Demucs found - something has to be installed.' 'Yellow'

    $tryList = @()
    foreach ($name in @('python', 'py')) {
        $c = Get-Command $name -ErrorAction SilentlyContinue
        if ($c -and $c.Source -and $c.Source -notlike '*\WindowsApps\*') { $tryList += $c.Source }
    }
    foreach ($dir in @((Join-Path $env:LOCALAPPDATA 'Programs\Python'), $env:ProgramFiles, 'C:\')) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Python3' } |
                ForEach-Object {
                    $p = Join-Path $_.FullName 'python.exe'
                    if (Test-Path -LiteralPath $p) { $tryList += $p }
                }
    }

    $basePy = $null
    $baseVer = $null
    foreach ($cand in ($tryList | Select-Object -Unique)) {
        $ver = (& $cand -c 'import sys;print("%d.%d" % sys.version_info[:2])' 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $ver) { continue }
        $v = [version]($ver.Trim())
        if ($v.Major -eq 3 -and $v.Minor -ge 9) { $basePy = $cand; $baseVer = $ver.Trim(); break }
    }

    if (-not $basePy) {
        Say 'No Python 3.9 or newer found on this PC.' 'Red'
        if ($Check) { Say 'Would offer to install Python with winget.' 'Yellow'; exit 0 }

        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget -and (Ask-Yes 'Install Python 3.12 with winget now?' $true)) {
            Say 'winget install Python.Python.3.12 --scope user'
            & winget install --id Python.Python.3.12 -e --scope user --accept-source-agreements --accept-package-agreements
            Say 'If that worked, close this window and run Setup again (PATH needs to refresh).' 'Yellow'
            exit 1
        }
        Say 'Install Python from https://www.python.org/downloads/ (tick "Add python.exe to PATH"), then run Setup again.' 'Red'
        exit 1
    }

    Say ("Will build a private environment in .\venv using Python {0} ({1})" -f $baseVer, $basePy)
    $script:BasePy = $basePy
    $script:UseVenv = $true
}

# -------------------------------------------------------------------- device
Step 'Processor'

$gpuName = $null
$cudaTag = $null
$smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
if (Test-Path -LiteralPath $smi) {
    $names = & $smi --query-gpu=name --format=csv,noheader 2>$null
    if ($LASTEXITCODE -eq 0 -and $names) { $gpuName = ($names | Select-Object -First 1).Trim() }
    $smiOut = & $smi 2>$null | Out-String
    if ($smiOut -match 'CUDA Version:\s*(\d+\.\d+)') { $cudaTag = $Matches[1] }
}
if (-not $gpuName) {
    $gpuName = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1 -ExpandProperty Name)
}

if ($gpuName) {
    Say "Graphics card: $gpuName  (driver CUDA $cudaTag)" 'Green'
}
else {
    Say 'No NVIDIA graphics card detected - processor only.'
}

# A CPU-only PyTorch cannot use the GPU, even if one is fitted.
if (-not $script:UseVenv -and $gpuName -and -not $Check -and -not $Force) {
    & $usable.Exe -c "import torch, sys; sys.exit(0 if torch.cuda.is_available() else 1)" *> $null
    if ($LASTEXITCODE -ne 0) {
        Say 'That Python install has CPU-only PyTorch, but this PC does have a GeForce GPU.' 'Yellow'
        if (Ask-Yes 'Build a private GPU-enabled environment in .\venv instead (2-3 GB download)?' $true) {
            $script:BasePy = $usable.Exe
            $script:UseVenv = $true
            $Flavor = 'gpu'
        }
    }
}

if (-not $Flavor -and -not $Check) {
    if ($gpuName) {
        $Flavor = if (Ask-Yes 'Use the graphics card for separation (faster)?' $true) { 'gpu' } else { 'cpu' }
    }
    else { $Flavor = 'cpu' }
}
if (-not $Flavor) { $Flavor = 'cpu' }

Say ("Chosen: {0}" -f $Flavor.ToUpper()) 'White'
$device = if ($Flavor -eq 'gpu') { 'cuda' } else { 'cpu' }

if ($Check) {
    Write-Host ''
    Say 'Check only - nothing was changed. Run Setup again without -Check to install.' 'Yellow'
    exit 0
}

# --------------------------------------------------------------------- ffmpeg
Step 'ffmpeg'

$ffmpeg = $null
$ff = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ff -and (Test-Ffmpeg $ff.Source)) {
    $ffmpeg = $ff.Source
    Say "Already on PATH: $ffmpeg" 'Green'
}
elseif (Test-Ffmpeg (Join-Path $portableFfmpeg 'ffmpeg.exe')) {
    $ffmpeg = Join-Path $portableFfmpeg 'ffmpeg.exe'
    Say "Already present: $ffmpeg" 'Green'
}
else {
    Say 'ffmpeg is missing (needed to read and write MP3).' 'Yellow'

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Say 'Trying: winget install Gyan.FFmpeg'
        & winget install --id Gyan.FFmpeg -e --scope user --accept-source-agreements --accept-package-agreements
        $wingetFf = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') `
                -Filter 'ffmpeg.exe' -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like '*\bin\*' } | Select-Object -First 1
        if ($wingetFf -and (Test-Ffmpeg $wingetFf.FullName)) {
            $ffmpeg = $wingetFf.FullName
            Say "Installed to: $ffmpeg" 'Green'
        }
    }

    if (-not $ffmpeg) {
        Say 'Falling back to a portable copy inside .\tools\ffmpeg'
        $url  = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
        $zip  = Join-Path $env:TEMP 'ffmpeg-setup.zip'
        $dest = Join-Path $env:TEMP 'ffmpeg-setup-x'
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 900
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
            $binFile = Get-ChildItem -LiteralPath $dest -Filter 'ffmpeg.exe' -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Directory.Name -eq 'bin' } | Select-Object -First 1
            if ($binFile) {
                New-Item -ItemType Directory -Force -Path $portableFfmpeg | Out-Null
                Copy-Item -Path (Join-Path $binFile.Directory.FullName '*') -Destination $portableFfmpeg -Recurse -Force
                $cand = Join-Path $portableFfmpeg 'ffmpeg.exe'
                if (Test-Ffmpeg $cand) { $ffmpeg = $cand; Say "Portable ffmpeg ready: $cand" 'Green' }
            }
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            Say "Download failed: $($_.Exception.Message)" 'Red'
        }
    }

    if (-not $ffmpeg) {
        Say 'Could not install ffmpeg automatically.' 'Red'
        Say 'Install it yourself (winget install Gyan.FFmpeg, or https://www.gyan.dev/ffmpeg/builds/) and put its bin folder on PATH, then try again.'
        exit 1
    }
}

# ------------------------------------------------------------------- packages
Step 'Packages'

if (-not $script:UseVenv) {
    Say 'Nothing to install - Demucs and PyTorch are already available.' 'Green'
    $pyForTest = $usable.Exe
}
else {
    if (-not (Test-Path -LiteralPath $venvPy)) {
        Say ("Creating venv: {0}" -f $venvDir)
        & $script:BasePy -m venv $venvDir
        if (-not (Test-Path -LiteralPath $venvPy)) {
            Say 'Could not create the venv. Try running: python -m venv venv' 'Red'
            exit 1
        }
    }
    else { Say "Reusing existing venv: $venvDir" }

    $pyForTest = $venvPy

    Say 'Upgrading pip...'
    & $venvPy -m pip install --upgrade pip --disable-pip-version-check --quiet *> $null

    if ($Flavor -eq 'gpu') {
        $idx = 'cu121'
        if ($cudaTag -and ([version]$cudaTag -lt [version]'12.0')) { $idx = 'cu118' }
        Say "Installing the CUDA build of PyTorch ($idx). Big download, about 2-3 GB..." 'White'
        & $venvPy -m pip install torch torchaudio --index-url "https://download.pytorch.org/whl/$idx" --disable-pip-version-check
        if ($LASTEXITCODE -ne 0) { Say 'PyTorch install failed. Run Setup again, or answer "no" to the GPU question.' 'Red'; exit 1 }
    }

    Say 'Installing demucs and its dependencies...' 'White'
    & $venvPy -m pip install demucs --disable-pip-version-check
    if ($LASTEXITCODE -ne 0) { Say 'demucs install failed. Check the internet connection and run Setup again.' 'Red'; exit 1 }

    Step 'Verify'
    $verLine = & $venvPy -c 'import torch, demucs; print("torch", torch.__version__, "| cuda available:", torch.cuda.is_available())' 2>&1
    if ($LASTEXITCODE -ne 0) { Say "Import check failed:`n$verLine" 'Red'; exit 1 }
    Say " $verLine" 'Green'
}

# Final sanity check: only claim the GPU if torch can actually see it.
if ($device -eq 'cuda') {
    & $pyForTest -c "import torch, sys; sys.exit(0 if torch.cuda.is_available() else 1)" *> $null
    if ($LASTEXITCODE -ne 0) {
        Say 'PyTorch in use is CPU-only, so the processor will be used instead.' 'Yellow'
        $device = 'cpu'
    }
}

# Let the self test find the freshly installed tools without restarting.
if (Test-Path -LiteralPath (Join-Path $venvDir 'Scripts')) {
    $env:PATH = (Join-Path $venvDir 'Scripts') + ';' + $env:PATH
}

# ------------------------------------------------------------------ self test
if ($SkipTest) {
    Write-Host ''
    Say 'Self test skipped (-SkipTest).' 'Yellow'
    exit 0
}

Step 'Self test'
Say 'Creating a 6 second test tone and running it through the real script.'
Say '(The first run also downloads the Demucs model, a few hundred MB. That only happens once.)'

$testDir = Join-Path $env:TEMP 'karaoke-selftest'
if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $testDir | Out-Null

& $ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=440:duration=6" -ar 44100 -ac 2 (Join-Path $testDir 'tone.wav') | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $testDir 'tone.wav'))) {
    Say 'Could not create the test tone, so the self test was skipped.' 'Yellow'
    exit 0
}

$mainScript = Join-Path $Root 'Make Karaoke Tracks.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $mainScript -InputPath $testDir -Device $device

$out = Get-ChildItem -LiteralPath (Join-Path $testDir 'Karaoke') -Filter '*.mp3' -ErrorAction SilentlyContinue
Write-Host ''
if ($out) {
    Say 'SELF TEST PASSED - instrumentals were produced:' 'Green'
    $out | ForEach-Object { Say ("  {0}  ({1:N0} KB)" -f $_.Name, ($_.Length / 1KB)) }
    Say 'Copy the two "Make Karaoke Tracks" files into a music folder and double-click the .bat.' 'White'
}
else {
    Say 'SELF TEST DID NOT PRODUCE A FILE - scroll up for the error message.' 'Red'
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
exit 0
