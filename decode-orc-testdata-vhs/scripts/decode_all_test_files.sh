#!/bin/bash
# Decode all test .flac files from vhs-decode testdata

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Decode SVHS PAL test file
INPUT="$BASE_DIR/flac/pal/yc/SVHS_PAL_EBU_Bars_MISRC_V2.5_40msps_12_bit_16_frames.flac"
OUTPUT="$BASE_DIR/tbc/pal/yc/SVHS_PAL_EBU_Bars_MISRC_V2.5_40msps_12_bit_16_frames"
mkdir -p "$(dirname "$OUTPUT")"
vhs-decode -f 40 --pal --tape_format SVHS --tape_speed SP --threads 4 --recheck_phase --ire0_adjust "$INPUT" "$OUTPUT"

# Add more decode commands here as needed
