#!/bin/bash
# ============================================================
# family_policy.sh  —  Hardcore Pop family defaults (LOCKED)
# ------------------------------------------------------------
# Source this from the master pipeline and from QC scripts:
#     . "$(dirname "$0")/family_policy.sh"
#
# Purpose: replace per-track reasoning about stereo widening
# with a single locked rule keyed off the v2 diagnostic's
# phase-correlation statistics. Encodes the family's standing
# decisions as parameters, not prose.
#
# NOTE ON SCOPE: bass-mono is staged here but DEFAULTS OFF, so
# sourcing this file changes NO existing master output. It only
# (a) formalizes the widening skip rule and (b) reserves the
# bass-mono parameters for the Stage D linear-phase build.
# Per framework rule: features are conditionally disabled,
# never deleted.
# ============================================================

# ---- House loudness targets (current single-target default) ----
TARGET_LUFS="-10.0"          # integrated, house standard (UNCHANGED default)
TARGET_TP_DBTP="-1.0"        # true peak ceiling, lossless/club path

# ---- Deliverable-specific loudness profiles (OPT-IN) ----
# Verified against 2026 platform behaviour:
#   streaming services normalize to ~-14 (Spotify/YouTube/Tidal/Amazon),
#   -16 (Apple/Deezer); loud-only services don't boost quiet tracks.
# Select a profile with: eval "$(policy_profile <name>)"
# Default behaviour (no call) keeps the -10.0 / -1.0 house standard,
# so existing sessions are byte-for-byte unaffected.
#
#   archival      : -10.0 LUFS / -1.0 dBTP   (current house standard)
#   club          :  -8.5 LUFS / -1.0 dBTP   (DJ/club, NOT normalized; PSR>=8)
#   streaming     : -14.0 LUFS / -1.5 dBTP   (services stop re-limiting it)
#
#   hiphop        :  -8.0 LUFS / -1.0 dBTP   (US hip-hop; dense, punchy; PSR>=8)
#   german_rap    :  -9.0 LUFS / -1.0 dBTP   (German chart rap; tighter LRA)
#   german_drill  :  -8.0 LUFS / -0.8 dBTP   (German drill; very dense, aggressive)
#   serbian_drill :  -8.5 LUFS / -1.0 dBTP   (Serbian drill; bass-heavy, aggressive)
#   house         :  -8.5 LUFS / -1.0 dBTP   (Club house; bass-heavy, wide stereo)
#
# NOTE: genre profiles are PRELIMINARY. Calibrate against 3-5 commercial
# references per genre using reference_benchmark.sh before relying on them.
policy_profile() {
    case "$1" in
      archival)      echo 'TARGET_LUFS="-10.0"; TARGET_TP_DBTP="-1.0"';;
      club)          echo 'TARGET_LUFS="-8.5";  TARGET_TP_DBTP="-1.0"';;
      streaming)     echo 'TARGET_LUFS="-14.0"; TARGET_TP_DBTP="-1.5"';;
      hiphop)        echo 'TARGET_LUFS="-8.0";  TARGET_TP_DBTP="-1.0"';;
      german_rap)    echo 'TARGET_LUFS="-9.0";  TARGET_TP_DBTP="-1.0"';;
      german_drill)  echo 'TARGET_LUFS="-8.0";  TARGET_TP_DBTP="-0.8"';;
      serbian_drill) echo 'TARGET_LUFS="-8.5";  TARGET_TP_DBTP="-1.0"';;
      house)         echo 'TARGET_LUFS="-8.5";  TARGET_TP_DBTP="-1.0"';;
      *) echo "echo 'unknown profile: $1 (use archival|club|streaming|hiphop|german_rap|german_drill|serbian_drill|house)' >&2; false";;
    esac
}

# ---- Stereo widening safety rule (LOCKED) ----
# Rule: widening is permitted ONLY if the per-frame MINIMUM phase
# correlation stays strictly above this threshold. Any negative
# minimum => widening is skipped. This is the family-wide rule
# that has consistently fired across Hardcore Pop tracks.
WIDENING_MIN_CORR_THRESHOLD="0.0"
WIDENING_EXTRASTEREO_M="1.0" # extrastereo kept at unity (inert), never removed

# ---- Genre-specific processing presets (OPT-IN, override per-stage params) ----
# When a genre profile is selected, these defaults replace the Hardcore Pop
# family EQ/compression defaults. They are STARTING POINTS only — bracket
# per-track as always.  All are overrideable via env vars.
# Load with: eval "$(policy_genre_presets <name>)"
policy_genre_presets() {
    case "$1" in
      hiphop)
        # Punchy low-mids, scooped mids, bright top for vocal intelligibility
        echo 'EQ_CHAIN="equalizer=f=150:t=q:w=1.0:g=1.2,equalizer=f=400:t=q:w=1.2:g=-1.0,equalizer=f=2500:t=q:w=1.5:g=0.8,equalizer=f=8000:t=q:w=0.8:g=1.2,equalizer=f=12000:t=q:w=0.7:g=1.0"'
        echo 'COMP="acompressor=threshold=-18dB:ratio=2.0:attack=15:release=150:makeup=2.0:knee=4"'
        ;;
      german_rap)
        # Tighter, cleaner; less sub-bass boost, more mid-forward
        echo 'EQ_CHAIN="equalizer=f=200:t=q:w=1.2:g=-0.5,equalizer=f=1000:t=q:w=1.5:g=0.8,equalizer=f=3000:t=q:w=1.5:g=0.6,equalizer=f=10000:t=q:w=0.8:g=0.8"'
        echo 'COMP="acompressor=threshold=-16dB:ratio=1.8:attack=20:release=180:makeup=1.5:knee=4"'
        ;;
      german_drill)
        # Aggressive sub-bass, darkened upper-mids, very tight limiting
        echo 'EQ_CHAIN="equalizer=f=80:t=q:w=1.4:g=1.5,equalizer=f=200:t=q:w=1.0:g=-1.0,equalizer=f=4000:t=q:w=1.5:g=-0.8,equalizer=f=10000:t=q:w=0.8:g=0.5"'
        echo 'COMP="acompressor=threshold=-20dB:ratio=2.5:attack=10:release=120:makeup=2.5:knee=2"'
        ;;
      serbian_drill)
        # Bass-dominant, heavy sub, reduced harshness in upper mids
        echo 'EQ_CHAIN="equalizer=f=60:t=q:w=1.2:g=1.8,equalizer=f=150:t=q:w=1.0:g=0.5,equalizer=f=3000:t=q:w=1.5:g=-1.0,equalizer=f=8000:t=q:w=0.8:g=0.6"'
        echo 'COMP="acompressor=threshold=-18dB:ratio=2.2:attack=12:release=140:makeup=2.2:knee=3"'
        ;;
      house)
        # Extended sub, warm low-mids, open top, wider stereo feel
        echo 'EQ_CHAIN="equalizer=f=50:t=q:w=1.0:g=1.0,equalizer=f=200:t=q:w=1.2:g=-0.8,equalizer=f=3000:t=q:w=1.5:g=1.0,equalizer=f=12000:t=q:w=0.7:g=1.5"'
        echo 'COMP="acompressor=threshold=-16dB:ratio=1.8:attack=25:release=200:makeup=1.5:knee=4"'
        ;;
      *) ;;  # default Hardcore Pop presets already in master_pipeline_v3.sh
    esac
}

# ---- Bass-mono / elliptical low-end (STAGED, default OFF) ----
# When enabled (Stage D rebuild, next thread), the SIDE channel is
# high-passed below BASS_MONO_FREQ with a linear-phase filter so the
# low end collapses to mono while width above is preserved.
BASS_MONO_ENABLE="0"         # 0 = preserve current behavior (no Stage D change yet)
BASS_MONO_FREQ="110"         # Hz, family starting point (plan: ~100-120 Hz)
BASS_MONO_PHASE="linear"     # linear | minimum  (linear strongly preferred)

# ------------------------------------------------------------
# policy_decide_widening <corr_min>
#   Echoes: SKIP | ALLOW   and a human-readable reason on stderr.
#   Deterministic; pure arithmetic comparison via awk.
# ------------------------------------------------------------
policy_decide_widening() {
    local cmin="$1"
    if [ -z "$cmin" ]; then
        echo "SKIP"
        echo "  policy: no correlation min provided -> conservative SKIP" >&2
        return 0
    fi
    local verdict
    verdict=$(awk -v m="$cmin" -v t="$WIDENING_MIN_CORR_THRESHOLD" \
        'BEGIN{ print (m+0 > t+0) ? "ALLOW" : "SKIP" }')
    echo "$verdict"
    if [ "$verdict" = "SKIP" ]; then
        echo "  policy: corr_min=$cmin <= threshold=$WIDENING_MIN_CORR_THRESHOLD -> widening SKIPPED (extrastereo held at m=$WIDENING_EXTRASTEREO_M)" >&2
    else
        echo "  policy: corr_min=$cmin > threshold=$WIDENING_MIN_CORR_THRESHOLD -> widening permitted" >&2
    fi
    return 0
}

# ------------------------------------------------------------
# policy_corr_min_from_report <report.txt>
#   Extracts corr_min from the v2 diagnostic's CORR_STATS footer.
# ------------------------------------------------------------
policy_corr_min_from_report() {
    local report="$1"
    grep '^CORR_STATS' "$report" 2>/dev/null | \
        sed -n 's/.*min=\([-0-9.]*\).*/\1/p' | head -1
}
