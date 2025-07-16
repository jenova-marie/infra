#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Test Runner
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Execute Bats tests with proper formatting and reporting
# Author: Infrastructure Management System v2.0
# Last Updated: May 26, 2024

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test directories
UNIT_TESTS="${SCRIPT_DIR}/unit"
INTEGRATION_TESTS="${SCRIPT_DIR}/integration"

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [PATTERN]

Infrastructure Management System v2.0 - Test Suite Runner

🔒 SAFETY GUARANTEE: All tests are now DRY-RUN ONLY
   No real AWS resources are ever created by any test

Test Types:
  📋 Unit Tests     - Mock-based logic testing (default)
  🔍 Dry-Run Tests  - Command validation with dry-run simulation

Options:
  -u, --unit           Run unit tests only (default)
  -d, --dry-run        Run dry-run simulation tests
  -a, --all            Run both unit and dry-run tests
  -v, --verbose        Show detailed test output
  -s, --skip-aws       Skip AWS CLI validation for CI/CD
  -h, --help           Show this help message

Pattern (optional):
  Filter tests by pattern (e.g., 'logger', 'args', 'backup')

Examples:
  # Run all safe tests (unit + dry-run)
  $0 --all

  # Run only unit tests (default)
  $0 --unit
  $0

  # Run only dry-run simulation tests
  $0 --dry-run

  # Run specific test pattern with verbose output
  $0 --all --verbose logger

  # CI/CD usage (skip AWS CLI validation)
  $0 --all --skip-aws

Safety Notes:
  🔒 ALL tests are completely safe - no real AWS resources created
  🔍 Dry-run tests validate command structure without execution
  📋 Unit tests use mocks and temporary test environments
  💰 ZERO AWS costs - no real infrastructure operations

EOF
}

# Print colored header
print_header() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}Infrastructure Management System v2.0 - Test Suite${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Print section header
print_section() {
    local title="$1"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}$title${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────────${NC}"
}

# Check AWS CLI availability for integration tests
check_aws_cli() {
    local skip_aws="${1:-false}"
    
    if [[ "$skip_aws" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Skipping AWS CLI validation (--skip-aws specified)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🔍 Checking AWS CLI configuration...${NC}"
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found. Install it or use --skip-aws${NC}"
        return 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' or use --skip-aws${NC}"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    local region=$(aws configure get region 2>/dev/null || echo "us-east-2")
    
    echo -e "${GREEN}✅ AWS CLI configured - Account: $account_id, Region: $region${NC}"
    return 0
}

# Run tests in a directory
run_test_directory() {
    local test_dir="$1"
    local test_type="$2"
    local pattern="${3:-}"
    local verbose="${4:-false}"
    local specific_file="${5:-}"
    
    if [[ ! -d "$test_dir" ]]; then
        echo -e "${YELLOW}⚠️  No $test_type tests found in $test_dir${NC}"
        return 0
    fi
    
    print_section "$test_type Tests"
    
    # Build bats command
    local bats_cmd="bats"
    if [[ "$verbose" == "true" ]]; then
        bats_cmd="$bats_cmd --verbose-run"
    fi
    
    # Find test files
    local test_files=()
    if [[ -n "$specific_file" ]]; then
        # Run specific file if provided
        if [[ -f "$test_dir/$specific_file" ]]; then
            test_files+=("$test_dir/$specific_file")
        fi
    elif [[ -n "$pattern" ]]; then
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$test_dir" -name "*${pattern}*.bats" -print0)
    else
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$test_dir" -name "*.bats" -print0)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No $test_type test files found matching criteria${NC}"
        return 0
    fi
    
    # Show what we're running
    echo -e "${PURPLE}📋 Test files:${NC}"
    for file in "${test_files[@]}"; do
        echo "   - $(basename "$file")"
    done
    echo ""
    
    # Run tests
    local exit_code=0
    for test_file in "${test_files[@]}"; do
        echo -e "${BLUE}Running: $(basename "$test_file")${NC}"
        if ! $bats_cmd "$test_file"; then
            exit_code=1
        fi
        echo ""
    done
    
    return $exit_code
}

# Main execution
main() {
    # Initialize variables
    verbose=false
    pattern=""
    run_unit=false
    run_dry_run=false
    default_mode=true
    skip_aws=false
    overall_exit_code=0
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    print_header
    
    # Check if bats is available
    if ! command -v bats &> /dev/null; then
        echo -e "${RED}❌ Bats is not installed or not in PATH${NC}"
        echo "Please install Bats: https://github.com/bats-core/bats-core"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Bats version: $(bats --version)${NC}"
    echo -e "${GREEN}✅ Project root: $PROJECT_ROOT${NC}"
    echo ""
    
    # Run unit tests
    if [[ "$run_unit" == "true" ]]; then
        echo -e "${GREEN}🔒 Running unit tests (completely safe - no real resources)${NC}"
        if ! run_test_directory "$UNIT_TESTS" "Unit" "$pattern" "$verbose"; then
            overall_exit_code=1
        fi
    fi
    
    # Run dry-run tests
    if [[ "$run_dry_run" == "true" ]]; then
        echo -e "${GREEN}🔒 Running dry-run tests (safe - simulation only, no real resources)${NC}"
        if ! check_aws_cli "$skip_aws"; then
            echo -e "${RED}❌ AWS CLI required for dry-run tests${NC}"
            overall_exit_code=1
        else
            if ! run_test_directory "$INTEGRATION_TESTS" "Dry-Run Integration" "$pattern" "$verbose" "dry_run.bats"; then
                overall_exit_code=1
            fi
        fi
    fi
    
    # Print summary
    print_section "Test Summary"
    if [[ $overall_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
    fi
    
    exit $overall_exit_code
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -u|--unit)
                run_unit=true
                default_mode=false
                shift
                ;;
            -d|--dry-run)
                run_dry_run=true
                default_mode=false
                shift
                ;;
            -a|--all)
                run_unit=true
                run_dry_run=true
                default_mode=false
                shift
                ;;
            -s|--skip-aws)
                skip_aws=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                pattern="$1"
                shift
                ;;
        esac
    done
    
    # Default to unit tests if no specific mode selected
    if [[ "$default_mode" == "true" ]]; then
        run_unit=true
    fi
}

# Execute main function
main "$@" 