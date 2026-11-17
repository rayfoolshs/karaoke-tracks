#!/bin/bash
#
#  Setup Karaoke Tracks  (macOS)
#  One-time installer: Python 3, Demucs, PyTorch and ffmpeg, all kept inside
#  a private "venv" folder next to these scripts. Nothing else on the Mac is
#  touched and no admin password is needed.
#
#  Usage:
#      ./"Setup Karaoke Tracks.command"
#      ./"Setup Karaoke Tracks.command" -c      (check only, change nothing)
#      ./"Setup Karaoke Tracks.command" -f      (force a reinstall)
#      ./"Setup Karaoke Tracks.command" -s      (skip the self test)
#
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1

VENV="$HERE/venv"
VPY="$VENV/bin/python3"
VFFMPEG="$VENV/bin/ffmpeg"

if [ -t 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
    YEL=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; CYN=""; RST=""
fi

LOG="$HERE/setup log.txt"
CHECK=0; FORCE=0; SKIPTEST=0

say() {
    printf '%s%s%s\n' "${2:-}" "$1" "$RST"
    if [ "$CHECK" -eq 0 ]; then
        printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG" 2>/dev/null
    fi
}
step() { printf '\n'; say "=== $1" "$CYN"; }
die()  { printf '\n'; say "$1" "$RED"; printf '\n'; exit 1; }

usage() {
    cat <<'EOF'
Setup Karaoke Tracks (macOS) - one-time installer for Make Karaoke Tracks.

Usage:
  Double-click this file in Finder, or from Terminal:

    ./"Setup Karaoke Tracks.command"        install what is missing
    ./"Setup Karaoke Tracks.command" -c     check only, change nothing
    ./"Setup Karaoke Tracks.command" -f     force a reinstall
    ./"Setup Karaoke Tracks.command" -s     skip the self test

It installs Python (if needed), then Demucs, PyTorch and ffmpeg into a
private "venv" folder next to this file. Nothing else on the Mac is touched
and no administrator password is needed.
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c|--check)   CHECK=1; shift ;;
        -f|--force)   FORCE=1; shift ;;
        -s|--skip-test) SKIPTEST=1; shift ;;
        -h|--help)    usage ;;
        *)            die "Unknown option: $1" ;;
    esac
done

ask_yes() {   # $1 = question, $2 = default (y or n)
    local ans
    printf '%s [%s]: ' "$1" "$([ "${2:-y}" = "y" ] && printf 'Y/n' || printf 'y/N')"
    IFS= read -r ans || ans=""
    ans="$(printf '%s' "$ans" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
    if [ -z "$ans" ]; then
        [ "${2:-y}" = "y" ] && return 0 || return 1
    fi
    case "$ans" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

ver_ge_39() {   # $1 = python executable
    "$1" -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 9) else 1)' >/dev/null 2>&1
}

# ================================================================== header ===
say "" 
say "Make Karaoke Tracks - setup (macOS)" "$BOLD"
say "Working folder: $HERE"
[ "$CHECK" -eq 1 ] && say "CHECK ONLY - nothing will be installed." "$YEL"

say ""
say "macOS $(sw_vers -productVersion 2>/dev/null) on $(uname -m)"

# Running under Rosetta on Apple Silicon?
if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
    say "Note: this Terminal is running under Rosetta (Intel emulation)." "$YEL"
    say "      Separation will still work, just slower. Use a native"
    say "      Terminal.app for full speed."
fi

# Free space.
FREE_GB="$(df -g "$HERE" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d ' ')"
if [ -n "${FREE_GB:-}" ] && [ "$FREE_GB" -lt 6 ] 2>/dev/null; then
    die "Only ${FREE_GB} GB free. Demucs + PyTorch need about 5 GB. Free some space first."
fi
[ -n "${FREE_GB:-}" ] && say "Free space: ${FREE_GB} GB"

# Remove the quarantine flag that stops downloaded .command files running.
for f in "$HERE/Make Karaoke Tracks.command" "$HERE/Setup Karaoke Tracks.command"; do
    [ -f "$f" ] && xattr -d com.apple.quarantine "$f" >/dev/null 2>&1
done
chmod +x "$HERE"/*.command 2>/dev/null

# ================================================================== python ===
step "Python"

BASEPY=""
if [ "$FORCE" -eq 0 ] && [ -x "$VPY" ] && ver_ge_39 "$VPY"; then
    say "Private environment already works: $VPY" "$GRN"
else
    CLT_OK=0
    xcode-select -p >/dev/null 2>&1 && CLT_OK=1   # /usr/bin/python3 is a stub without it

    for cand in "$VPY" python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        [ "$cand" = "/usr/bin/python3" ] && [ "$CLT_OK" -eq 0 ] && continue
        if command -v "$cand" >/dev/null 2>&1 || [ -x "$cand" ]; then
            if ver_ge_39 "$cand"; then
                BASEPY="$cand"
                break
            fi
        fi
    done

    if [ -z "$BASEPY" ]; then
        say "No Python 3.9+ found." "$YEL"
        say ""
        say "macOS does not ship a usable Python for this. Two options:"
        say "  a) Enter   xcode-select --install   in Terminal, then run Setup again"
        say "  b) Install Python from https://www.python.org/downloads/"
        if command -v brew >/dev/null 2>&1; then
            say "  c) Homebrew is installed, so I can do: brew install python@3.12"
        fi
        say ""
        [ "$CHECK" -eq 1 ] && exit 0

        if command -v brew >/dev/null 2>&1 && ask_yes "Install Python with Homebrew now?" y; then
            brew install python@3.12 || die "Homebrew could not install Python."
            BASEPY="/opt/homebrew/bin/python3.12"
            [ -x "$BASEPY" ] || BASEPY="/usr/local/bin/python3.12"
            [ -x "$BASEPY" ] || die "Python installed but not found. Close this window, open a new Terminal, run Setup again."
        else
            die "Run Setup again once Python is available."
        fi
    fi

    PYVER="$("$BASEPY" -c 'import sys;print("%d.%d" % sys.version_info[:2])' 2>/dev/null)"
    say "Using Python $PYVER ($BASEPY)" "$GRN"

    case "$PYVER" in
        3.1[3-9]|3.[2-9][0-9])
            say "Note: PyTorch wheels often lag behind Python $PYVER." "$YEL"
            say "      If the install below fails, use python@3.12 from Homebrew." 
            ;;
    esac

    if [ "$CHECK" -eq 1 ]; then
        say "Would create: $VENV" "$YEL"
        exit 0
    fi

    if [ ! -x "$VPY" ] || [ "$FORCE" -eq 1 ]; then
        say "Creating private environment: $VENV"
        "$BASEPY" -m venv "$VENV" || die "Could not create the venv. Try: $BASEPY -m venv venv"
    fi
fi

# ============================================================================
# Everything below needs the check flag handled first.
if [ "$CHECK" -eq 1 ]; then
    step "Report"
    [ -x "$VPY" ] && say "python venv : $VPY" "$GRN" || say "python venv : missing (would be created)" "$YEL"
    if "$VPY" -c 'import demucs, torch' >/dev/null 2>&1; then
        say "demucs      : installed" "$GRN"
    else
        say "demucs      : missing (would be installed)" "$YEL"
    fi
    if command -v ffmpeg >/dev/null 2>&1 || [ -x "$VFFMPEG" ]; then
        say "ffmpeg      : available" "$GRN"
    else
        say "ffmpeg      : missing (would be installed)" "$YEL"
    fi
    say ""
    say "Nothing was changed." "$YEL"
    exit 0
fi

# ================================================================= packages ==
step "Packages"

"$VPY" -m pip install --upgrade pip --quiet --disable-pip-version-check 2>/dev/null

if "$VPY" -c 'import demucs, torch' >/dev/null 2>&1 && [ "$FORCE" -eq 0 ]; then
    say "Demucs and PyTorch are already installed." "$GRN"
else
    say "Installing demucs + PyTorch (about 1-2 GB, this takes a few minutes)..." "$BOLD"
    "$VPY" -m pip install --upgrade demucs --disable-pip-version-check || \
        die "pip could not install demucs. Check the internet connection and run Setup again."
fi

CHIP="$("$VPY" -c 'import torch, platform; print(platform.machine(), "| mps:", torch.backends.mps.is_available() if hasattr(torch.backends, "mps") else False)')"
say "Torch build : $CHIP" "$DIM"

# =================================================================== ffmpeg ==
step "ffmpeg"

if [ -x "$VFFMPEG" ] && "$VFFMPEG" -version >/dev/null 2>&1; then
    say "Already available: $VFFMPEG" "$GRN"
elif command -v ffmpeg >/dev/null 2>&1; then
    say "Already on PATH: $(command -v ffmpeg)" "$GRN"
else
    say "ffmpeg is missing (needed to read and write MP3)." "$YEL"

    if command -v brew >/dev/null 2>&1 && ask_yes "Install ffmpeg with Homebrew (recommended)?" y; then
        brew install ffmpeg || say "Homebrew could not install ffmpeg - trying a self-contained copy." "$YEL"
    fi

    if ! command -v ffmpeg >/dev/null 2>&1; then
        say "Fetching a self-contained ffmpeg into the venv..." 
        "$VPY" -m pip install --quiet imageio-ffmpeg --disable-pip-version-check || \
            die "Could not fetch ffmpeg. Install Homebrew (https://brew.sh) then run Setup again."
        INNER="$("$VPY" -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')"
        if [ -n "$INNER" ] && [ -x "$INNER" ]; then
            ln -sf "$INNER" "$VFFMPEG"
            chmod +x "$INNER" 2>/dev/null
            say "ffmpeg ready: $VFFMPEG" "$GRN"
        fi
    fi

    if ! command -v ffmpeg >/dev/null 2>&1 && { [ ! -x "$VFFMPEG" ] || ! "$VFFMPEG" -version >/dev/null 2>&1; }; then
        die "Still no working ffmpeg. Install Homebrew from https://brew.sh, then run Setup again."
    fi
fi

# ================================================================ self test ==
if [ "$SKIPTEST" -eq 1 ]; then
    say ""
    say "Self test skipped (-s)." "$YEL"
    exit 0
fi

step "Self test"
say "Making a 6 second test tone and running it through the real script."
say "(First run also downloads the Demucs model - a few hundred MB, once only.)"

TESTDIR="$(mktemp -d "${TMPDIR:-/tmp}/karaoke-selftest.XXXXXX")" || die "mktemp failed."
FF="$(command -v ffmpeg 2>/dev/null || printf '%s' "$VFFMPEG")"

"$FF" -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=440:duration=6" \
    -ar 44100 -ac 2 "$TESTDIR/tone.wav" || die "Could not create the test tone with ffmpeg."

DEVICE="cpu"
"$VPY" -c 'import torch,sys; sys.exit(0 if getattr(torch.backends,"mps",None) and torch.backends.mps.is_available() else 1)' >/dev/null 2>&1 && DEVICE="mps"

bash "$HERE/Make Karaoke Tracks.command" -i "$TESTDIR" -d "$DEVICE" -q
OUTFILE="$(find "$TESTDIR/Karaoke" -type f -name '*.mp3' 2>/dev/null | head -n 1)"

say ""
if [ -n "$OUTFILE" ]; then
    say "SELF TEST PASSED - produced: $(basename "$OUTFILE")" "$GRN"
    say "On this Mac, use -d $DEVICE for the fastest separation." "$DIM"
    say ""
    say "You can now double-click 'Make Karaoke Tracks.command'." "$BOLD"
    rm -rf "$TESTDIR"
else
    say "SELF TEST DID NOT PRODUCE A FILE - scroll up for the error." "$RED"
    say "The test folder was left at: $TESTDIR"
    exit 1
fi

exit 0
