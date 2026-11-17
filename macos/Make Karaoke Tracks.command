#!/bin/bash
#
#  Make Karaoke Tracks
#  Removes the vocals from songs with Demucs and writes 320 kbps MP3
#  instrumentals into a "Karaoke" folder next to the originals.
#
#  Double-click this file, or run it from Terminal:
#
#      ./"Make Karaoke Tracks.command"
#      ./"Make Karaoke Tracks.command" -i ~/Music/Album -d mps
#      ./"Make Karaoke Tracks.command" -i ~/Music/Album -n      (dry run)
#
#  Options:
#      -i DIR    input folder (default: asks, offering ~/Music)
#      -o DIR    output folder (default: INPUT/Karaoke)
#      -d DEV    cpu or mps     (mps = Apple Silicon graphics chip)
#      -r        reconvert tracks that already exist
#      -n        dry run: list what would happen, convert nothing
#      -q        quiet: do not open the Karaoke folder at the end
#      -h        this help
#
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1

# ---------------------------------------------------------------- colours ----
if [ -t 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
    YEL=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GRN=""; YEL=""; CYN=""; RST=""
fi

LOG=""
say() {   # $1 = message, $2 = optional colour
    printf '%s%s%s\n' "${2:-}" "$1" "$RST"
    if [ -n "$LOG" ]; then
        printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG" 2>/dev/null
    fi
}
die() { say ""; say "$1" "$RED"; say ""; exit 1; }

TMPDIRS=""
SEEN=""
LIST=""
caffeinate_pid=""
cleanup() {
    [ -n "$caffeinate_pid" ] && kill "$caffeinate_pid" 2>/dev/null
    for d in $TMPDIRS; do rm -rf "$d" 2>/dev/null; done
    
    [ -n "$LIST" ] && rm -f "$LIST"
}
trap cleanup EXIT INT TERM

usage() {
    cat <<'EOF'
Make Karaoke Tracks - turns songs into instrumental (karaoke) MP3s.

Usage:
  Double-click this file, or from Terminal:

    ./"Make Karaoke Tracks.command"                        asks for a folder
    ./"Make Karaoke Tracks.command" -i ~/Music/Album       process a folder
    ./"Make Karaoke Tracks.command" -i ~/Music/Album -n    dry run, no work

Options:
  -i DIR    input folder (default: asks, offering ~/Music)
  -o DIR    output folder (default: INPUT/Karaoke)
  -d DEV    cpu or mps    (mps = Apple Silicon graphics chip)
  -r        reconvert tracks that already exist
  -n        dry run: list what would happen, convert nothing
  -q        quiet: do not open the Karaoke folder at the end
  -h        this help

Output goes to a "Karaoke" folder next to your songs. Originals are never
modified. Running it again skips tracks that already have an output file.
EOF
    exit 0
}

# ------------------------------------------------------------------- args ----
IN=""; OUT=""; DEVICE=""; RECONVERT=0; DRY=0; QUIET=0

while [ $# -gt 0 ]; do
    case "$1" in
        -i|--input)    IN="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        -o|--output)   OUT="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        -d|--device)   DEVICE="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
        -r|--reconvert) RECONVERT=1; shift ;;
        -n|--dry-run)  DRY=1; shift ;;
        -q|--quiet)    QUIET=1; shift ;;
        -h|--help)     usage ;;
        *)             die "Unknown option: $1  (use -h for help)" ;;
    esac
done

# -------------------------------------------------------------- tool lookup --
# Prefer the private venv built by Setup, then anything already on PATH.
DEMUCS_CMD=()
CLT_OK=0
xcode-select -p >/dev/null 2>&1 && CLT_OK=1    # /usr/bin/python3 is a stub without it

if [ -x "$HERE/venv/bin/demucs" ]; then
    DEMUCS_CMD=("$HERE/venv/bin/demucs")
elif command -v demucs >/dev/null 2>&1; then
    DEMUCS_CMD=("$(command -v demucs)")
else
    for py in "$HERE/venv/bin/python3" python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
        [ "$py" = "/usr/bin/python3" ] && [ "$CLT_OK" -eq 0 ] && continue
        if command -v "$py" >/dev/null 2>&1; then
            if "$py" -c 'import demucs' >/dev/null 2>&1; then
                DEMUCS_CMD=("$py" "-m" "demucs.separate")
                break
            fi
        fi
    done
fi

if [ "${#DEMUCS_CMD[@]}" -eq 0 ]; then
    say "" 
    say "Demucs is not installed yet." "$RED"
    say ""
    say "Run 'Setup Karaoke Tracks.command' first (double-click it in Finder)." "$YEL"
    say "It installs Python, Demucs and ffmpeg into a private 'venv' folder here."
    say ""
    exit 1
fi

# ffmpeg: PATH, then a portable copy, then the venv (Setup puts one there
# when Homebrew is not available).
FFMPEG="$(command -v ffmpeg 2>/dev/null || true)"
[ -z "$FFMPEG" ] && [ -x "$HERE/tools/ffmpeg/bin/ffmpeg" ] && FFMPEG="$HERE/tools/ffmpeg/bin/ffmpeg"
[ -z "$FFMPEG" ] && [ -x "$HERE/venv/bin/ffmpeg" ] && FFMPEG="$HERE/venv/bin/ffmpeg"

if [ -z "$FFMPEG" ]; then
    say ""
    say "ffmpeg was not found." "$RED"
    say "Run 'Setup Karaoke Tracks.command' - it installs ffmpeg for you."
    exit 1
fi

# Make the tool folders visible to demucs' own subprocesses.
PATH="$HERE/venv/bin:$(dirname "$FFMPEG"):$PATH"
export PATH

say ""
say "Demucs  : ${DEMUCS_CMD[*]}" "$DIM"
say "ffmpeg  : $FFMPEG" "$DIM"
[ -n "$DEVICE" ] && say "Device  : $DEVICE" "$DIM"

# ------------------------------------------------------------------ input ----
if [ -z "$IN" ]; then
    default="$HOME/Music"
    [ -d "$HERE" ] || default=""
    # If this folder already holds songs, offer it instead.
    if [ -n "$(find "$HERE" -maxdepth 2 -type f \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.ogg' \) 2>/dev/null | head -n 1)" ]; then
        default="$HERE"
    fi

    say ""
    say "Where are your songs?" "$BOLD"
    say "(tip: drag the folder into this window and press Return)" "$DIM"
    printf 'Folder%s: ' "$([ -n "$default" ] && printf ' [%s]' "$default")"
    IFS= read -r IN || IN=""
    IN="${IN%$'\r'}"
    IN="${IN//\\ / }"                 # drag-and-drop escapes spaces
    IN="${IN%\"}"; IN="${IN#\"}"      # strip quotes
    IN="${IN%\'}"; IN="${IN#\'}"
    IN="$(printf '%s' "$IN" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$IN" ] && IN="$default"
    [ -z "$IN" ] && die "No folder given."
fi

# Expand a leading ~ that arrived as text.
case "$IN" in "~"*) IN="$HOME${IN#\~}" ;; esac

[ -d "$IN" ] || die "Not a folder: $IN"
IN="$(cd "$IN" && pwd)"

# ----------------------------------------------------------------- output ----
[ -z "$OUT" ] && OUT="$IN/Karaoke"
case "$OUT" in "~"*) OUT="$HOME${OUT#\~}" ;; esac
mkdir -p "$OUT" || die "Could not create the output folder: $OUT"
OUT="$(cd "$OUT" && pwd)"

[ "$IN" = "$OUT" ] && die "The output folder must be different from the input folder."

LOG="$OUT/_karaoke log.txt"
printf '\n===== run %s | input: %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$IN" >>"$LOG" 2>/dev/null

say "Input   : $IN" "$DIM"
say "Output  : $OUT" "$DIM"
say "Scanning..." "$DIM"

# --------------------------------------------------------------- file list ---
LIST="$(mktemp "${TMPDIR:-/tmp}/karaoke-list.XXXXXX")"
find "$IN" -type f \
    \( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' \
       -o -iname '*.m4a' -o -iname '*.ogg' \) \
    -not -path "$OUT/*" -print0 >"$LIST"

COUNT="$(tr -cd '\0' <"$LIST" | wc -c | tr -d ' ')"

if [ "$COUNT" -eq 0 ]; then
    say ""
    say "No audio files (.mp3 .wav .flac .m4a .ogg) found in:" "$YEL"
    say "  $IN"
    exit 1
fi

say "Found $COUNT audio file(s)."
say ""

# Keep the Mac awake while this runs (hours on CPU).
if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i -w $$ >/dev/null 2>&1 &
    caffeinate_pid=$!
fi

# ------------------------------------------------------------- name helper ---
# bash 3.2 (the macOS default) has no associative arrays, so names used so far
# in this run are kept in one newline-separated string. Quoting $1 inside the
# pattern makes it literal, so names containing [ ] * ? are safe.
USED_NAMES=$'\n'
NAME=""

name_used() {   # $1 = candidate file name
    case "$USED_NAMES" in
        *$'\n'"$1"$'\n'*) return 0 ;;
        *) return 1 ;;
    esac
}

pick_name() {   # $1 = stem ; sets NAME, registers it
    local base="$1 (Instrumental)" n=1
    NAME="$base.mp3"
    while name_used "$NAME"; do
        n=$((n + 1))
        NAME="$base ($n).mp3"
    done
    USED_NAMES="$USED_NAMES$NAME"$'\n'
}

# -------------------------------------------------------------------- loop ---
I=0; OK=0; SKIPPED=0; FAILED=0
FAILED_FILES=""

while IFS= read -r -d '' f; do
    I=$((I + 1))
    stem="$(basename "$f")"
    stem="${stem%.*}"

    say ""
    say "[$I/$COUNT] $(basename "$f")" "$CYN"

    pick_name "$stem"
    name="$NAME"
    target="$OUT/$name"

    if [ "$RECONVERT" -eq 0 ] && [ -e "$target" ]; then
        say "    already done, skipping" "$DIM"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ "$DRY" -eq 1 ]; then
        say "    would write -> $name" "$YEL"
        OK=$((OK + 1))
        continue
    fi

    # A fresh temp folder per track: no stale result can pass for success.
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/demucs.XXXXXX")" || continue
    TMPDIRS="$TMPDIRS $tmp"

    args=(--two-stems=vocals --mp3 --mp3-bitrate 320 -o "$tmp")
    [ -n "$DEVICE" ] && args+=(-d "$DEVICE")
    args+=("$f")

    "${DEMUCS_CMD[@]}" "${args[@]}"
    rc=$?

    result="$(find "$tmp" -type f -name 'no_vocals.mp3' 2>/dev/null | head -n 1)"

    if [ "$rc" -ne 0 ] || [ -z "$result" ] || [ ! -s "$result" ]; then
        say "    FAILED: $f" "$RED"
        FAILED=$((FAILED + 1))
        FAILED_FILES="$FAILED_FILES  $f"$'\n'
    else
        mv -f "$result" "$target"
        say "    -> $name" "$GRN"
        OK=$((OK + 1))
    fi

    rm -rf "$tmp" 2>/dev/null
done <"$LIST"

# ----------------------------------------------------------------- summary ---
say ""
say "------------------------------------------------------------" "$DIM"
say "Converted : $OK" "$GRN"
[ "$SKIPPED" -gt 0 ] && say "Skipped   : $SKIPPED (already existed)" "$DIM"
if [ "$FAILED" -gt 0 ]; then
    say "Failed    : $FAILED" "$RED"
else
    say "Failed    : 0" "$GRN"
fi
say "Folder    : $OUT"

if [ "$FAILED" -gt 0 ]; then
    say ""
    say "These files failed:" "$RED"
    printf '%s' "$FAILED_FILES"
    say ""
    say "Open '$OUT/_karaoke log.txt' and scroll up for the real error." "$YEL"
fi

if [ "$DRY" -eq 1 ]; then
    say ""
    say "Dry run only - nothing was converted." "$YEL"
fi

if [ "$QUIET" -eq 0 ] && [ -t 1 ]; then
    say ""
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$OK track(s) converted\" with title \"Make Karaoke Tracks\"" >/dev/null 2>&1
    fi
    open "$OUT" 2>/dev/null
fi

[ "$FAILED" -gt 0 ] && exit 1
exit 0
