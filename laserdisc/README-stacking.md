# laserdisc (stacking)

LaserDisc RF capture test data for the video-decode toolchain — multi-pass
**stacking** source sets used to verify frame alignment and stacking algorithms.

## Overview

This directory contains ld-decode test data. The test data is in LDF/LDS
format, the native input format for ld-decode, so the test procedure runs
end-to-end: ld-decode turns the RF captures into TBC video (and associated
metadata), which is then colour-decoded, dropout-corrected and exported by
**tbc-tools**.

Note: Any copyright material is included under fair-use, research. All material
is short clips of a few seconds.

## Tools

| Tool | Role |
|---|---|
| [ld-decode](https://github.com/happycube/ld-decode) | Decode LaserDisc RF (.ldf/.lds) → TBC |
| [tbc-tools](https://github.com/happycube/ld-decode) | TBC post-processing: `ld-chroma-decoder`, `ld-dropout-correct`, `ld-analyse`, `tbc-video-export` |
| [git-lfs](https://git-lfs.com) | Large-file storage for `.ldf` / `.lds` |

### tbc-tools (post-decode TBC processing)

tbc-tools operates on the TBC output produced by ld-decode:

- **ld-chroma-decoder** — colour-decodes the TBC to RGB48 / YUV444P16 / GRAY16
  (NTSC1D/2D/3D, PAL2D/transform2D/3D decoders).
- **ld-dropout-correct** — multi-source dropout correction; the stacking sets
  in `stacking/` are the inputs for its multi-pass correction.
- **ld-analyse** — GUI viewer / analyser for TBCs (chroma preview, VBI,
  dropout overlay, export dialog).
- **tbc-video-export** — orchestrates dropout-correct + chroma-decode + ffmpeg
  encode into final containers (FFV1/ProRes/AV1 in MKV/MOV/MP4), with proxy
  generation and aspect-ratio/MKV-header normalisation.

## Repository Structure

LaserDisc data is subdivided by disc system (ntsc/pal), then by access mode
(cav/clv):

### `ntsc/` and `pal/`
Contains standard LaserDisc test files organized by disc format:
```
laserdisc/
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

### `stacking/`
Contains LaserDisc files specifically for testing frame stacking functionality:
```
stacking/
├── ntsc/
│   └── cav/    # Multiple captures of Dragons Lair for testing stacking
└── pal/
    ├── cav/    # Multiple captures of British Garden Birds
    └── clv/    # Additional PAL CLV test files
```

These files represent multiple captures of the same content from different discs or at different positions, useful for testing frame alignment and stacking algorithms.

### Other subdirectories
- `issues/<n>/` — clips attached to ld-decode bug reports
- `cx/` — CX-ADC / EFM audio test data
- `pal-misc/` — miscellaneous PAL test cards
- `scripts/chroma/` — ld-chroma-decoder reference project YAMLs

## Usage

### Prerequisites
- [ld-decode](https://github.com/happycube/ld-decode) installed and available in your PATH
- Sufficient disk space for TBC output files (TBC files are significantly larger than LDF files)

### Decoding Test Files

Use the provided script to decode all test files:

```bash
./scripts/decode_all_test_files.sh
```

This will process the `.ldf` files, auto-detect PAL/NTSC from the directory
structure, and write TBC files into the `tbc/` output directory (mirroring the
source structure), producing `.tbc` and `.tbc.json` per input. Unnecessary
outputs (`.efm`, `.pcm`, `.log`) are cleaned up.

### Output Structure

Decoded files are saved to a `tbc/` output directory mirroring the source
structure under `laserdisc/{ntsc,pal}/{cav,clv}/` and `laserdisc/stacking/`.

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
