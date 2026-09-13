# decode-orc-testdata-ld
A repository of LaserDisc test data for the Decode Orc project - it is intended to be used as a decode-orc git sub-module.

## Overview
This repository contains ld-decode test data used for the verification of the decode-orc project with the ld-decode front-end.

The test data in this repository is in LDF format which is the native input format for ld-decode.  This is so the test procedure can run end-to-end, starting with ld-decode decoding the LDF files into TBC (and associated files) which are then sourced by decode-orc for processing.

Note: Any copyright material is included under fair-use, research.  All material are short clips of less than 5 seconds.

## Repository Structure

The repository is organized into two main directories:

### `ldf/`
Contains standard LaserDisc test files organized by video standard and disc format:
```
ldf/
├── ntsc/
│   ├── cav/    # NTSC CAV (Constant Angular Velocity) discs
│   └── clv/    # NTSC CLV (Constant Linear Velocity) discs
└── pal/
    ├── cav/    # PAL CAV discs
    └── clv/    # PAL CLV discs
```

Test files include a variety of LaserDisc content:
- **NTSC CAV**: Dragons Lair, Firefox, National Gallery of Art, Pioneer test discs
- **NTSC CLV**: Bambi, Cinderella (Japan imports with closed captions)
- **PAL CAV**: BBC Domesday Project discs, British Garden Birds, EcoDisc, Roger Rabbit
- **PAL CLV**: BBC Domesday Project National B discs, BBC Archives

### `ldf-stacking/`
Contains LaserDisc files specifically for testing frame stacking functionality:
```
ldf-stacking/
├── ntsc/
│   └── cav/    # Multiple captures of Dragons Lair for testing stacking
└── pal/
    ├── cav/    # Multiple captures of British Garden Birds
    └── clv/    # Additional PAL CLV test files
```

These files represent multiple captures of the same content from different discs or at different positions, useful for testing frame alignment and stacking algorithms.

## Usage

### Prerequisites
- [ld-decode](https://github.com/happycube/ld-decode) installed and available in your PATH
- Sufficient disk space for TBC output files (TBC files are significantly larger than LDF files)

### Decoding Test Files

Use the provided script to decode all test files:

```bash
./scripts/decode_all_test_files.sh
```

This script will:
1. Process all `.ldf` files in both `ldf/` and `ldf-stacking/` directories
2. Automatically detect PAL vs NTSC from the directory structure
3. Create TBC files in the `tbc/` output directory (mirroring the source structure)
4. Generate `.tbc` and `.tbc.json` files for each input
5. Clean up unnecessary output files (`.efm`, `.pcm`, `.log`)
6. Display progress and summary statistics

### Output Structure

Decoded files are saved to:
```
tbc/
├── ldf/
│   ├── ntsc/
│   │   ├── cav/
│   │   └── clv/
│   └── pal/
│       ├── cav/
│       └── clv/
└── ldf-stacking/
    ├── ntsc/
    │   └── cav/
    └── pal/
        ├── cav/
        └── clv/
```

Each `.ldf` file produces:
- `<filename>.tbc` - Time Base Corrected video data
- `<filename>.tbc.db` - Metadata including frame information, VBI data, etc.
- ...and more (such as audio, EFM, logs, etc.)

## Test File Naming Convention

LDF files follow a descriptive naming pattern:
```
<Title>_<DiscType>_<VideoStandard>_<Side>_<AdditionalInfo>_<Timestamp>_<Position>.ldf
```

Examples:
- `Dragons-Lair_DS1_Side1_20191230_CAV_NTSC_pos3103.ldf`
- `Domesday_DD86-DS10_NationalB_PP_20200830_CLV_PAL_00-60_pos64678.ldf`
