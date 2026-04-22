#!/bin/bash
# Decode all test .ldf files from ld-decode and ld-decode-stacking directories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$BASE_DIR/tbc"

echo "=========================================="
echo "Decoding All Test .ldf Files"
echo "=========================================="
echo ""
echo "Base directory: $BASE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{ldf,ldf-stacking}/{ntsc,pal}/{cav,clv}

# Function to decode a file
decode_file() {
    local input_file="$1"
    local rel_path="$2"  # Path relative to base (e.g., ld-decode/ntsc/cav)
    local output_base="$OUTPUT_DIR/$rel_path"
    
    # Determine PAL or NTSC from path
    local decoder_flag=""
    if [[ "$rel_path" == *"/ntsc/"* ]]; then
        decoder_flag="--NTSC"
    elif [[ "$rel_path" == *"/pal/"* ]]; then
        decoder_flag="--PAL"
    else
        echo "  ERROR: Cannot determine PAL/NTSC for $input_file"
        return 1
    fi
    
    # Get filename without extension
    local filename=$(basename "$input_file" .ldf)
    local output_file="$output_base/$filename"
    
    # Create output directory if needed
    mkdir -p "$output_base"
    
    echo "Decoding: $rel_path/$filename.ldf ($decoder_flag)"
    
    # Decode the file - capture stderr to show errors
    local decode_output
    decode_output=$(ld-decode $decoder_flag "$input_file" "$output_file" 2>&1)
    local decode_status=$?
    
    if [ $decode_status -eq 0 ]; then
        echo "  ✓ Success: $output_file.tbc"
        # Remove log files, keep .tbc, .tbc.json, .efm, and .pcm
        rm -f "$output_file.log"
        return 0
    else
        echo "  ✗ Failed to decode $input_file"
        # Show the error (first few lines)
        echo "$decode_output" | grep -i "error\|traceback\|modulenotfound" | head -3
        return 1
    fi
}

total_files=0
success_count=0
fail_count=0

# Process ldf directory
echo "=== Processing ldf directory ==="
echo ""
for disc_type in ntsc pal; do
    for disc_format in cav clv; do
        dir="$BASE_DIR/ldf/$disc_type/$disc_format"
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' ldf_file; do
                ((total_files++))
                rel_path="ldf/$disc_type/$disc_format"
                if decode_file "$ldf_file" "$rel_path"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
                echo ""
            done < <(find "$dir" -maxdepth 1 -name "*.ldf" -print0 2>/dev/null)
        fi
    done
done

# Process ldf-stacking directory
echo "=== Processing ldf-stacking directory ==="
echo ""
for disc_type in ntsc pal; do
    for disc_format in cav clv; do
        dir="$BASE_DIR/ldf-stacking/$disc_type/$disc_format"
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' ldf_file; do
                ((total_files++))
                rel_path="ldf-stacking/$disc_type/$disc_format"
                if decode_file "$ldf_file" "$rel_path"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
                echo ""
            done < <(find "$dir" -maxdepth 1 -name "*.ldf" -print0 2>/dev/null)
        fi
    done
done

echo "=========================================="
echo "Decoding Complete"
echo "=========================================="
echo "Total files: $total_files"
echo "Successful: $success_count"
echo "Failed: $fail_count"
echo ""
echo "Output location: $OUTPUT_DIR"
echo ""

if [ $fail_count -eq 0 ]; then
    echo "✓ All files decoded successfully!"
    exit 0
else
    echo "✗ Some files failed to decode"
    exit 1
fi
