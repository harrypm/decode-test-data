#!/bin/bash
#
# Comprehensive test suite for ld-chroma-decoder
# Tests both PAL and NTSC decoding with various options to ensure
# output remains consistent during refactoring
#

set -e

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTDATA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TBC_ROOT="$TESTDATA_ROOT/tbc/ldf"
DECODER="${DECODER:-ld-chroma-decoder}"
OUTPUT_DIR="$TESTDATA_ROOT/rgb"
TEMP_DIR="/tmp/ld-chroma-decoder-test-$$"
SIGNATURES_FILE="$SCRIPT_DIR/ld-chroma-decoder-references.txt"
SIGNATURES_FILE_NEW="$TEMP_DIR/ld-chroma-decoder-references.txt.new"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Flags
VERBOSE=${VERBOSE:-0}
MODE=${MODE:-verify}  # 'generate' or 'verify'
QUICK_MODE=${QUICK_MODE:-0}

# Usage information
usage() {
    cat << EOF
Usage: $0 [MODE] [OPTIONS]

Run comprehensive tests for ld-chroma-decoder

MODES:
    generate                Generate baseline signatures (run first)
    verify                  Verify against baseline signatures (default)

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -q, --quick             Run only a quick subset of tests
    --decoder CMD           Decoder command (default: ld-chroma-decoder)
    --test PATTERN          Run only tests matching PATTERN

ENVIRONMENT VARIABLES:
    DECODER                 Path to decoder executable
    VERBOSE                 Set to 1 for verbose output
    MODE                    Set to 'generate' or 'verify'
    QUICK_MODE              Set to 1 for quick test mode

EXAMPLES:
    # Generate initial baseline signatures
    $0 generate

    # Verify against baseline (default mode)
    $0
    $0 verify

    # Generate signatures with verbose output
    $0 generate -v

    # Verify only PAL tests
    $0 verify --test "PAL"

    # Quick smoke test
    $0 verify --quick

WORKFLOW:
    1. Build the decoder
    2. Run '$0 generate' to create baseline signatures
    3. Make code changes
    4. Run '$0 verify' to check for regressions
    5. If output intentionally changed, run '$0 generate' again

EOF
    exit 0
}

# Parse command line arguments
TEST_PATTERN=""

# Check if first argument is a mode
if [[ $# -gt 0 ]] && [[ "$1" == "generate" || "$1" == "verify" ]]; then
    MODE="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -q|--quick)
            QUICK_MODE=1
            shift
            ;;
        --decoder)
            DECODER="$2"
            shift 2
            ;;
        --test)
            TEST_PATTERN="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${NC}[DEBUG]${NC} $*"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v "$DECODER" &> /dev/null; then
        log_error "Decoder not found: $DECODER"
        log_info "Install ld-chroma-decoder or set DECODER environment variable"
        exit 1
    fi
    
    if [[ ! -d "$TBC_ROOT" ]]; then
        log_error "Test data not found: $TBC_ROOT"
        exit 1
    fi
    
    # Check for required tools
    for tool in sha256sum mktemp; do
        if ! command -v $tool &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log_success "Prerequisites OK (using: $DECODER)"
}

# Initialize test environment
init_test_env() {
    log_info "Initializing test environment..."
    
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Setup cleanup trap
    trap "rm -rf '$TEMP_DIR'" EXIT
    
    # Clean old outputs
    rm -f "$OUTPUT_DIR"/*.rgb
    rm -f "$OUTPUT_DIR"/*.yuv
    rm -f "$OUTPUT_DIR"/*.y4m
    # Check for signatures file in verify mode
    if [[ "$MODE" == "verify" ]] && [[ ! -f "$SIGNATURES_FILE" ]]; then
        log_warning "No signatures file found: $SIGNATURES_FILE"
        log_info "Run in 'generate' mode first to create baseline signatures"
        log_info "  Example: $0 generate"
        exit 1
    fi
    
    log_success "Test environment initialized"
}

# Load existing signatures
load_signatures() {
    if [[ -f "$SIGNATURES_FILE" ]]; then
        log_verbose "Loading signatures from: $SIGNATURES_FILE"
        # Create associative array for lookups
        declare -g -A SIGNATURES
        while IFS='|' read -r test_name checksum; do
            SIGNATURES["$test_name"]="$checksum"
        done < "$SIGNATURES_FILE"
        log_verbose "Loaded ${#SIGNATURES[@]} signatures"
    fi
}

# Save signature to file
save_signature() {
    local test_name="$1"
    local checksum="$2"
    
    # Append to signatures file
    echo "${test_name}|${checksum}" >> "$SIGNATURES_FILE_NEW"
}

# Calculate checksum of a file
calculate_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Run a single test case
run_test() {
    local test_name="$1"
    local input_tbc="$2"
    local decoder_args="$3"
    local output_file="$4"
    
    # Check if test matches pattern
    if [[ -n "$TEST_PATTERN" ]] && [[ ! "$test_name" =~ $TEST_PATTERN ]]; then
        log_verbose "Skipping test - pattern mismatch: $test_name"
        ((TESTS_SKIPPED++)) || true
        return 0
    fi
    
    ((TESTS_TOTAL++)) || true
    
    log_info "Running test: $test_name"
    log_verbose "  Input: $input_tbc"
    log_verbose "  Args: $decoder_args"
    log_verbose "  Output: $output_file"
    
    # Check if input exists
    if [[ ! -f "$input_tbc" ]]; then
        log_error "Input file not found: $input_tbc"
        ((TESTS_FAILED++)) || true
        return 1
    fi
    
    # Run decoder
    local cmd="$DECODER $decoder_args \"$input_tbc\" \"$output_file\""
    log_verbose "  Command: $cmd"
    
    if [[ $VERBOSE -eq 1 ]]; then
        eval "$cmd"
    else
        eval "$cmd" > "$TEMP_DIR/${test_name}.log" 2>&1
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Test failed with exit code $exit_code: $test_name"
        if [[ $VERBOSE -eq 0 ]]; then
            log_info "See log: $TEMP_DIR/${test_name}.log"
        fi
        ((TESTS_FAILED++)) || true
        return 1
    fi
    
    # Check if output was created
    if [[ ! -f "$output_file" ]]; then
        log_error "Output file not created: $output_file"
        ((TESTS_FAILED++)) || true
        return 1
    fi
    
    # Calculate checksum
    local checksum=$(calculate_checksum "$output_file")
    
    if [[ "$MODE" == "generate" ]]; then
        # Generate mode: save signature
        save_signature "$test_name" "$checksum"
        echo -e "  ${YELLOW}Generated:${NC} $checksum"
        log_success "Generated signature: $test_name"
        ((TESTS_PASSED++)) || true
        return 0
    else
        # Verify mode: compare with saved signature
        local expected_checksum="${SIGNATURES[$test_name]}"
        
        if [[ -z "$expected_checksum" ]]; then
            log_warning "No baseline signature found for: $test_name"
            log_info "Run in 'generate' mode to create baseline"
            ((TESTS_SKIPPED++)) || true
            return 0
        fi
        
        echo -e "  ${YELLOW}Expected:${NC}  $expected_checksum"
        echo -e "  ${YELLOW}Generated:${NC} $checksum"
        
        if [[ "$checksum" == "$expected_checksum" ]]; then
            log_success "Test passed: $test_name"
            ((TESTS_PASSED++)) || true
            return 0
        else
            log_error "Signature mismatch: $test_name"
            ((TESTS_FAILED++)) || true
            return 1
        fi
    fi
}

# Test suite: PAL decoders
test_pal_decoders() {
    log_info "=========================================="
    log_info "Testing PAL Decoders"
    log_info "=========================================="
    
    # Use a PAL CLV sample for testing
    local pal_clv="$TBC_ROOT/pal/clv/Domesday_DD86-DS1_NationalB_PP_20191014_CLV_PAL_00-60_pos32794.tbc"
    
    # Test PAL 2D decoder (default)
    run_test "PAL_2D_RGB" \
        "$pal_clv" \
        "-s 1 -l 10 -p rgb" \
        "$OUTPUT_DIR/pal_2d_rgb.rgb"
    
    # Test PAL Transform 2D decoder
    run_test "PAL_Transform2D_RGB" \
        "$pal_clv" \
        "-s 1 -l 10 -f transform2d -p rgb" \
        "$OUTPUT_DIR/pal_transform2d_rgb.rgb"
    
    # Test PAL Transform 3D decoder
    run_test "PAL_Transform3D_RGB" \
        "$pal_clv" \
        "-s 1 -l 10 -f transform3d -p rgb" \
        "$OUTPUT_DIR/pal_transform3d_rgb.rgb"
    
    if [[ $QUICK_MODE -eq 0 ]]; then
        # Test YUV output
        run_test "PAL_2D_YUV" \
            "$pal_clv" \
            "-s 1 -l 10 -p yuv" \
            "$OUTPUT_DIR/pal_2d_yuv.yuv"
        
        # Test Y4M output
        run_test "PAL_2D_Y4M" \
            "$pal_clv" \
            "-s 1 -l 10 -p y4m" \
            "$OUTPUT_DIR/pal_2d_y4m.y4m"
        
        # Test monochrome output
        run_test "PAL_2D_Mono" \
            "$pal_clv" \
            "-s 1 -l 10 -f mono -p rgb" \
            "$OUTPUT_DIR/pal_2d_mono.rgb"
        
        # Test with chroma gain adjustment
        run_test "PAL_2D_ChromaGain" \
            "$pal_clv" \
            "-s 1 -l 10 --chroma-gain 1.5 -p rgb" \
            "$OUTPUT_DIR/pal_2d_chromagain.rgb"
        
        # Test with chroma phase adjustment
        run_test "PAL_2D_ChromaPhase" \
            "$pal_clv" \
            "-s 1 -l 10 --chroma-phase 90 -p rgb" \
            "$OUTPUT_DIR/pal_2d_chromaphase.rgb"
        
        # Test simple PAL (1D UV filter)
        run_test "PAL_2D_Simple" \
            "$pal_clv" \
            "-s 1 -l 10 --simple-pal -p rgb" \
            "$OUTPUT_DIR/pal_2d_simple.rgb"
        
        # Test PAL CAV source
        local pal_cav="$TBC_ROOT/pal/cav/GGV1011_CAV_PAL_side2_DD1_2019-06-12_20-35-19_pos11931.tbc"
        if [[ -f "$pal_cav" ]]; then
            run_test "PAL_CAV_2D" \
                "$pal_cav" \
                "-s 1 -l 5 -p rgb" \
                "$OUTPUT_DIR/pal_cav_2d.rgb"
        fi
    fi
}

# Test suite: NTSC decoders
test_ntsc_decoders() {
    log_info "=========================================="
    log_info "Testing NTSC Decoders"
    log_info "=========================================="
    
    # Use Bambi NTSC CLV sample
    local ntsc_clv="$TBC_ROOT/ntsc/clv/Bambi_CLV_NTSC_side1_JapanImport_LDG_2020-01-22_20-25-19_pos8483.tbc"
    
    # Test NTSC 1D decoder
    run_test "NTSC_1D_RGB" \
        "$ntsc_clv" \
        "-s 1 -l 10 -f ntsc1d -p rgb" \
        "$OUTPUT_DIR/ntsc_1d_rgb.rgb"
    
    # Test NTSC 2D decoder (default)
    run_test "NTSC_2D_RGB" \
        "$ntsc_clv" \
        "-s 1 -l 10 -f ntsc2d -p rgb" \
        "$OUTPUT_DIR/ntsc_2d_rgb.rgb"
    
    # Test NTSC 3D decoder
    run_test "NTSC_3D_RGB" \
        "$ntsc_clv" \
        "-s 1 -l 10 -f ntsc3d -p rgb" \
        "$OUTPUT_DIR/ntsc_3d_rgb.rgb"
    
    if [[ $QUICK_MODE -eq 0 ]]; then
        # Test NTSC 3D no-adapt decoder
        run_test "NTSC_3D_NoAdapt_RGB" \
            "$ntsc_clv" \
            "-s 1 -l 10 -f ntsc3dnoadapt -p rgb" \
            "$OUTPUT_DIR/ntsc_3d_noadapt_rgb.rgb"
        
        # Test YUV output
        run_test "NTSC_2D_YUV" \
            "$ntsc_clv" \
            "-s 1 -l 10 -f ntsc2d -p yuv" \
            "$OUTPUT_DIR/ntsc_2d_yuv.yuv"
        
        # Test Y4M output
        run_test "NTSC_2D_Y4M" \
            "$ntsc_clv" \
            "-s 1 -l 10 -f ntsc2d -p y4m" \
            "$OUTPUT_DIR/ntsc_2d_y4m.y4m"
        
        # Test monochrome output
        run_test "NTSC_2D_Mono" \
            "$ntsc_clv" \
            "-s 1 -l 10 -f mono -p rgb" \
            "$OUTPUT_DIR/ntsc_2d_mono.rgb"
        
        # Test with chroma noise reduction
        run_test "NTSC_2D_ChromaNR" \
            "$ntsc_clv" \
            "-s 1 -l 10 --chroma-nr 3.0 -p rgb" \
            "$OUTPUT_DIR/ntsc_2d_chromanr.rgb"
        
        # Test with luma noise reduction
        run_test "NTSC_2D_LumaNR" \
            "$ntsc_clv" \
            "-s 1 -l 10 --luma-nr 2.0 -p rgb" \
            "$OUTPUT_DIR/ntsc_2d_lumanr.rgb"
        
        # Test with phase compensation
        run_test "NTSC_2D_PhaseComp" \
            "$ntsc_clv" \
            "-s 1 -l 10 --ntsc-phase-comp -p rgb" \
            "$OUTPUT_DIR/ntsc_2d_phasecomp.rgb"
        
        # Test NTSC CAV source
        local ntsc_cav="$TBC_ROOT/ntsc/cav/Pioneer_GGV1069_CAV_NTSC_side1_dup1_2019-09-12_21-11-38_pos3584.tbc"
        if [[ -f "$ntsc_cav" ]]; then
            run_test "NTSC_CAV_2D" \
                "$ntsc_cav" \
                "-s 1 -l 5 -f ntsc2d -p rgb" \
                "$OUTPUT_DIR/ntsc_cav_2d.rgb"
        fi
    fi
}



# Finalize signature generation
finalize_signatures() {
    if [[ "$MODE" == "generate" ]]; then
        if [[ -f "$SIGNATURES_FILE_NEW" ]]; then
            mv "$SIGNATURES_FILE_NEW" "$SIGNATURES_FILE"
            log_success "Signatures saved to: $SIGNATURES_FILE"
            log_info "Total signatures: $(wc -l < "$SIGNATURES_FILE")"
        fi
    fi
}

# Print summary
print_summary() {
    echo ""
    log_info "=========================================="
    log_info "Test Summary"
    log_info "=========================================="
    echo "Mode:    $MODE"
    echo "Decoder: $DECODER"
    echo "Total:   $TESTS_TOTAL"
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    log_info "=========================================="
    
    if [[ "$MODE" == "generate" ]]; then
        log_success "Baseline signatures generated!"
        log_info "Signatures file: $SIGNATURES_FILE"
        log_info "Next: Run '$0 verify' to verify against baseline"
        return 0
    else
        if [[ $TESTS_FAILED -gt 0 ]]; then
            log_error "Some tests failed!"
            log_info "Output may have changed. If intentional, regenerate signatures:"
            log_info "  $0 generate"
            return 1
        elif [[ $TESTS_SKIPPED -gt 0 ]]; then
            log_warning "Some tests were skipped (no baseline signatures)"
            log_info "Run in 'generate' mode to create baseline signatures"
            return 0
        else
            log_success "All tests passed!"
            return 0
        fi
    fi
}



# Main execution
main() {
    check_prerequisites
    init_test_env
    load_signatures
    
    # Run test suites
    test_pal_decoders
    test_ntsc_decoders
    
    # Finalize
    finalize_signatures
    print_summary
}

# Run main function
main
exit $?
