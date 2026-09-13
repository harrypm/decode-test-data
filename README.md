# decode-test-data

Reference RF capture samples and decoded TBC outputs for the video-decode toolchain.
Used for regression testing and A/B comparison across the decode → TBC → export pipeline.

Samples are short clips (typically < 10 s) included under fair-use / research.
Large `.ldf` / `.lds` LaserDisc files are stored via [Git LFS](https://git-lfs.com).

## Repository structure

```
decode-test-data/
├── laserdisc/        LaserDisc RF captures (.ldf / .lds), LFS-tracked
│   ├── ntsc/{cav,clv}/
│   ├── pal/{cav,clv}/
│   ├── stacking/{ntsc,pal}/...   multi-pass stacking source sets
│   ├── issues/<n>/               clips attached to ld-decode bug reports
│   ├── cx/                       CX-ADC / EFM audio test data
│   ├── pal-misc/                 miscellaneous PAL test cards
│   └── scripts/chroma/           ld-chroma-decoder reference project YAMLs
├── tape/            Tape (colour-under) RF captures (.flac)
│   ├── vhs/{pal,ntsc,secam,mesecam,palm}/
│   ├── svhs/{pal,ntsc,...}/
│   ├── betamax/{pal,ntsc,...}/
│   ├── quadruplex/{pal,ntsc,secam,...}/
│   └── scripts/decode_all_test_files.sh
├── composite/       Baseband composite video captures (placeholder)
└── s-video/         Baseband S-Video (Y/C) captures (placeholder)
```

`tape/` is subdivided **by tape format, then by TV system**.
`laserdisc/` is subdivided by disc system (ntsc/pal), then by access mode (cav/clv).

### What gets committed vs. generated

The committed, canonical sample in `tape/` is the **RF `.flac`** capture.
TBC files (`.tbc`, `.tbc.json`, `.tbc.db`) and decode `.log`s are **regenerated**
by decoding and are git-ignored (see `tape/.gitignore`) — do not commit them.

In `laserdisc/`, the `.ldf` / `.lds` RF files are the canonical samples and are
stored via Git LFS (see `.gitattributes`).

## Tools referenced

| Tool | Purpose | Repo |
|---|---|---|
| **vhs-decode** | Decode colour-under tape RF (VHS/S-VHS/Beta/Quadruplex) → TBC | https://github.com/oyvindln/vhs-decode |
| **tape-decode-rust** | Rust decode front-end (profiles per tape format/system) → TBC | (this toolchain) |
| **tbc-tools** | TBC post-processing: ld-chroma-decoder, ld-dropout-correct, ld-analyse, tbc-video-export | https://github.com/harrypm/ld-decode (tbc-tools) |
| **FLAC-Chop** | Sample-exact cutting of RF-capture FLAC/PCM files | https://github.com/harrypm/FLAC-Chop |
| **git-lfs** | Large-file storage for `.ldf` / `.lds` | https://git-lfs.com |

## Making a reference sample (RF → decode → TBC → export)

A reference sample lets you re-run the full pipeline on a small, stable clip and
compare the output frame-by-frame against a known-good baseline.

### 1. Capture / locate the RF source

A full-length RF capture (FLAC, from MISRC/DdD/cxadc). Note its real sample rate
from the in-file tags (`RF_SAMPLE_RATE`) — RF FLAC headers use the `/1000`
convention (a 40 MSPS capture reports 40000 Hz in the FLAC header).

### 2. Chop a short clip with FLAC-Chop

Keep clips short (a few seconds). Start at a frame boundary if possible, and
include a little pre-roll so the decoder can lock sync.

```bash
# Probe to confirm the real rate and total samples
flac-chop --probe source.flac

# Cut e.g. 5 seconds from 0 s
flac-chop source.flac out_clip.flac 0 5
```

`flac-chop --probe` reports `real_rate_hz` and `total_samples` correctly,
including the `/1000` RF convention and unfinalized/wrapped headers.

### 3. Decode the clip to TBC

Pick the decoder and profile matching the tape format and TV system.

**vhs-decode** (colour-under tapes):
```bash
vhs-decode --pal -l 50 --overwrite out_clip.flac out_clip
# -> out_clip.tbc, out_clip_chroma.tbc, out_clip.tbc.json
```

**tape-decode-rust** (profile-driven):
```bash
tape-decode list-profiles                       # e.g. MESECAM_VHS, PAL_QUADRUPLEX, NTSC_VHS
tape-decode decode --profile MESECAM_VHS \
  --input-format flac --frequency 17.898MHz --overwrite \
  --luma-out out_clip.tbc --chroma-out out_clip_chroma.tbc \
  --metadata-out out_clip.tbc.json out_clip.flac
```

For SECAM/MESECAM, the decode uses the 625-line PAL geometry; the SECAM
colourimetry is handled by the chroma decoder (`ld-chroma-decoder -f secam`)
in the next step. Quadruplex SECAM uses the `PAL_QUADRUPLEX` (625-line) profile.

### 4. (Optional) Dropout-correct and colour-decode the TBC

```bash
# Chroma-decode to RGB/YUV for inspection (ld-chroma-decoder from tbc-tools)
ld-chroma-decoder --full-frame -f secam -p yuv -s 1 -l 50 \
  --input-json out_clip.tbc.json out_clip_chroma.tbc out_clip.yuv
```

### 5. Export to a final container with tbc-video-export

```bash
tbc-video-export --start 1 --length 50 --profile ffv1 --10bit \
  --video-system pal out_clip.tbc out_clip.mkv
```

### 6. Commit only the RF clip

Place the `.flac` under `tape/<format>/<system>/` and commit **only** the FLAC.
The generated `.tbc` / `.tbc.json` / `.log` are ignored by `tape/.gitignore`.

```bash
git add tape/quadruplex/secam/secam_example_clip.flac
git commit -m "test: add SECAM quadruplex colorbar reference clip"
```

## License

See `laserdisc/LICENSE` and `tape/LICENSE`. Samples are provided for
non-infringing fair-use research to support the open-source video-decode toolchain.
