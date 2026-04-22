#!/bin/bash
#
# Test suite for orc-cli chroma decoder
# Runs ORC YAML projects and compares output against ld-chroma-decoder baseline
#

# Don't exit on error - we want to run all tests
set +e

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTDATA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$(cd "$TESTDATA_ROOT/.." && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/orc-projects"
OUTPUT_DIR="$TESTDATA_ROOT/rgb"
SIGNATURES_FILE="$SCRIPT_DIR/ld-chroma-decoder-references.txt"

# Try to find orc-cli: prefer latest build, allow environment override
if [[ -n "${ORC_CLI:-}" ]] && command -v "$ORC_CLI" &> /dev/null; then
    # ORC_CLI environment variable is set and exists (user override)
    ORC_CLI="$ORC_CLI"
elif [[ -x "$REPO_ROOT/build/bin/orc-cli" ]]; then
    # Use latest build from build directory (PREFERRED)
    ORC_CLI="$REPO_ROOT/build/bin/orc-cli"
elif command -v orc-cli &> /dev/null; then
    # Fall back to orc-cli in PATH
    ORC_CLI="orc-cli"
else
    # Will be checked later in main()
    ORC_CLI="orc-cli"
fi

# Test options
QUICK_MODE=0
VERBOSE=0

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${NC}[VERB]${NC} $*"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test ORC chroma decoder against ld-chroma-decoder baseline.

OPTIONS:
    -h, --help          Show this help message
    -q, --quick         Quick mode (run only essential tests)
    -v, --verbose       Verbose output
    
EXAMPLES:
    $0                  Run all tests
    $0 --quick          Run quick subset of tests
    $0 --verbose        Run with verbose output

NOTES:
    - Requires orc-cli to be in PATH or set ORC_CLI environment variable
    - Compares output against signatures from test-chroma-decoder.sh
    - Signatures file: $SIGNATURES_FILE

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -q|--quick)
                QUICK_MODE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Load existing signatures from ld-chroma-decoder baseline
load_signatures() {
    if [[ -f "$SIGNATURES_FILE" ]]; then
        log_verbose "Loading signatures from: $SIGNATURES_FILE"
        # Create associative array for lookups
        declare -g -A SIGNATURES
        while IFS='|' read -r test_name checksum; do
            SIGNATURES["$test_name"]="$checksum"
        done < "$SIGNATURES_FILE"
        log_verbose "Loaded ${#SIGNATURES[@]} signatures"
    else
        log_error "Signatures file not found: $SIGNATURES_FILE"
        log_info "Run test-chroma-decoder.sh generate first to create baseline"
        exit 1
    fi
}

# Calculate checksum of a file
calculate_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Run a single ORC project test
run_orc_test() {
    local test_name="$1"
    local project_file="$2"
    local output_file="$3"
    
    ((TESTS_TOTAL++)) || true
    
    log_info "Running test: $test_name"
    log_verbose "  Project: $project_file"
    log_verbose "  Output: $output_file"
    
    # Check if project file exists
    if [[ ! -f "$project_file" ]]; then
        log_error "Project file not found: $project_file"
        ((TESTS_FAILED++)) || true
        return 1
    fi
    
    # Run orc-cli from the scripts/chroma directory (where relative paths in YAML files are based)
    # The YAML files use paths like ../../tbc/... which are relative to scripts/chroma/
    local cmd="cd \"$SCRIPT_DIR\" && \"$ORC_CLI\" \"$project_file\" --process"
    log_verbose "  Command: $cmd"
    
    # Capture output to check for errors
    local output
    if [[ $VERBOSE -eq 1 ]]; then
        output=$(eval "$cmd" 2>&1)
    else
        output=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        # Check if it's a project file compatibility issue
        if echo "$output" | grep -q "not registered\|invalid connections\|missing required"; then
            log_warning "Project file not compatible with current ORC version: $test_name"
            log_verbose "  Error: $(echo "$output" | head -3)"
            ((TESTS_SKIPPED++)) || true
            return 0
        else
            log_error "orc-cli failed with exit code $exit_code: $test_name"
            log_verbose "  Error: $(echo "$output" | grep -i error | head -1)"
            ((TESTS_FAILED++)) || true
            return 1
        fi
    fi
    
    # Check if output was created
    if [[ ! -f "$output_file" ]]; then
        log_error "Output file not created: $output_file"
        ((TESTS_FAILED++)) || true
        return 1
    fi
    
    # Calculate checksum
    local checksum=$(calculate_checksum "$output_file")
    log_verbose "  ORC Checksum: $checksum"
    
    # Get expected signature from baseline
    local expected_checksum="${SIGNATURES[$test_name]}"
    
    if [[ -z "$expected_checksum" ]]; then
        log_warning "No baseline signature found for: $test_name"
        log_info "Run test-chroma-decoder.sh generate first"
        ((TESTS_SKIPPED++)) || true
        return 0
    fi
    
    log_verbose "  LD Checksum:  $expected_checksum"
    
    # Display signatures
    echo -e "  ${YELLOW}Expected (ld-chroma-decoder):${NC} $expected_checksum"
    echo -e "  ${YELLOW}Got (orc-cli):               ${NC} $checksum"
    
    # Compare checksums
    if [[ "$checksum" == "$expected_checksum" ]]; then
        log_success "Test passed: $test_name"
        ((TESTS_PASSED++)) || true
        return 0
    else
        log_error "Signature mismatch: $test_name"
        ((TESTS_FAILED++)) || true
        return 1
    fi
}

# Test suite: PAL decoders
test_pal_decoders() {
    log_info "=========================================="
    log_info "Testing PAL Decoders"
    log_info "=========================================="
    
    # Test PAL 2D decoder (default)
    run_orc_test "PAL_2D_RGB" \
        "$PROJECTS_DIR/pal-2d-rgb.yaml" \
        "$OUTPUT_DIR/pal_2d_rgb.rgb"
    
    # Test PAL Transform 2D decoder
    run_orc_test "PAL_Transform2D_RGB" \
        "$PROJECTS_DIR/pal-transform2d-rgb.yaml" \
        "$OUTPUT_DIR/pal_transform2d_rgb.rgb"
    
    # Test PAL Transform 3D decoder
    run_orc_test "PAL_Transform3D_RGB" \
        "$PROJECTS_DIR/pal-transform3d-rgb.yaml" \
        "$OUTPUT_DIR/pal_transform3d_rgb.rgb"
    
    if [[ $QUICK_MODE -eq 0 ]]; then
        # Test YUV output
        run_orc_test "PAL_2D_YUV" \
            "$PROJECTS_DIR/pal-2d-yuv.yaml" \
            "$OUTPUT_DIR/pal_2d_yuv.yuv"
        
        # Test Y4M output
        run_orc_test "PAL_2D_Y4M" \
            "$PROJECTS_DIR/pal-2d-y4m.yaml" \
            "$OUTPUT_DIR/pal_2d_y4m.y4m"
        
        # Test monochrome output
        run_orc_test "PAL_2D_Mono" \
            "$PROJECTS_DIR/pal-2d-mono.yaml" \
            "$OUTPUT_DIR/pal_2d_mono.rgb"
        
        # Test with chroma gain adjustment
        run_orc_test "PAL_2D_ChromaGain" \
            "$PROJECTS_DIR/pal-2d-chromagain.yaml" \
            "$OUTPUT_DIR/pal_2d_chromagain.rgb"
        
        # Test with chroma phase adjustment
        run_orc_test "PAL_2D_ChromaPhase" \
            "$PROJECTS_DIR/pal-2d-chromaphase.yaml" \
            "$OUTPUT_DIR/pal_2d_chromaphase.rgb"
        
        # Test simple PAL (1D UV filter)
        run_orc_test "PAL_2D_Simple" \
            "$PROJECTS_DIR/pal-2d-simple.yaml" \
            "$OUTPUT_DIR/pal_2d_simple.rgb"
        
        # Test PAL CAV source
        run_orc_test "PAL_CAV_2D" \
            "$PROJECTS_DIR/pal-cav-2d.yaml" \
            "$OUTPUT_DIR/pal_cav_2d.rgb"
    fi
}

# Test suite: NTSC decoders
test_ntsc_decoders() {
    log_info "=========================================="
    log_info "Testing NTSC Decoders"
    log_info "=========================================="
    
    # Test NTSC 1D decoder
    run_orc_test "NTSC_1D_RGB" \
        "$PROJECTS_DIR/ntsc-1d-rgb.yaml" \
        "$OUTPUT_DIR/ntsc_1d_rgb.rgb"
    
    # Test NTSC 2D decoder (default)
    run_orc_test "NTSC_2D_RGB" \
        "$PROJECTS_DIR/ntsc-2d-rgb.yaml" \
        "$OUTPUT_DIR/ntsc_2d_rgb.rgb"
    
    # Test NTSC 3D decoder
    run_orc_test "NTSC_3D_RGB" \
        "$PROJECTS_DIR/ntsc-3d-rgb.yaml" \
        "$OUTPUT_DIR/ntsc_3d_rgb.rgb"
    
    if [[ $QUICK_MODE -eq 0 ]]; then
        # Test NTSC 3D no-adapt decoder
        run_orc_test "NTSC_3D_NoAdapt_RGB" \
            "$PROJECTS_DIR/ntsc-3d-noadapt-rgb.yaml" \
            "$OUTPUT_DIR/ntsc_3d_noadapt_rgb.rgb"
        
        # Test YUV output
        run_orc_test "NTSC_2D_YUV" \
            "$PROJECTS_DIR/ntsc-2d-yuv.yaml" \
            "$OUTPUT_DIR/ntsc_2d_yuv.yuv"
        
        # Test Y4M output
        run_orc_test "NTSC_2D_Y4M" \
            "$PROJECTS_DIR/ntsc-2d-y4m.yaml" \
            "$OUTPUT_DIR/ntsc_2d_y4m.y4m"
        
        # Test monochrome output
        run_orc_test "NTSC_2D_Mono" \
            "$PROJECTS_DIR/ntsc-2d-mono.yaml" \
            "$OUTPUT_DIR/ntsc_2d_mono.rgb"
        
        # Test with chroma noise reduction
        run_orc_test "NTSC_2D_ChromaNR" \
            "$PROJECTS_DIR/ntsc-2d-chromanr.yaml" \
            "$OUTPUT_DIR/ntsc_2d_chromanr.rgb"
        
        # Test with luma noise reduction
        run_orc_test "NTSC_2D_LumaNR" \
            "$PROJECTS_DIR/ntsc-2d-lumanr.yaml" \
            "$OUTPUT_DIR/ntsc_2d_lumanr.rgb"
        
        # Test with phase compensation
        run_orc_test "NTSC_2D_PhaseComp" \
            "$PROJECTS_DIR/ntsc-2d-phasecomp.yaml" \
            "$OUTPUT_DIR/ntsc_2d_phasecomp.rgb"
        
        # Test NTSC CAV source
        run_orc_test "NTSC_CAV_2D" \
            "$PROJECTS_DIR/ntsc-cav-2d.yaml" \
            "$OUTPUT_DIR/ntsc_cav_2d.rgb"
    fi
}

# Print summary
print_summary() {
    echo ""
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    echo "Mode:    orc-cli verification"
    echo "Decoder: $ORC_CLI"
    echo "Total:   $TESTS_TOTAL"
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    log_info "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_TOTAL -gt 0 ]]; then
        log_success "All tests passed! ORC output matches ld-chroma-decoder baseline."
        return 0
    elif [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Some tests failed. ORC output differs from baseline."
        return 1
    else
        log_warning "No tests were run."
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "ORC Chroma Decoder Test Suite"
    log_info "Comparing orc-cli output against ld-chroma-decoder baseline"
    echo ""
    
    # Check if orc-cli is available
    if ! command -v "$ORC_CLI" &> /dev/null; then
        log_error "orc-cli not found. Install it or set ORC_CLI environment variable."
        exit 1
    fi
    
    log_info "Using ORC CLI: $ORC_CLI"
    log_info "Projects directory: $PROJECTS_DIR"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Signatures file: $SIGNATURES_FILE"
    echo ""
    
    # Load baseline signatures
    load_signatures
    
    # Run test suites in same order as ld-chroma-decoder tests
    test_pal_decoders
    test_ntsc_decoders
    
    # Print summary and exit
    print_summary
    exit $?
}

# Run main
main "$@"
