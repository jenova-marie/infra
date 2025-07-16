#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Mock Helpers
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Mocking utilities for unit tests to isolate functionality from external dependencies
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2025

# Global arrays to track mock calls and setup (bash 3.x compatible)
declare -a MOCK_CALLS=()

# Reset all mocks between tests
reset_mocks() {
    MOCK_CALLS=()
    # Clear any previously set mock variables
    unset AWS_MOCK_EXIT AWS_MOCK_OUTPUT
    unset TERRAGRUNT_MOCK_EXIT TERRAGRUNT_MOCK_OUTPUT
}

# Track a mock function call
track_mock_call() {
    local function_name="$1"
    shift
    local args="$*"
    MOCK_CALLS+=("${function_name}:${args}")
}

# Set up mock return value for AWS commands
mock_aws_command() {
    local command="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    
    case "$command" in
        "ec2 describe-instances")
            export AWS_EC2_DESCRIBE_INSTANCES_EXIT="$exit_code"
            export AWS_EC2_DESCRIBE_INSTANCES_OUTPUT="$output"
            ;;
        "ec2 describe-volumes")
            export AWS_EC2_DESCRIBE_VOLUMES_EXIT="$exit_code"
            export AWS_EC2_DESCRIBE_VOLUMES_OUTPUT="$output"
            ;;
        "ec2 reboot-instances")
            export AWS_EC2_REBOOT_INSTANCES_EXIT="$exit_code"
            export AWS_EC2_REBOOT_INSTANCES_OUTPUT="$output"
            ;;
        "ec2 detach-volume")
            export AWS_EC2_DETACH_VOLUME_EXIT="$exit_code"
            export AWS_EC2_DETACH_VOLUME_OUTPUT="$output"
            ;;
        *)
            export AWS_MOCK_EXIT="$exit_code"
            export AWS_MOCK_OUTPUT="$output"
            ;;
    esac
}

# Set up mock return value for terragrunt commands
mock_terragrunt_command() {
    local exit_code="${1:-0}"
    local output="${2:-}"
    
    export TERRAGRUNT_MOCK_EXIT="$exit_code"
    export TERRAGRUNT_MOCK_OUTPUT="$output"
}

# Get number of times a function was called
get_mock_call_count() {
    local function_name="$1"
    local count=0
    
    if [[ ${#MOCK_CALLS[@]} -gt 0 ]]; then
        for call in "${MOCK_CALLS[@]}"; do
            if [[ "$call" =~ ^${function_name}: ]]; then
                ((count++))
            fi
        done
    fi
    
    echo "$count"
}

# Check if a function was called with specific arguments
was_called_with() {
    local function_name="$1"
    shift
    local expected_args="$*"
    local expected_call="${function_name}:${expected_args}"
    
    if [[ ${#MOCK_CALLS[@]} -gt 0 ]]; then
        for call in "${MOCK_CALLS[@]}"; do
            if [[ "$call" == "$expected_call" ]]; then
                return 0
            fi
        done
    fi
    return 1
}

# Mock AWS CLI commands
aws() {
    track_mock_call "aws" "$@"
    
    case "$1 $2" in
        "sts get-caller-identity")
            echo '{"Account": "123456789012", "Arn": "arn:aws:iam::123456789012:user/test-user"}'
            return 0
            ;;
        "ec2 describe-instances")
            if [[ -n "${AWS_EC2_DESCRIBE_INSTANCES_EXIT}" ]]; then
                echo "${AWS_EC2_DESCRIBE_INSTANCES_OUTPUT}"
                return "${AWS_EC2_DESCRIBE_INSTANCES_EXIT}"
            fi
            echo '{"Reservations": []}'
            return 0
            ;;
        "ec2 describe-volumes")
            if [[ -n "${AWS_EC2_DESCRIBE_VOLUMES_EXIT}" ]]; then
                echo "${AWS_EC2_DESCRIBE_VOLUMES_OUTPUT}"
                return "${AWS_EC2_DESCRIBE_VOLUMES_EXIT}"
            fi
            echo '{"Volumes": []}'
            return 0
            ;;
        "ec2 reboot-instances")
            if [[ -n "${AWS_EC2_REBOOT_INSTANCES_EXIT}" ]]; then
                echo "${AWS_EC2_REBOOT_INSTANCES_OUTPUT}"
                return "${AWS_EC2_REBOOT_INSTANCES_EXIT}"
            fi
            echo "Reboot initiated for instances: $4"
            return 0
            ;;
        "ec2 detach-volume")
            if [[ -n "${AWS_EC2_DETACH_VOLUME_EXIT}" ]]; then
                echo "${AWS_EC2_DETACH_VOLUME_OUTPUT}"
                return "${AWS_EC2_DETACH_VOLUME_EXIT}"
            fi
            echo '{"State": "detaching", "VolumeId": "'$4'"}'
            return 0
            ;;
        *)
            echo "Mocked AWS CLI: $*" >&2
            return "${AWS_MOCK_EXIT:-0}"
            ;;
    esac
}

# Mock terragrunt commands
terragrunt() {
    track_mock_call "terragrunt" "$@"
    
    if [[ -n "${TERRAGRUNT_MOCK_EXIT}" ]]; then
        echo "${TERRAGRUNT_MOCK_OUTPUT}"
        return "${TERRAGRUNT_MOCK_EXIT}"
    fi
    
    case "$1" in
        "output")
            echo '{"instance_ids": {"value": {"athena": "i-0123456789abcdef0"}}}'
            return 0
            ;;
        "apply"|"destroy"|"plan")
            echo "Mock terragrunt $1 executed successfully"
            return 0
            ;;
        *)
            echo "Mock terragrunt: $*" >&2
            return 0
            ;;
    esac
}

# Mock file operations
# Override file test operators for specific paths
setup_file_mocks() {
    # Mock file existence checks
    mock_file_exists() {
        local file="$1"
        case "$file" in
            "/mock/project/src/live/test/root.hcl")
                return 0  # File exists
                ;;
            "/mock/project/src/live/test/outputs/athena.json")
                return 0  # File exists
                ;;
            "/mock/project/src/live/test/athena/volumes.yml")
                return 0  # File exists
                ;;
            "/nonexistent/"*)
                return 1  # File doesn't exist
                ;;
            *)
                # Default to checking real filesystem
                [[ -f "$file" ]]
                ;;
        esac
    }
    
    # Mock file read operations
    mock_cat() {
        local file="$1"
        track_mock_call "cat" "$file"
        
        case "$file" in
            "/mock/project/src/live/test/root.hcl")
                echo 'aws_region = "us-west-2"'
                ;;
            "/mock/project/src/live/test/outputs/athena.json")
                echo '{"instance_ids": {"value": {"athena": "i-0123456789abcdef0"}}, "volume_ids": {"value": {"test-volume": "vol-0123456789abcdef0"}}}'
                ;;
            "/mock/project/src/live/test/athena/volumes.yml")
                echo 'volumes:'
                echo '  test-volume:'
                echo '    device: /dev/xvdf'
                echo '    status: attached'
                ;;
            *)
                # If real file exists, read it
                if [[ -f "$file" ]]; then
                    command cat "$file"
                else
                    echo "Mock cat: file not found: $file" >&2
                    return 1
                fi
                ;;
        esac
    }
    
    # Mock grep operations
    mock_grep() {
        track_mock_call "grep" "$@"
        
        # For AWS region extraction from root.hcl
        if [[ "$*" =~ aws_region.*root\.hcl ]]; then
            echo 'aws_region = "us-west-2"'
            return 0
        fi
        
        # Default to real grep behavior for other cases
        command grep "$@"
    }
    
    # Mock cp (copy) operations
    mock_cp() {
        track_mock_call "cp" "$@"
        # For testing, just track the call without actually copying
        return 0
    }
    
    # Mock rm (remove) operations
    mock_rm() {
        track_mock_call "rm" "$@"
        # For testing, just track the call without actually removing
        return 0
    }
    
    # Mock ls operations for backup file listing
    mock_ls() {
        track_mock_call "ls" "$@"
        
        if [[ "$*" =~ volumes\.yml\.backup\.\* ]]; then
            # Return mock backup files
            echo "volumes.yml.backup.20250528_120000"
            echo "volumes.yml.backup.20250528_130000"
            echo "volumes.yml.backup.20250528_140000"
            echo "volumes.yml.backup.20250528_150000"
            echo "volumes.yml.backup.20250528_160000"
            return 0
        fi
        
        # Default behavior
        command ls "$@" 2>/dev/null || return 1
    }
    
    # Export mock functions to override commands
    export -f mock_file_exists
    export -f mock_cat
    export -f mock_grep
    export -f mock_cp
    export -f mock_rm
    export -f mock_ls
}

# Mock environment variables
setup_environment_mocks() {
    export PROJECT_ROOT="/mock/project"
    export ENVIRONMENT="test"
    export BACKUP="false"  # Default backup flag state
    export DRY_RUN="false"
    export VERBOSE_LEVEL="0"
    export FORCE="false"
}

# Setup mocks for volume operations
setup_volume_mocks() {
    debug_message "Setting up volume-specific mocks"
    
    # Mock backup flag checking functions
    is_backup() {
        if [[ "${BACKUP:-false}" == "true" ]]; then
            return 0
        else
            return 1
        fi
    }
    export -f is_backup
    
    # Mock environment path resolution
    get_environment_path() {
        local env="$1"
        echo "${TEST_TEMP_DIR}/src/live/$env"
    }
    export -f get_environment_path
    
    # Mock handle_error for tests
    handle_error() {
        local message="$1"
        echo "ERROR: $message" >&2
        return 1
    }
    export -f handle_error
    
    # Mock message functions
    debug_message() {
        echo "[DEBUG] $*" >&3
    }
    export -f debug_message
    
    info_message() {
        echo "[INFO] $*" >&3
    }
    export -f info_message
    
    warn_message() {
        echo "[WARN] $*" >&3  
    }
    export -f warn_message
    
    success_message() {
        echo "[SUCCESS] $*" >&3
    }
    export -f success_message
    
    # Mock terragrunt execution
    execute_terragrunt() {
        debug_message "[MOCK] execute_terragrunt called with: $*"
        return 0
    }
    export -f execute_terragrunt
}

# Setup mocks for argument parsing
setup_args_mocks() {
    setup_environment_mocks
    
    # Mock validation will succeed by default
    export VALIDATE_ENVIRONMENT_MOCK=0
    export VALIDATE_MODULE_MOCK=0
    export VALIDATE_VOLUME_NAME_MOCK=0
}

# Setup mocks for backup operations
setup_backup_mocks() {
    setup_file_mocks
    setup_environment_mocks
    
    # Mock the abstracted file operations (much simpler than mocking system commands)
    file_copy() {
        track_mock_call "file_copy" "$@"
        debug_message "Mock file_copy: $1 -> $2"
        return 0
    }
    export -f file_copy
    
    file_remove() {
        track_mock_call "file_remove" "$@"
        debug_message "Mock file_remove: $1"
        return 0
    }
    export -f file_remove
    
    get_backup_timestamp() {
        track_mock_call "get_backup_timestamp" "$@"
        echo "20250528_170000"
    }
    export -f get_backup_timestamp
    
    # Also mock the date command for timestamp generation
    date() {
        track_mock_call "date" "$@"
        if [[ "$*" == "+%Y%m%d_%H%M%S" ]]; then
            echo "20250528_170000"
        else
            command date "$@"
        fi
    }
    export -f date
    
    # Mock find/ls for backup file discovery (only if needed)
    find() {
        track_mock_call "find" "$@"
        if [[ "$*" =~ backup\.\* ]]; then
            printf '%s\0' "/test/volumes.yml.backup.20250528_120000" "/test/volumes.yml.backup.20250528_130000" "/test/volumes.yml.backup.20250528_140000"
        fi
    }
    export -f find
}

# Verify that expected mock calls were made
assert_mock_called() {
    local function_name="$1"
    local expected_count="${2:-1}"
    local actual_count
    
    actual_count=$(get_mock_call_count "$function_name")
    
    if [[ "$actual_count" != "$expected_count" ]]; then
        echo "Expected $function_name to be called $expected_count times, but was called $actual_count times" >&2
        return 1
    fi
}

# Verify that a function was called with specific arguments
assert_mock_called_with() {
    local function_name="$1"
    shift
    local expected_args="$*"
    
    if ! was_called_with "$function_name" "$expected_args"; then
        echo "Expected $function_name to be called with arguments: $expected_args" >&2
        echo "Actual calls:" >&2
        if [[ ${#MOCK_CALLS[@]} -gt 0 ]]; then
            for call in "${MOCK_CALLS[@]}"; do
                if [[ "$call" =~ ^${function_name}: ]]; then
                    echo "  $call" >&2
                fi
            done
        else
            echo "  (no calls made)" >&2
        fi
        return 1
    fi
}

# Print all mock calls for debugging
debug_mock_calls() {
    echo "Mock calls made:" >&2
    if [[ ${#MOCK_CALLS[@]} -gt 0 ]]; then
        for call in "${MOCK_CALLS[@]}"; do
            echo "  $call" >&2
        done
    else
        echo "  (no calls made)" >&2
    fi
}

# Set up shutdown-specific mocks
setup_shutdown_mocks() {
    # Mock flag checking functions
    is_bounce() {
        [[ "${BOUNCE:-false}" == "true" ]]
    }
    export -f is_bounce
    
    is_reboot() {
        [[ "${REBOOT:-false}" == "true" ]]
    }
    export -f is_reboot
    
    is_flush() {
        [[ "${FLUSH:-false}" == "true" ]]
    }
    export -f is_flush
    
    is_hard() {
        [[ "${HARD:-false}" == "true" ]]
    }
    export -f is_hard
    
    is_terminate() {
        [[ "${TERMINATE:-false}" == "true" ]]
    }
    export -f is_terminate
    
    # Mock operation context function
    get_operation_context() {
        export OP_ENV="${ENVIRONMENT:-$TEST_ENV}"
        export OP_TARGET_TYPE="${TARGET_TYPE:-athena}"
        export OP_ENV_PATH="${LIVE_ROOT}/${OP_ENV}"
        debug_message "Mock operation context set: env=$OP_ENV, target=$OP_TARGET_TYPE"
        return 0
    }
    export -f get_operation_context
    
    # Mock module validation functions
    is_valid_module() {
        local module="$1"
        case "$module" in
            "athena"|"aegis"|"metis"|"mnemosyne"|"eips"|"vpc"|"security_groups")
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }
    export -f is_valid_module
    
    get_module_type() {
        local module="$1"
        case "$module" in
            "athena"|"aegis"|"metis"|"mnemosyne")
                echo "instance"
                ;;
            "eips")
                echo "eips"
                ;;
            "vpc"|"security_groups")
                echo "infrastructure"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    }
    export -f get_module_type
    
    # Mock bounce operation function
    execute_bounce_operation() {
        local env="$1"
        local target_type="$2"
        shift 2
        local instances=("$@")
        
        track_mock_call "execute_bounce_operation" "$env" "$target_type" "${instances[*]}"
        
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would execute bounce operation for $env:$target_type"
            dry_run_message "[DRY-RUN] Would process instances: ${instances[*]}"
            dry_run_message "[DRY-RUN] Would complete: SSH shutdown → destroy → apply → output"
            info_message "ℹ️  [DRY-RUN] Bounce operation would complete successfully"
            return 0
        fi
        
        success_message "✅ Bounce operation completed successfully"
        return 0
    }
    export -f execute_bounce_operation
    
    # Mock terminate operation function
    execute_terminate_operation() {
        local env="$1"
        shift
        local instances=("$@")
        
        track_mock_call "execute_terminate_operation" "$env" "${instances[*]}"
        
        if is_dry_run; then
            if ! is_hard; then
                dry_run_message "[DRY-RUN] Would execute SSH shutdown for instances: ${instances[*]}"
                dry_run_message "[DRY-RUN] Would wait for instances to stop gracefully"
            else
                dry_run_message "[DRY-RUN] SSH shutdown - SKIPPED (hard mode enabled)"
            fi
            dry_run_message "[DRY-RUN] Would terminate instances via AWS CLI: ${instances[*]}"
            for instance in "${instances[@]}"; do
                dry_run_message "[DRY-RUN] Would execute: aws ec2 terminate-instances --instance-ids {$instance-id}"
            done
            info_message "ℹ️  [DRY-RUN] Terminate operations would complete successfully"
            return 0
        fi
        
        success_message "✅ Terminate operation completed successfully"
        return 0
    }
    export -f execute_terminate_operation
    
    # Mock hard operations functions
    execute_hard_shutdown_operations() {
        local env="$1"
        shift
        local instances=("$@")
        
        track_mock_call "execute_hard_shutdown_operations" "$env" "${instances[*]}"
        
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would terminate instances via AWS CLI: ${instances[*]}"
            for instance in "${instances[@]}"; do
                dry_run_message "[DRY-RUN] Would execute: aws ec2 terminate-instances --instance-ids {$instance-id}"
            done
            info_message "ℹ️  [DRY-RUN] Hard shutdown operations would complete successfully"
            return 0
        fi
        
        success_message "✅ Hard shutdown operations completed successfully"
        return 0
    }
    export -f execute_hard_shutdown_operations
    
    execute_hard_reboot_operations() {
        local env="$1"
        shift
        local instances=("$@")
        
        track_mock_call "execute_hard_reboot_operations" "$env" "${instances[*]}"
        
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would reboot instances via AWS CLI: ${instances[*]}"
            for instance in "${instances[@]}"; do
                dry_run_message "[DRY-RUN] Would execute: aws ec2 reboot-instances --instance-ids {$instance-id}"
            done
            info_message "ℹ️  [DRY-RUN] Hard reboot operations would complete successfully"
            return 0
        fi
        
        success_message "✅ Hard reboot operations completed successfully"
        return 0
    }
    export -f execute_hard_reboot_operations
    
    # Mock SSH operations function
    execute_parallel_ssh_operations() {
        local instances=("$@")
        local remote_command="${instances[-1]}"
        unset 'instances[-1]'  # Remove command from instances array
        
        track_mock_call "execute_parallel_ssh_operations" "${instances[*]}" "$remote_command"
        
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would execute SSH operations for instances: ${instances[*]}"
            dry_run_message "[DRY-RUN] Would execute: ssh {instance}-${OP_ENV} '$remote_command'"
            info_message "ℹ️  [DRY-RUN] SSH operations would complete successfully"
            return 0
        fi
        
        success_message "✅ SSH operations completed successfully"
        return 0
    }
    export -f execute_parallel_ssh_operations
    
    # Mock remote command building function
    build_remote_shutdown_command() {
        local result_var="$1"
        local cmd="~/scripts/shutdown.sh"
        
        if is_flush; then
            cmd="$cmd --flush"
        fi
        if is_reboot; then
            cmd="$cmd --reboot"
        fi
        
        eval "$result_var='$cmd'"
        debug_message "Built remote shutdown command: $cmd"
        return 0
    }
    export -f build_remote_shutdown_command
    
    # Mock finalization function
    finalize_shutdown_operation() {
        local message="$1"
        track_mock_call "finalize_shutdown_operation" "$message"
        debug_message "Mock shutdown operation finalized: $message"
        return 0
    }
    export -f finalize_shutdown_operation
} 