#!/bin/bash
# ============================================================
# metadata_tag.sh  —  delivery tagging + audio-MD5 record
# ------------------------------------------------------------
# Scriptable batch tagging via kid3-cli (ID3v2.4 for MP3; Vorbis
# comments for FLAC/Opus): title/artist/album/year/ISRC/artwork.
# Also writes the FFmpeg-computed MD5 of the DECODED AUDIO DATA to
# a sidecar .md5 — a determinism record that travels with the file.
# (bwfmetaedit would embed an equivalent MD5 in a WAV bext chunk,
# but it isn't in the Ubuntu repos; the plan notes FLAC is a better
# tagged-delivery format than WAV anyway.)
#
# Usage:
#   bash metadata_tag.sh <file> "Title" "Artist" "Album" YEAR ISRC [cover.jpg]
# ============================================================
set -e
F="$1"; TITLE="$2"; ARTIST="$3"; ALBUM="$4"; YEAR="$5"; ISRC="$6"; COVER="$7"
[ -z "$ISRC" ] && { echo 'Usage: metadata_tag.sh <file> "Title" "Artist" "Album" YEAR ISRC [cover.jpg]'; exit 1; }

kid3-cli -c "set title \"$TITLE\""   "$F"
kid3-cli -c "set artist \"$ARTIST\"" "$F"
kid3-cli -c "set album \"$ALBUM\""   "$F"
kid3-cli -c "set date \"$YEAR\""     "$F"
kid3-cli -c "set isrc \"$ISRC\""     "$F"
[ -n "$COVER" ] && [ -f "$COVER" ] && kid3-cli -c "set picture:\"$COVER\" \"cover\"" "$F"

# audio-data MD5 determinism record (decoded PCM, format-independent)
MD5=$(ffmpeg -hide_banner -i "$F" -map 0:a -f md5 - 2>/dev/null | sed 's/MD5=//')
echo "$MD5  $(basename "$F")  (decoded-audio MD5)" > "$F.md5"

echo "[metadata_tag] tagged $F"
echo "  audio MD5 -> $F.md5 : $MD5"
echo "  tags:"
kid3-cli -c "get" "$F" | grep -iE 'title|artist|album|date|isrc' | sed 's/^/    /'
