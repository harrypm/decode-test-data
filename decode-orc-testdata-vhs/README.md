# decode-orc-testdata-vhs
A repository of tape test data for the Decode Orc project - it is intended to be used as a decode-orc git sub-module.

## Overview
This repository contains vhs-decode test data used for the verification of the decode-orc project with the vhs-decode front-end.

The test data in this repository is in flac format which is the native input format for vhs-decode.  This is so the test procedure can run end-to-end, starting with vhs-decode decoding the flac files into TBC (and associated files) which are then sourced by decode-orc for processing.

Note: Any copyright material is included under fair-use, research.  All material are short clips of less than 5 seconds.

## Repository Structure

The repository is organized into two main directories:

### `flac/`
Contains standard tape test files organized by video standard and tape format:

## Usage

### Prerequisites
- [vhs-decode](https://github.com/oyvindln/vhs-decode) installed and available in your PATH
- Sufficient disk space for TBC output files (TBC files are significantly larger than flac files)

### Decoding Test Files

Use the provided script to decode all test files:

```bash
./scripts/decode_all_test_files.sh
```

This script will:
1. Process all `.flac` files in the `flac/` directory
2. Automatically detect PAL vs NTSC from the directory structure
3. Create TBC files in the `tbc/` output directory (mirroring the source structure)
4. Generate `.tbc` and `.tbc.db` files for each input
5. Clean up unnecessary output files (`.pcm`, `.log`)
6. Display progress and summary statistics

### Output Structure

Decoded files are saved to:
```
tbc/
```

Each `.ldf` file produces:
- `<filename>.tbc` - Time Base Corrected video data
- `<filename>.tbc.db` - Metadata including frame information, VBI data, etc.
- ...and more (such as audio, EFM, logs, etc.)

and... the YC outputs too?

## Test File Naming Convention

flac files follow a descriptive naming pattern (this needs fixing):
```
<Title>_<DiscType>_<VideoStandard>_<Side>_<AdditionalInfo>_<Timestamp>_<Position>.ldf
```

Examples:
- `Dragons-Lair_DS1_Side1_20191230_CAV_NTSC_pos3103.flac`
- `Domesday_DD86-DS10_NationalB_PP_20200830_CLV_PAL_00-60_pos64678.flac`
