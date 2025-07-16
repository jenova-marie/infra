#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Test Helpers
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Common test utilities and setup functions for Bats tests
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2025

# ─────────────────────────────────────────────────────────────────────────────
# Test Environment Constants
# ─────────────────────────────────────────────────────────────────────────────

# Test environment constants
readonly TEST_ENV="test"
DRY_RUN="${DRY_RUN:-true}"  # Default to dry-run for safety, override with DRY_RUN=false
export DRY_RUN

# Test environment setup
export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME}"
export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
export INFRA_ROOT="${PROJECT_ROOT}/src/infra"
export TEST_ROOT="${PROJECT_ROOT}/test"
export TEST_FIXTURES="${TEST_ROOT}/fixtures"
export TEST_TEMP_DIR="${BATS_TMPDIR}/infra-test-$$"

# Create temporary test directory
setup_test_env() {
    mkdir -p "${TEST_TEMP_DIR}"
    cd "${TEST_TEMP_DIR}"
    
    # Create mock environment structure that matches our project layout
    mkdir -p "src/live/${TEST_ENV}/log"
    mkdir -p "src/live/${TEST_ENV}/outputs"
    
    # Copy modules.yml fixture to test environments only
    if [[ -f "${TEST_FIXTURES}/modules.yml" ]]; then
        cp "${TEST_FIXTURES}/modules.yml" "src/live/${TEST_ENV}/"
    else
        # Create basic modules.yml if fixture doesn't exist
        echo "modules:" > "src/live/${TEST_ENV}/modules.yml"
    fi
    
    # Set up environment variables for testing
    export LIVE_ROOT="${TEST_TEMP_DIR}/src/live"
}

# Clean up test environment
teardown_test_env() {
    if [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# Source infra modules for testing
source_infra_modules() {
    # Set required environment variables before sourcing modules
    export LIVE_ROOT="${TEST_TEMP_DIR}/src/live"
    
    # Define color variables for testing (normally defined in shared.sh)
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export BLUE='\033[0;34m'
    export PURPLE='\033[0;35m'
    export CYAN='\033[0;36m'
    export WHITE='\033[1;37m'
    export NC='\033[0m'
    
    source "${INFRA_ROOT}/shared.sh"
    source "${INFRA_ROOT}/logger.sh"
    source "${INFRA_ROOT}/args.sh"
    source "${INFRA_ROOT}/modules.sh"
    
    # Enable test mode for proper error handling
    TEST_MODE=true
    export TEST_MODE
    
    # Override command validation for testing
    validate_required_commands() {
        debug_message "Skipping command validation in test environment"
    }
    
    # Mock validation functions for args.sh testing
    validate_action() {
        local action="$1"
        local supported_actions=("apply" "destroy" "plan" "init" "output" "volume" "clean" "reboot" "shutdown" "verify" "status")
        
        debug_message "Validating action: $action"
        
        for supported_action in "${supported_actions[@]}"; do
            if [[ "$action" == "$supported_action" ]]; then
                debug_message "Action is valid: $action"
                return 0
            fi
        done
        
        handle_error "Unsupported action: $action. Supported actions: ${supported_actions[*]}"
        return 1
    }
    
    # Mock validate_environment function - ENFORCES TEST ENVIRONMENT ONLY
    validate_environment() {
        local env="$1"
        local env_path="$LIVE_ROOT/$env"
        
        debug_message "Mock validating environment: $env at path: $env_path"
        
        # SECURITY: Only allow test environment for all tests
        if [[ "$env" != "$TEST_ENV" ]]; then
            handle_error "SECURITY: Tests can only run against '${TEST_ENV}' environment, not '$env'"
            return 1
        fi
        
        # For testing, we'll accept the hardcoded test environment
        case "$env" in
            "$TEST_ENV")
                debug_message "Environment validation successful: $env"
                return 0
                ;;
            *)
                handle_error "Environment directory not found: $env_path"
                return 1
                ;;
        esac
    }
    
    # Mock parse_target function
    parse_target() {
        local target="$1"
        if [[ "$target" =~ ^([^:]+):(.+)$ ]]; then
            # Full format: env:target
            export PARSED_ENV="${BASH_REMATCH[1]}"
            export PARSED_TARGET="${BASH_REMATCH[2]}"
            return 0
        elif [[ "$target" =~ ^[^:]+$ ]]; then
            # Shorthand format: env (implies :all)
            export PARSED_ENV="$target"
            export PARSED_TARGET="all"
            return 0
        else
            handle_error "Invalid target format: $target. Expected format: env:target or env"
            return 1
        fi
    }
    
    # Mock validate_parsed_arguments function
    validate_parsed_arguments() {
        # First validate the environment
        validate_environment "$ENVIRONMENT" || return 1
        
        # For reboot operations, check invalid targets
        if [[ "$ACTION" == "reboot" ]]; then
            case "$TARGET_TYPE" in
                "infrastructure"|"all")
                    handle_error "Cannot reboot $TARGET_TYPE target"
                    return 1
                    ;;
            esac
        fi
        
        # For volume operations, validate volume name and action
        if [[ "$ACTION" == "volume" ]]; then
            if [[ -z "$VOLUME_NAME" ]]; then
                handle_error "Volume name required"
                return 1
            fi
            if [[ -z "$VOLUME_ACTION" ]]; then
                handle_error "Volume action required"
                return 1
            fi
        fi
        
        return 0
    }
    
    # Mock validate_target_type function
    validate_target_type() {
        local target_type="$1"
        # Accept any target type for testing
        return 0
    }
    
    # Mock validate_volume_target function
    validate_volume_target() {
        local target_instance="$1"
        # Accept any volume target for testing
        return 0
    }
    
    # Mock validate_volume_name function
    validate_volume_name() {
        local volume_name="$1"
        
        # Check volume name format (alphanumeric, hyphens, underscores)
        if [[ ! "$volume_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            handle_error "Invalid volume name format: $volume_name. Use only alphanumeric characters, hyphens, and underscores"
            return 1
        fi
        
        # Check volume name length
        if [[ ${#volume_name} -gt 50 ]]; then
            handle_error "Volume name too long: $volume_name. Maximum 50 characters"
            return 1
        fi
        
        return 0
    }
    
    # Mock validate_reboot_target function
    validate_reboot_target() {
        local target_instance="$1"
        
        # Must be a single instance module, not infrastructure or all
        if [[ "$target_instance" == "infrastructure" || "$target_instance" == "all" || "$target_instance" == "instances" ]]; then
            handle_error "Cannot reboot $target_instance"
            return 1
        fi
        
        return 0
    }
    
    # Mock validate_flag_combinations function
    validate_flag_combinations() {
        # No additional flag validation needed for testing
        return 0
    }
    
    # Mock show_usage function
    show_usage() {
        echo "Usage: infra.sh <action> <target> [options]"
        echo "Action required"
    }
    
    # Mock show_help function
    show_help() {
        cat << 'EOF'
Infrastructure Management System v2.0

USAGE:
    ./infra.sh <action> <target> [options]

ACTIONS:
    apply        Apply infrastructure changes
    destroy      Destroy infrastructure
    plan         Show planned changes
    volume       Manage EBS volumes
    reboot       Reboot EC2 instances

FLAGS:
    --dry-run           Show what would be executed
    --verbose [0|1]     Verbosity level (0=default, 1=debug)
    --no-color          Disable color output
    --force             Force operations (for volume detach/AWS CLI operations)
    --backup            Create backup files (recommended for production)

EXAMPLES:
    # Standard operations
    ./infra.sh apply dev:infrastructure
    ./infra.sh destroy test:athena

    # Production operations with backups
    ./infra.sh apply prod:infrastructure --backup
    ./infra.sh volume prod:athena my-volume --detach --backup
EOF
    }
    
    # Initialize shared utilities with test-friendly settings
    init_shared_utilities
    
    # Set up global variables for testing (normally done by main infra script)
    set_global_vars "1" "false" "false" "$TEST_ENV" "" ""
}

# Source AWS helper functions for integration tests
source_aws_helpers() {
    source "${TEST_ROOT}/helpers/aws_helper.bash"
}

# Mock terragrunt command for testing
mock_terragrunt() {
    local mock_script="${TEST_TEMP_DIR}/terragrunt"
    cat > "${mock_script}" << 'EOF'
#!/bin/bash
# Mock terragrunt for testing
echo "MOCK: terragrunt $*" >&2
exit 0
EOF
    chmod +x "${mock_script}"
    export PATH="${TEST_TEMP_DIR}:${PATH}"
}

# Check if file contains expected content
file_contains() {
    local file="$1"
    local expected="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    grep -q "$expected" "$file"
}

# Check if log file was created with expected session
log_file_created() {
    local log_dir="$1"
    local log_type="$2"  # debug, infra, or terragrunt
    
    case "$log_type" in
        "debug")
            [[ -f "${log_dir}/debug.log" ]]
            ;;
        "infra")
            [[ -f "${log_dir}/infra.log" ]]
            ;;
        "terragrunt")
            [[ -f "${log_dir}/terragrunt.log" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Get the content of a log file
get_log_content() {
    local log_dir="$1"
    local log_type="$2"
    
    # Use absolute path to ensure we're reading from the correct location
    local log_file=""
    case "$log_type" in
        "debug")
            log_file="${log_dir}/debug.log"
            ;;
        "infra")
            log_file="${log_dir}/infra.log"
            ;;
        "terragrunt")
            log_file="${log_dir}/terragrunt.log"
            ;;
    esac
    
    if [[ -f "$log_file" ]]; then
        cat "$log_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Check if a test marker exists in debug log
# Usage: has_test_marker "log_dir" "LOGGING_SESSION_STARTED"
has_test_marker() {
    local log_dir="$1"
    local marker_name="$2"
    local debug_log="${log_dir}/debug.log"
    
    if [[ -f "$debug_log" ]]; then
        grep -q "\[TEST_MARKER\] $marker_name" "$debug_log"
    else
        return 1
    fi
}

# Get test marker value from debug log
# Usage: get_test_marker_value "log_dir" "LOGGING_SESSION_STARTED" "env"
get_test_marker_value() {
    local log_dir="$1"
    local marker_name="$2"
    local param_name="$3"
    local debug_log="${log_dir}/debug.log"
    
    if [[ -f "$debug_log" ]]; then
        # Extract the value after param_name= (handles quoted strings with spaces)
        grep "\[TEST_MARKER\] $marker_name" "$debug_log" | \
        sed -n "s/.*${param_name}=\(.*\)/\1/p" | \
        sed 's/ [a-zA-Z_]*=.*//' | \
        tail -1
    else
        echo ""
    fi
}

# Check if human log marker exists
# Usage: has_human_log_marker "log_dir" "HUMAN_LOG_INITIALIZED"
has_human_log_marker() {
    local log_dir="$1"
    local marker_name="$2"
    local human_log="${log_dir}/infra.log"
    
    if [[ -f "$human_log" ]]; then
        grep -q "\[TEST_MARKER\] $marker_name" "$human_log"
    else
        return 1
    fi
}

# Assert that a string contains expected text
assert_contains() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Expected '$actual' to contain '$expected'}"
    
    if [[ "$actual" != *"$expected"* ]]; then
        echo "$message" >&2
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-Expected file '$file' to exist}"
    
    if [[ ! -f "$file" ]]; then
        echo "$message" >&2
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Expected directory '$dir' to exist}"
    
    if [[ ! -d "$dir" ]]; then
        echo "$message" >&2
        return 1
    fi
} 