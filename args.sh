#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Argument Processing
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Command-line argument parsing and validation
# Author: Infrastructure Management System v2.0
# Last Updated: May 26, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Global Variables for Parsed Arguments
# ─────────────────────────────────────────────────────────────────────────────

# Core operation parameters
ACTION=""
TARGET=""
ENVIRONMENT=""
TARGET_TYPE=""

# Volume operation parameters (for volume action)
VOLUME_NAME=""
VOLUME_ACTION=""

# Shutdown operation parameters (for shutdown action)
BOUNCE=false
REBOOT=false
FLUSH=false
HARD=false
TERMINATE=false
NO_VOLUMES=false

# Operation flags
DRY_RUN=false
VERBOSE_LEVEL=0
NO_COLOR=false
FORCE=false
BACKUP=false
REFRESH=false
BELL=false
DNS=false
KNOWN_HOSTS_CLEANUP=true
CLEAN=false
AWS_REGION=""
TEST_MODE=false

# Endpoint flags
SSM=false
ECR=false
S3=false

# Gateway flags
VPCS=false

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing Functions
# ─────────────────────────────────────────────────────────────────────────────

# Main argument parsing function
# Usage: parse_arguments "$@"
parse_arguments() {
    debug_message "Starting argument parsing with: $*"
    
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    # Parse action (first argument)
    ACTION="$1"
    shift
    
    # Validate action
    if ! validate_action "$ACTION"; then
        return $?  # Return the error code from validate_action
    fi
    
    # Parse remaining arguments based on action
    case "$ACTION" in
        "apply"|"destroy"|"plan"|"init"|"output"|"clean")
            parse_standard_operation_args "$@"
            ;;
        "volume")
            parse_volume_operation_args "$@"
            ;;
        "shutdown")
            parse_shutdown_operation_args "$@"
            ;;
        "reboot")
            parse_reboot_operation_args "$@"
            ;;
        "verify")
            parse_verify_operation_args "$@"
            ;;
        "status")
            parse_status_operation_args "$@"
            ;;
        "query")
            parse_query_operation_args "$@"
            ;;
        *)
            handle_error "Unknown action: $ACTION"
            ;;
    esac
    
    # Validate parsed arguments
    validate_parsed_arguments || return 1
    
    debug_message "Argument parsing completed successfully"
    debug_message "Action: $ACTION, Target: $TARGET, Environment: $ENVIRONMENT, Target Type: $TARGET_TYPE"
}

# Parse arguments for standard operations (apply, destroy, plan, init, output)
# Usage: parse_standard_operation_args "dev:infrastructure" "--auto" "--verbose" "1"
parse_standard_operation_args() {
    debug_message "Parsing standard operation arguments: $*"
    
    if [[ $# -eq 0 ]]; then
        handle_error "Target required for $ACTION operation. Format: env:target"
        return 1
    fi
    
    # Parse target (required)
    TARGET="$1"
    shift
    
    # Parse target into environment and target type
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--force")
                FORCE=true
                debug_message "Force mode enabled for infrastructure operations"
                shift
                ;;
            "--dry-run")
                DRY_RUN=true
                debug_message "Dry-run mode enabled"
                shift
                ;;
            "--verbose")
                if [[ $# -gt 1 && "$2" =~ ^[01]$ ]]; then
                    VERBOSE_LEVEL="$2"
                    debug_message "Verbose level set to: $VERBOSE_LEVEL"
                    shift 2
                else
                    VERBOSE_LEVEL=1
                    debug_message "Verbose level set to: $VERBOSE_LEVEL (default)"
                    shift
                fi
                ;;
            "--no-color")
                NO_COLOR=true
                debug_message "Color output disabled"
                shift
                ;;
            "--backup")
                BACKUP=true
                debug_message "Backup mode enabled"
                shift
                ;;
            "--refresh")
                REFRESH=true
                debug_message "Refresh mode enabled - will refresh state before operation"
                shift
                ;;
            "--no-volumes")
                NO_VOLUMES=true
                debug_message "No-volumes mode enabled - will empty volumes.yml files before apply"
                shift
                ;;
            "--bell")
                BELL=true
                debug_message "Bell mode enabled"
                shift
                ;;
            "--dns")
                DNS=true
                debug_message "DNS update mode enabled"
                shift
                ;;
            "--no-known-hosts-cleanup")
                KNOWN_HOSTS_CLEANUP=false
                debug_message "Known hosts cleanup disabled for shutdown operation"
                shift
                ;;
            "--clean")
                CLEAN=true
                debug_message "Clean mode enabled - will remove output files"
                shift
                ;;
            "--region")
                if [[ $# -gt 1 && -n "$2" ]]; then
                    AWS_REGION="$2"
                    debug_message "AWS region manually specified: $AWS_REGION"
                    shift 2
                else
                    handle_error "--region flag requires a region value (e.g., --region us-west-2)"
                    return 1
                fi
                ;;
            "--test-mode")
                TEST_MODE=true
                debug_message "Test mode enabled - errors will return instead of exit"
                shift
                ;;
            "--ssm")
                SSM=true
                debug_message "SSM endpoint flag enabled"
                shift
                ;;
            "--ecr")
                ECR=true
                debug_message "ECR endpoint flag enabled"
                shift
                ;;
            "--s3")
                S3=true
                debug_message "S3 endpoint flag enabled"
                shift
                ;;
            "--vpcs")
                VPCS=true
                debug_message "VPCs gateway flag enabled - will apply VPCs after gateway operations"
                shift
                ;;
            *)
                handle_error "Unknown flag for $ACTION operation: $1"
                return 1
                ;;
        esac
    done
}

# Parse arguments for volume operations
# Usage: parse_volume_operation_args "dev:athena" "my-volume" "--attach" "--auto"
parse_volume_operation_args() {
    debug_message "Parsing volume operation arguments: $*"
    
    if [[ $# -lt 3 ]]; then
        handle_error "Volume operation requires: env:instance volume-name --attach|--detach [--auto] [--dry-run]"
        return 1
    fi
    
    # Parse target (required)
    TARGET="$1"
    shift
    
    # Parse target into environment and target type
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
    
    # Parse volume name (required)
    VOLUME_NAME="$1"
    shift
    
    # Parse volume action (required)
    if [[ $# -eq 0 ]]; then
        handle_error "Volume action required: --attach or --detach"
        return 1
    fi
    
    case "$1" in
        "--attach")
                    VOLUME_ACTION="attach"
            debug_message "Volume action: attach"
            shift
            ;;
        "--detach")
            VOLUME_ACTION="detach"
            debug_message "Volume action: detach"
            shift
            ;;
        *)
            handle_error "Invalid volume action: $1. Use --attach or --detach"
            return 1
            ;;
    esac
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--force")
                FORCE=true
                debug_message "Force mode enabled for volume operation"
                shift
                ;;
            "--dry-run")
                DRY_RUN=true
                debug_message "Dry-run mode enabled for volume operation"
                shift
                ;;
            "--verbose")
                if [[ $# -gt 1 && "$2" =~ ^[01]$ ]]; then
                    VERBOSE_LEVEL="$2"
                    debug_message "Verbose level set to: $VERBOSE_LEVEL"
                    shift 2
                else
                    VERBOSE_LEVEL=1
                    debug_message "Verbose level set to: $VERBOSE_LEVEL (default)"
                    shift
                fi
                ;;
            "--no-color")
                NO_COLOR=true
                debug_message "Color output disabled"
                shift
                ;;
            "--backup")
                BACKUP=true
                debug_message "Backup mode enabled for volume operation"
                shift
                ;;
            "--refresh")
                REFRESH=true
                debug_message "Refresh mode enabled for volume operation - will refresh outputs after operation"
                shift
                ;;
            "--bell")
                BELL=true
                debug_message "Bell mode enabled for volume operation"
                shift
                ;;
            "--dns")
                DNS=true
                debug_message "DNS update mode enabled for volume operation"
                shift
                ;;
            "--no-known-hosts-cleanup")
                KNOWN_HOSTS_CLEANUP=false
                debug_message "Known hosts cleanup disabled for volume operation"
                shift
                ;;
            "--test-mode")
                TEST_MODE=true
                debug_message "Test mode enabled - errors will return instead of exit"
                shift
                ;;
            "--vpcs")
                VPCS=true
                debug_message "VPCs gateway flag enabled - will apply VPCs after gateway operations"
                shift
                ;;
            *)
                handle_error "Unknown flag for volume operation: $1"
                return 1
                ;;
        esac
    done
}

# Parse arguments for shutdown operations
# Usage: parse_shutdown_operation_args "dev:athena" "--dry-run" "--verbose"
parse_shutdown_operation_args() {
    debug_message "Parsing shutdown operation arguments: $*"
    
    if [[ $# -eq 0 ]]; then
        handle_error "Target required for $ACTION operation. Format: env:instance"
        return 1
    fi
    
    # Parse target (required)
    TARGET="$1"
    shift
    
    # Parse target into environment and target type
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--bounce")
                BOUNCE=true
                debug_message "Bounce mode enabled - will execute graceful stop→destroy→apply→output sequence"
                shift
                ;;
            "--reboot")
                REBOOT=true
                debug_message "Reboot mode enabled - will execute SSH reboot"
                shift
                ;;
            "--flush")
                FLUSH=true
                debug_message "Flush mode enabled - will execute SSH flush/cleanup"
                shift
                ;;
            "--hard")
                HARD=true
                debug_message "Hard mode enabled - will use AWS CLI only (no SSH scripts)"
                shift
                ;;
            "--terminate")
                TERMINATE=true
                debug_message "Terminate mode enabled for shutdown operation"
                shift
                ;;
            "--no-volumes")
                NO_VOLUMES=true
                debug_message "No-volumes mode enabled - instances will be recreated without volumes"
                shift
                ;;
            "--force")
                FORCE=true
                debug_message "Force mode enabled for shutdown operation"
                shift
                ;;
            "--dry-run")
                DRY_RUN=true
                debug_message "Dry-run mode enabled for shutdown operation"
                shift
                ;;
            "--verbose")
                if [[ $# -gt 1 && "$2" =~ ^[01]$ ]]; then
                    VERBOSE_LEVEL="$2"
                    debug_message "Verbose level set to: $VERBOSE_LEVEL"
                    shift 2
                else
                    VERBOSE_LEVEL=1
                    debug_message "Verbose level set to: $VERBOSE_LEVEL (default)"
                    shift
                fi
                ;;
            "--no-color")
                NO_COLOR=true
                debug_message "Color output disabled"
                shift
                ;;
            "--backup")
                BACKUP=true
                debug_message "Backup mode enabled for shutdown operation"
                shift
                ;;
            "--bell")
                BELL=true
                debug_message "Bell mode enabled for shutdown operation"
                shift
                ;;
            "--dns")
                DNS=true
                debug_message "DNS update mode enabled for shutdown operation"
                shift
                ;;
            "--no-known-hosts-cleanup")
                KNOWN_HOSTS_CLEANUP=false
                debug_message "Known hosts cleanup disabled for shutdown operation"
                shift
                ;;
            "--test-mode")
                TEST_MODE=true
                debug_message "Test mode enabled - errors will return instead of exit"
                shift
                ;;
            "--vpcs")
                VPCS=true
                debug_message "VPCs gateway flag enabled - will apply VPCs after gateway operations"
                shift
                ;;
            *)
                handle_error "Unknown flag for shutdown operation: $1"
                return 1
                ;;
        esac
    done
}

# Parse arguments for reboot operations
# Usage: parse_reboot_operation_args "dev:athena" "--dry-run" "--verbose"
parse_reboot_operation_args() {
    debug_message "Parsing reboot operation arguments: $*"
    
    if [[ $# -eq 0 ]]; then
        handle_error "Target required for $ACTION operation. Format: env:instance"
        return 1
    fi
    
    # Parse target (required)
    TARGET="$1"
    shift
    
    # Parse target into environment and target type
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--force")
                FORCE=true
                debug_message "Force mode enabled for reboot operation"
                shift
                ;;
            "--dry-run")
                DRY_RUN=true
                debug_message "Dry-run mode enabled for reboot operation"
                shift
                ;;
            "--verbose")
                if [[ $# -gt 1 && "$2" =~ ^[01]$ ]]; then
                    VERBOSE_LEVEL="$2"
                    debug_message "Verbose level set to: $VERBOSE_LEVEL"
                    shift 2
                else
                    VERBOSE_LEVEL=1
                    debug_message "Verbose level set to: $VERBOSE_LEVEL (default)"
                    shift
                fi
                ;;
            "--no-color")
                NO_COLOR=true
                debug_message "Color output disabled"
                shift
                ;;
            "--bell")
                BELL=true
                debug_message "Bell mode enabled for reboot operation"
                shift
                ;;
            "--dns")
                DNS=true
                debug_message "DNS update mode enabled for reboot operation"
                shift
                ;;
            "--no-known-hosts-cleanup")
                KNOWN_HOSTS_CLEANUP=false
                debug_message "Known hosts cleanup disabled for reboot operation"
                shift
                ;;
            "--test-mode")
                TEST_MODE=true
                debug_message "Test mode enabled - errors will return instead of exit"
                shift
                ;;
            "--vpcs")
                VPCS=true
                debug_message "VPCs gateway flag enabled - will apply VPCs after gateway operations"
                shift
                ;;
            *)
                handle_error "Unknown flag for reboot operation: $1"
                return 1
                ;;
        esac
    done
}

# Parse arguments for verify operations
# Usage: parse_verify_operation_args "dev:infrastructure" "--verbose" "1"
parse_verify_operation_args() {
    debug_message "Parsing verify operation arguments: $*"
    
    if [[ $# -eq 0 ]]; then
        handle_error "Target required for verify operation. Format: env:target"
        return 1
    fi
    
    # Parse target (required)
    TARGET="$1"
    shift
    
    # Parse target into environment and target type
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
    
    # Parse optional flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "--verbose")
                if [[ $# -gt 1 && "$2" =~ ^[01]$ ]]; then
                    VERBOSE_LEVEL="$2"
                    debug_message "Verbose level set to: $VERBOSE_LEVEL"
                    shift 2
                else
                    VERBOSE_LEVEL=1
                    debug_message "Verbose level set to: $VERBOSE_LEVEL (default)"
                    shift
                fi
                ;;
            "--dry-run")
                DRY_RUN=true
                debug_message "Dry-run mode enabled (note: verify is always read-only)"
                shift
                ;;
            "--no-color")
                NO_COLOR=true
                debug_message "Color output disabled"
                shift
                ;;
            "--bell")
                BELL=true
                debug_message "Bell mode enabled for verify operation"
                shift
                ;;
            "--dns")
                DNS=true
                debug_message "DNS update mode enabled for verify operation"
                shift
                ;;
            "--no-known-hosts-cleanup")
                KNOWN_HOSTS_CLEANUP=false
                debug_message "Known hosts cleanup disabled for verify operation"
                shift
                ;;
            "--test-mode")
                TEST_MODE=true
                debug_message "Test mode enabled - errors will return instead of exit"
                shift
                ;;
            *)
                handle_error "Unknown flag for verify operation: $1"
                return 1
                ;;
        esac
    done
}

# Parse status operation arguments
# Usage: parse_status_operation_args "$@"
parse_status_operation_args() {
    debug_message "Parsing status operation arguments"
    
    # Status uses same argument parsing as verify
    parse_standard_operation_args "$@"
    
    debug_message "Status operation argument parsing completed"
}

# Add a new function to parse query arguments
parse_query_operation_args() {
    debug_message "Parsing query operation arguments: $*"
    if [[ $# -ne 2 ]]; then
        handle_error "Query operation requires two arguments: <env>:<target>[,<target2>...] <path>"
        return 1
    fi
    TARGET="$1"
    QUERY_PATH="$2"
    # Parse target into environment and target type (for consistency)
    parse_target "$TARGET" || return 1
    ENVIRONMENT="$PARSED_ENV"
    TARGET_TYPE="$PARSED_TARGET"
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Validate all parsed arguments
# Usage: validate_parsed_arguments
validate_parsed_arguments() {
    debug_message "Validating parsed arguments"
    
    # Validate environment exists
    validate_environment "$ENVIRONMENT" || return 1
    
    # Validate target type based on action
    case "$ACTION" in
        "apply"|"destroy"|"plan"|"init"|"output"|"clean")
            validate_target_type "$TARGET_TYPE"
            ;;
        "volume")
            validate_volume_target "$TARGET_TYPE"
            validate_volume_name "$VOLUME_NAME"
            ;;
        "shutdown")
            validate_shutdown_target "$TARGET_TYPE"
            ;;
        "reboot")
            validate_reboot_target "$TARGET_TYPE"
            ;;
        "verify")
            validate_verify_target "$TARGET_TYPE"
            ;;
        "status")
            validate_status_target "$TARGET_TYPE"
            ;;
    esac
    
    # Validate flag combinations
    validate_flag_combinations
    
    debug_message "Argument validation completed successfully"
}

# Validate target type for standard operations
# Usage: validate_target_type "infrastructure"
validate_target_type() {
    local target_type="$1"
    local valid_targets=("infrastructure" "instances" "all")
    
    debug_message "Validating target type: $target_type"
    
    # Check if it's a standard target type
    for valid_target in "${valid_targets[@]}"; do
        if [[ "$target_type" == "$valid_target" ]]; then
            debug_message "Target type is valid: $target_type"
            return 0
        fi
    done
    
    # If not a standard target, assume it's a module name (validation will happen after loading modules.yml)
    debug_message "Target type assumed to be module: $target_type"
}

# Validate target for volume operations (must be an instance module)
# Usage: validate_volume_target "athena"
validate_volume_target() {
    local target_instance="$1"
    
    debug_message "Validating volume target: $target_instance"
    
    # Volume target validation will happen after loading modules.yml
    
    debug_message "Volume target validation successful: $target_instance"
}

# Validate volume name format
# Usage: validate_volume_name "my-volume"
validate_volume_name() {
    local volume_name="$1"
    
    debug_message "Validating volume name: $volume_name"
    
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
    
    debug_message "Volume name validation successful: $volume_name"
}

# Validate target for shutdown operations (must be an instance module)
# Usage: validate_shutdown_target "athena"
validate_shutdown_target() {
    local target_instance="$1"
    
    debug_message "Validating shutdown target: $target_instance"
    
    # Shutdown target validation will happen after loading modules.yml
    # Must be a single instance module, instances, or all - infrastructure is not supported
    if [[ "$target_instance" == "infrastructure" ]]; then
        handle_error "Shutdown operation requires a specific instance target (e.g., athena, aegis) or instances/all, not: $target_instance"
        return 1
    fi
    
    debug_message "Shutdown target validation successful: $target_instance"
}

# Validate target for reboot operations (must be an instance module)
# Usage: validate_reboot_target "athena"
validate_reboot_target() {
    local target_instance="$1"
    
    debug_message "Validating reboot target: $target_instance"
    
    # Reboot target validation will happen after loading modules.yml
    # Must be a single instance module, not infrastructure or all
    if [[ "$target_instance" == "infrastructure" || "$target_instance" == "all" || "$target_instance" == "instances" ]]; then
        handle_error "Reboot operation requires a specific instance target (e.g., athena, aegis), not: $target_instance"
        return 1
    fi
    
    debug_message "Reboot target validation successful: $target_instance"
}

# Validate target for verify operations (supports all target types)
# Usage: validate_verify_target "athena"
validate_verify_target() {
    local target_type="$1"
    
    debug_message "Validating verify target: $target_type"
    
    # Verify supports all target types (infrastructure, instances, all, or specific modules)
    # No specific validation needed as all targets are valid for verification
    debug_message "Verify target validation successful: $target_type"
}

# Validate status target type
# Usage: validate_status_target "athena"
validate_status_target() {
    local target="$1"
    
    debug_message "Validating status target: $target"
    
    # Status works with all target types that verify supports
    validate_verify_target "$target"
}

# Module validation is now handled by modules.sh after loading modules.yml

# Validate flag combinations
# Usage: validate_flag_combinations
validate_flag_combinations() {
    debug_message "Validating flag combinations"
    
    # No additional flag validation needed
    
    debug_message "Flag combination validation completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Accessor Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get parsed action
# Usage: get_action
get_action() {
    echo "$ACTION"
}

# Get parsed target
# Usage: get_target
get_target() {
    echo "$TARGET"
}

# Get parsed environment
# Usage: get_environment
get_environment() {
    echo "$ENVIRONMENT"
}

# Get parsed target type
# Usage: get_target_type
get_target_type() {
    echo "$TARGET_TYPE"
}

# Get volume name (for volume operations)
# Usage: get_volume_name
get_volume_name() {
    echo "$VOLUME_NAME"
}

# Get volume action (for volume operations)
# Usage: get_volume_action
get_volume_action() {
    echo "$VOLUME_ACTION"
}

# ─────────────────────────────────────────────────────────────────────────────
# Flag Checking Functions
# ─────────────────────────────────────────────────────────────────────────────

# NOTE: is_dry_run() function moved to shared.sh for KISS approach standardization

# Check if verbose mode is enabled
# Usage: is_verbose
is_verbose() {
    [[ "$VERBOSE_LEVEL" -ge 1 ]]
}

# Get verbose level
# Usage: get_verbose_level
get_verbose_level() {
    echo "$VERBOSE_LEVEL"
}

# Check if color output is disabled
# Usage: is_no_color
is_no_color() {
    [[ "$NO_COLOR" == true ]]
}

# Check if force mode is enabled
# Usage: is_force
is_force() {
    [[ "$FORCE" == true ]]
}

# Check if backup mode is enabled
# Usage: is_backup
is_backup() {
    [[ "$BACKUP" == true ]]
}

# Check if refresh mode is enabled
# Usage: is_refresh
is_refresh() {
    [[ "$REFRESH" == true ]]
}

# Check if bell mode is enabled
# Usage: is_bell
is_bell() {
    [[ "$BELL" == true ]]
}

# Check if DNS update mode is enabled
# Usage: is_dns
is_dns() {
    [[ "$DNS" == true ]]
}

# Check if known hosts cleanup is enabled
# Usage: is_known_hosts_cleanup
is_known_hosts_cleanup() {
    [[ "$KNOWN_HOSTS_CLEANUP" == true ]]
}

# Check if bounce mode is enabled
# Usage: is_bounce
is_bounce() {
    [[ "$BOUNCE" == true ]]
}

# Check if reboot mode is enabled
# Usage: is_reboot
is_reboot() {
    [[ "$REBOOT" == true ]]
}

# Check if flush mode is enabled
# Usage: is_flush
is_flush() {
    [[ "$FLUSH" == true ]]
}

# Check if hard mode is enabled
# Usage: is_hard
is_hard() {
    [[ "$HARD" == true ]]
}

# Check if terminate mode is enabled
# Usage: is_terminate
is_terminate() {
    [[ "$TERMINATE" == true ]]
}

# Check if clean mode is enabled  
# Usage: is_clean
is_clean() {
    [[ "$CLEAN" == true ]]
}

# Check if test mode is enabled
# Usage: is_test_mode
is_test_mode() {
    [[ "$TEST_MODE" == true ]]
}

# Check if no-volumes mode is enabled
# Usage: is_no_volumes  
is_no_volumes() {
    [[ "$NO_VOLUMES" == true ]]
}

# Check if SSM endpoint flag is enabled
# Usage: is_ssm
is_ssm() {
    [[ "$SSM" == true ]]
}

# Check if ECR endpoint flag is enabled
# Usage: is_ecr
is_ecr() {
    [[ "$ECR" == true ]]
}

# Check if S3 endpoint flag is enabled
# Usage: is_s3
is_s3() {
    [[ "$S3" == true ]]
}

# Check if VPCs gateway flag is enabled
# Usage: is_vpcs
is_vpcs() {
    [[ "$VPCS" == true ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Help and Usage Functions
# ─────────────────────────────────────────────────────────────────────────────

# Show usage information
# Usage: show_usage
show_usage() {
    cat << 'EOF'
🌟 Infrastructure Management System v2.0 - Complete Command Reference

USAGE:
    ./infra <action> <target> [flags]

═══════════════════════════════════════════════════════════════════════════
🔧 CORE ACTIONS
═══════════════════════════════════════════════════════════════════════════

APPLY - Deploy and update infrastructure
  Usage: ./infra apply <target> [flags]
  
  Purpose: Executes Terragrunt apply to create or update infrastructure resources
  Examples:
    ./infra apply dev:infrastructure         # Apply all infrastructure modules
    ./infra apply dev:instances             # Apply all instance modules  
    ./infra apply dev:athena                # Apply single module
    ./infra apply dev:all --backup         # Apply all with backup
    ./infra apply dev:infrastructure --dry-run --verbose 1
    ./infra apply dev:all --no-volumes     # Apply without volumes
  
  Requirements: 
    - Valid Terragrunt configuration
    - Appropriate AWS credentials
    - Target environment must exist

DESTROY - Remove infrastructure
  Usage: ./infra destroy <target> [flags]
  
  Purpose: Executes Terragrunt destroy to remove infrastructure resources
  Examples:
    ./infra destroy dev:athena              # Destroy single module
    ./infra destroy dev:instances           # Destroy all instances
    ./infra destroy dev:all --dry-run       # Dry-run destroy all
    ./infra destroy dev:infrastructure --force  # Force destroy protected modules
  
  ⚠️  PROTECTED MODULES: Some critical infrastructure modules are protected by default:
    • eips (Elastic IP addresses)
    • ebss (EBS volumes)  
    • ecrs (Container registries)
    
    These modules have 'protected: true' in modules.yml and cannot be destroyed
    without the --force flag to prevent accidental data loss.
  
  ⚠️  WARNING: This permanently removes resources! Use --dry-run first.
  Requirements:
    - Existing Terraform state
    - AWS credentials with delete permissions
    - Use --force to destroy protected modules

PLAN - Preview infrastructure changes  
  Usage: ./infra plan <target> [flags]
  
  Purpose: Shows what changes would be made without executing them
  Examples:
    ./infra plan dev:infrastructure         # Plan infrastructure changes
    ./infra plan dev:all --verbose 1       # Plan with detailed output
    ./infra plan dev:athena               # Plan single module changes
  
  Benefits: Safe way to preview changes before applying
  Requirements: Valid Terragrunt configuration

INIT - Initialize Terraform modules
  Usage: ./infra init <target> [flags]
  
  Purpose: Downloads providers and initializes Terraform backend
  Examples:
    ./infra init dev:infrastructure         # Initialize infrastructure modules
    ./infra init dev:all                   # Initialize all modules
    ./infra init dev:athena               # Initialize single module
  
  When to use: First time setup, provider updates, backend changes
  Requirements: Valid Terragrunt configuration, AWS credentials

OUTPUT - Generate Terraform outputs
  Usage: ./infra output <target> [flags]
  
  Purpose: Generates JSON output files for use by other operations
  Examples:
    ./infra output dev:infrastructure       # Generate infrastructure outputs
    ./infra output dev:instances           # Generate instance outputs
    ./infra output dev:athena              # Generate single module outputs
    ./infra output dev:ebss                # Generate EBS volume outputs
  
  Output Location: <env>/outputs/<module>.json
  Requirements: Applied Terraform state

CLEAN - Remove Terragrunt cache
  Usage: ./infra clean <target> [flags]
  
  Purpose: Removes .terragrunt-cache directories and terraform state files to force re-initialization
  Examples:
    ./infra clean dev:all                  # Clean all module caches and state files
    ./infra clean dev:infrastructure       # Clean infrastructure caches and state files
    ./infra clean dev:athena               # Clean single module cache and state files
  
  When to use: Cache corruption, provider issues, debugging, state file cleanup

═══════════════════════════════════════════════════════════════════════════
💾 VOLUME MANAGEMENT
═══════════════════════════════════════════════════════════════════════════

VOLUME - Attach/detach EBS volumes
  Usage: ./infra volume <env:instance> <volume-name> <--attach|--detach> [flags]
  
  Purpose: Manage EBS volume attachments to EC2 instances
  
  ATTACH Examples:
    ./infra volume dev:athena my-volume --attach
      └─ Attaches volume to next available device (/dev/sdf, /dev/sdg, etc.)
    
    ./infra volume prod:aegis data-volume --attach --backup
      └─ Attach with backup of volume configuration
    
    ./infra volume dev:mnemosyne temp-volume --attach --dry-run
      └─ Preview attachment without executing
  
  DETACH Examples:
    ./infra volume dev:athena my-volume --detach
      └─ Standard detachment using Terragrunt
    
    ./infra volume dev:athena my-volume --detach --force
      └─ Force detachment using AWS CLI (for stuck volumes)
    
    ./infra volume prod:aegis data-volume --detach --backup
      └─ Detach with backup of configuration
  
  Device Assignment: Automatic assignment to /dev/sdf through /dev/sdp
  Volume Resolution: Accepts volume names or volume IDs (vol-xxxxxxxx)
  
  Requirements:
    - EBS outputs must exist: ./infra output <env>:ebss
    - Instance outputs must exist: ./infra output <env>:<instance>
    - Volume must be in same AZ as instance
    - AWS CLI required for --force operations

═══════════════════════════════════════════════════════════════════════════
🔄 INSTANCE MANAGEMENT
═══════════════════════════════════════════════════════════════════════════

SHUTDOWN - Graceful instance shutdown and management
  Usage: ./infra shutdown <env:instance> [flags]
  
  Purpose: Unified command for shutdown-related operations with different behaviors 
  based on flags. Supports both SSH-based operations and infrastructure recreation.
  
  OPERATION MODES:
  
    🏗️  BOUNCE MODE (--bounce)
      Infrastructure recreation sequence: SSH shutdown → wait → destroy → apply → output
      Purpose: Complete infrastructure rebuild with proper application shutdown
      
    🔄 REBOOT MODE (--reboot)  
      SSH shutdown + AWS restart: SSH shutdown → wait → start
      Purpose: Restart instances with proper application shutdown
      
    🧹 FLUSH MODE (--flush)
      SSH-based cleanup and preparation operations
      Purpose: Clean instance state without restart
      
    🛑 DEFAULT MODE (no flags)
      SSH-based shutdown via remote scripts  
      Purpose: Graceful instance shutdown
  
  Examples:
    ./infra shutdown dev:athena              # Graceful shutdown
    ./infra shutdown dev:athena --bounce     # Complete rebuild
    ./infra shutdown dev:athena --reboot     # Restart instance
    ./infra shutdown dev:athena --flush      # Clean instance state
    ./infra shutdown dev:athena --hard       # AWS CLI only (no SSH)
    ./infra shutdown dev:athena --terminate  # Terminate instance
    ./infra shutdown dev:athena --no-volumes # Recreate without volumes
  
  Requirements:
    - Instance outputs must exist: ./infra output <env>:<instance>
    - SSH access for graceful operations
    - AWS CLI for --hard operations

REBOOT - Restart AWS instances
  Usage: ./infra reboot <env:instance> [flags]
  
  Purpose: Reboot EC2 instances using AWS CLI
  Examples:
    ./infra reboot dev:athena               # Reboot instance
    ./infra reboot prod:aegis --verbose 1  # Reboot with detailed output
    ./infra reboot dev:mnemosyne --dry-run  # Preview reboot command
  
  Process:
    1. Retrieves instance ID from outputs
    2. Executes AWS CLI reboot command
    3. Monitors reboot status
  
  Requirements:
    - AWS CLI installed and configured
    - Instance outputs must exist: ./infra output <env>:<instance>
    - AWS credentials with EC2 reboot permissions

═══════════════════════════════════════════════════════════════════════════
🔍 VERIFICATION & STATUS
═══════════════════════════════════════════════════════════════════════════

VERIFY - Verify infrastructure state
  Usage: ./infra verify <target> [flags]
  
  Purpose: Verify infrastructure state and configuration
  Examples:
    ./infra verify dev:infrastructure       # Verify infrastructure state
    ./infra verify dev:instances           # Verify instance state
    ./infra verify dev:athena              # Verify single module
  
  Benefits: Validate infrastructure health and configuration
  Requirements: Applied Terraform state

STATUS - Show infrastructure status
  Usage: ./infra status <target> [flags]
  
  Purpose: Display current infrastructure status and health
  Examples:
    ./infra status dev:infrastructure       # Show infrastructure status
    ./infra status dev:instances           # Show instance status
    ./infra status dev:athena              # Show single module status
  
  Benefits: Quick overview of infrastructure health
  Requirements: Applied Terraform state

═══════════════════════════════════════════════════════════════════════════
🎯 TARGETS & ENVIRONMENTS
═══════════════════════════════════════════════════════════════════════════

TARGET FORMATS:
  <env>:infrastructure     All infrastructure modules (VPC, security, etc.)
  <env>:instances         All instance modules (athena, aegis, mnemosyne)
  <env>:all              All modules (infrastructure + instances)
  <env>:<module-name>     Single specific module
  
AVAILABLE ENVIRONMENTS:
  dev                     Development environment
  test                    Test environment  
  prod                    Production environment
  
EXAMPLE MODULES:
  athena                  Primary compute instance
  aegis                   Security/monitoring instance  
  mnemosyne              Memory/storage instance
  metis                   Analytics instance
  ebss                   EBS volume definitions
  eips                   Elastic IP addresses
  ecrs                   Container registries
  vpcs                   Virtual Private Clouds
  security_groups         Security group configurations

═══════════════════════════════════════════════════════════════════════════
🚩 FLAGS & OPTIONS
═══════════════════════════════════════════════════════════════════════════

GLOBAL FLAGS (available for all commands):
  --dry-run              Preview operations without executing
                         • Shows exact commands that would run
                         • Safe for testing and validation
                         • No state changes made
  
  --verbose [0|1]        Control output verbosity
                         • 0: Standard output (default)
                         • 1: Debug output with detailed logging
                         • Shows command execution, timing, paths
  
  --no-color             Disable colored output
                         • Useful for logging to files
                         • Better for CI/CD environments
  
  --backup               Create backup files
                         • Recommended for production operations
                         • Backs up volume configurations
                         • Creates timestamped backups
  
  --bell                 Ring terminal bell on completion
                         • Audio notification for long operations
                         • Useful for background operations
  
  --dns                  Update DNS records after operation
                         • Automatically updates DNS after changes
                         • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                         Disable known_hosts cleanup for SSH operations
                         • Keeps SSH known_hosts entries
                         • Useful for debugging SSH connections
  
  --test-mode            Enable test mode (errors return instead of exit)
                         • Useful for testing and automation
                         • Errors return exit codes instead of exiting
  
  --region <aws-region>  Manually specify AWS region
                         • Override automatic region detection
                         • Format: us-west-2, us-east-1, etc.

SPECIALIZED FLAGS:
  --force                Force operations (volume detach, AWS CLI, destroy protected)
                         • Volume: Use AWS CLI force detachment
                         • Destroy: Override protected module restrictions
                         • Bypasses normal safety checks
                         • Use with caution!
  
  --refresh              Refresh state/outputs before operation
                         • Updates Terraform state before operation
                         • Regenerates outputs before operation
                         • Useful for stale state issues
  
  --no-volumes           Empty volumes.yml files before apply
                         • Removes all volume attachments
                         • Instances recreated without EBS volumes
                         • Useful for testing or migration scenarios
  
  --clean                Remove output files after operation
                         • Cleans up JSON output files
                         • Useful for space management

SHUTDOWN-SPECIFIC FLAGS:
  --bounce               Complete infrastructure rebuild
                         • SSH shutdown → wait → destroy → apply → output
                         • Full infrastructure recreation
                         • Use for major changes or troubleshooting
  
  --reboot               Restart instance with SSH shutdown
                         • SSH shutdown → wait → AWS restart
                         • Graceful restart with application shutdown
                         • Use for software updates or troubleshooting
  
  --flush                Clean instance state
                         • SSH-based cleanup operations
                         • No restart or infrastructure changes
                         • Use for state cleanup or preparation
  
  --hard                 AWS CLI only (no SSH scripts)
                         • Uses AWS CLI for all operations
                         • Bypasses SSH-based graceful shutdown
                         • Use when SSH is unavailable
  
  --terminate            Terminate instance
                         • Permanently removes instance
                         • Use with extreme caution!
                         • Requires --force for confirmation

VOLUME-SPECIFIC FLAGS:
  --attach               Attach volume to instance
                         • Automatic device assignment
                         • Next available device (/dev/sdf, /dev/sdg, etc.)
  
  --detach               Detach volume from instance
                         • Standard Terragrunt detachment
                         • Use --force for AWS CLI detachment

═══════════════════════════════════════════════════════════════════════════
⚠️  IMPORTANT NOTES
═══════════════════════════════════════════════════════════════════════════

OUTPUT DEPENDENCIES:
  • Volume operations require: ./infra output <env>:ebss
  • Reboot operations require: ./infra output <env>:<instance>
  • Always generate outputs after infrastructure changes

SAFETY PRACTICES:
  • Always use --dry-run for destructive operations first
  • Use --backup for production changes
  • Test in dev environment before production
  • Keep volume configurations backed up

AWS REQUIREMENTS:
  • AWS CLI installed and configured for reboot/force operations
  • Appropriate IAM permissions for target resources
  • Instance and volumes must be in same AWS region/AZ

FILE LOCATIONS:
  • Outputs: <env>/outputs/<module>.json
  • Logs: /tmp/infra-<timestamp>-<operation>.log
  • Backups: <env>/volumes/<instance>-volumes-<timestamp>.yml

For specific command help: ./infra <action> --help
For troubleshooting: Use --verbose 1 flag for detailed output

EOF
}

# Show detailed help for specific action
# Usage: show_action_help "apply"
show_action_help() {
    local action="$1"
    
    case "$action" in
        "apply")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🚀 APPLY ACTION - Deploy and Update Infrastructure
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Executes Terragrunt apply to create or update infrastructure resources.
  This is the primary command for deploying changes to your infrastructure.

USAGE:
  ./infra apply <target> [flags]

PARAMETERS:
  <target>               Target specification (required)
                         Format: <environment>:<module-type|module-name>

SUPPORTED TARGETS:
  dev:infrastructure     All infrastructure modules (VPC, security, networking)
  dev:instances         All instance modules (athena, aegis, mnemosyne) 
  dev:all              All modules (infrastructure + instances)
  dev:athena           Single module deployment
  prod:infrastructure   Production infrastructure
  prod:all             All production modules

FLAGS:
  --dry-run            Preview what would be applied without making changes
                       • Shows Terraform plan output
                       • Safe for testing and validation
                       • No state modifications
  
  --verbose [0|1]      Control output detail level
                       • 0: Standard output (default)
                       • 1: Debug output with command tracing
  
  --backup             Create backup files before applying
                       • Recommended for production changes
                       • Creates timestamped backups
                       • Includes volume configurations
  
  --no-volumes         Empty volumes.yml files before apply (recreate instances without volumes)
                       • Removes all volume attachments
                       • Instances recreated without EBS volumes
                       • Useful for testing or migration scenarios
  
  --no-color           Disable colored output for logging/CI
  
  --force              Force operations (override protected module restrictions)
                       • Allows destruction of protected modules during apply
                       • Use with caution!
  
  --refresh            Refresh state/outputs before operation
                       • Updates Terraform state before operation
                       • Regenerates outputs before operation
                       • Useful for stale state issues
  
  --clean              Remove output files after operation
                       • Cleans up JSON output files
                       • Useful for space management
  
  --bell               Ring terminal bell on completion
                       • Audio notification for long operations
                       • Useful for background operations
  
  --dns                Update DNS records after operation
                       • Automatically updates DNS after changes
                       • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                       Disable known_hosts cleanup for SSH operations
                       • Keeps SSH known_hosts entries
                       • Useful for debugging SSH connections
  
  --test-mode          Enable test mode (errors return instead of exit)
                       • Useful for testing and automation
                       • Errors return exit codes instead of exiting
  
  --ssm                Enable SSM-related endpoints
                       • Enables SSM, SSM Messages, EC2 Messages, and Secrets Manager endpoints
                       • Only affects endpoints module deployment
                       • Use when instances need Systems Manager access
  
  --ecr                Enable ECR-related endpoints
                       • Enables ECR endpoint for container registry access
                       • Only affects endpoints module deployment
                       • Use when instances need to pull/push container images
  
  --s3                 Enable S3-related endpoints
                       • Enables S3 endpoint for object storage access
                       • Only affects endpoints module deployment
                       • Use when instances need S3 access without internet
  
  --vpcs               Enable VPCs reapplication after gateway operations
                       • Automatically applies VPCs module after gateway instance changes
                       • Only triggers for instances marked with 'gateway: true' in modules.yml
                       • Ensures routing tables stay synchronized with gateway NICs
  
  --region <aws-region> Manually specify AWS region
                       • Override automatic region detection
                       • Format: us-west-2, us-east-1, etc.

EXAMPLES:
  # Standard deployments
  ./infra apply dev:infrastructure
  ./infra apply dev:instances
  ./infra apply dev:all
  
  # Production with safety
  ./infra apply prod:infrastructure --backup --dry-run
  ./infra apply prod:infrastructure --backup
  
  # Testing and validation
  ./infra apply dev:athena --dry-run --verbose 1
  ./infra apply dev:all --no-volumes
  
  # Endpoint-specific deployments
  ./infra apply dev:endpoints --ssm
  ./infra apply dev:endpoints --ecr
  ./infra apply dev:endpoints --ssm --ecr
  
  # With notifications and DNS
  ./infra apply dev:infrastructure --bell --dns
  ./infra apply prod:all --backup --bell --dns

REQUIREMENTS:
  • Valid Terragrunt configuration
  • Appropriate AWS credentials
  • Target environment must exist

POST-APPLY:
  • Outputs are automatically generated
  • Volume configurations are preserved
  • DNS records updated if --dns flag used

EOF
            ;;
        "destroy")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🗑️  DESTROY ACTION - Remove Infrastructure Resources
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Executes Terragrunt destroy to remove infrastructure resources.
  ⚠️  WARNING: This permanently removes resources! Use --dry-run first.

USAGE:
  ./infra destroy <target> [flags]

PARAMETERS:
  <target>               Target specification (required)
                         Format: <environment>:<module-type|module-name>

SUPPORTED TARGETS:
  dev:infrastructure     All infrastructure modules (VPC, security, networking)
  dev:instances         All instance modules (athena, aegis, mnemosyne) 
  dev:all              All modules (infrastructure + instances)
  dev:athena           Single module destruction
  prod:infrastructure   Production infrastructure (USE WITH EXTREME CAUTION)
  prod:all             All production modules (USE WITH EXTREME CAUTION)

PROTECTED MODULES:
  ⚠️  CRITICAL: Some modules are protected from accidental destruction:
    • eips (Elastic IP addresses) - prevents accidental IP loss
    • ebss (EBS volumes) - prevents data loss  
    • ecrs (Container registries) - prevents image loss
  
  These modules have 'protected: true' in modules.yml and cannot be destroyed
  without the --force flag to prevent accidental data loss.

FLAGS:
  --force              Force destruction of protected modules
                       • Overrides protected: true protection
                       • Allows destruction of eips, ebss, ecrs
                       • Use with extreme caution!
  
  --dry-run            Preview what would be destroyed without executing
                       • Shows Terraform plan output
                       • Safe for testing and validation
                       • No state modifications
  
  --verbose [0|1]      Control output detail level
                       • 0: Standard output (default)
                       • 1: Debug output with command tracing
  
  --backup             Create backup files before destroying
                       • Recommended for production operations
                       • Creates timestamped backups
                       • Includes volume configurations
  
  --no-color           Disable colored output for logging/CI
  
  --refresh            Refresh state/outputs before operation
                       • Updates Terraform state before operation
                       • Regenerates outputs before operation
                       • Useful for stale state issues
  
  --clean              Remove output files after operation
                       • Cleans up JSON output files
                       • Useful for space management
  
  --bell               Ring terminal bell on completion
                       • Audio notification for long operations
                       • Useful for background operations
  
  --dns                Update DNS records after operation
                       • Automatically updates DNS after changes
                       • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                       Disable known_hosts cleanup for SSH operations
                       • Keeps SSH known_hosts entries
                       • Useful for debugging SSH connections
  
  --test-mode          Enable test mode (errors return instead of exit)
                       • Useful for testing and automation
                       • Errors return exit codes instead of exiting
  
  --region <aws-region> Manually specify AWS region
                       • Override automatic region detection
                       • Format: us-west-2, us-east-1, etc.

EXAMPLES:
  # Safe testing (always use --dry-run first!)
  ./infra destroy dev:athena --dry-run
  ./infra destroy dev:instances --dry-run --verbose 1
  
  # Destroy non-protected modules
  ./infra destroy dev:athena
  ./infra destroy dev:instances
  
  # Force destroy protected modules (DANGEROUS!)
  ./infra destroy dev:infrastructure --force
  ./infra destroy dev:all --force --backup
  
  # Production destruction (EXTREME CAUTION!)
  ./infra destroy prod:athena --dry-run --backup
  ./infra destroy prod:athena --backup

REQUIREMENTS:
  • Existing Terraform state for target resources
  • AWS credentials with delete permissions
  • No dependent resources in other modules

POST-DESTRUCTION:
  • Output files are automatically cleaned up
  • Terraform state reflects destroyed resources
  • Volume attachments are automatically cleaned

⚠️  SAFETY REMINDERS:
  • ALWAYS use --dry-run first to preview changes
  • Use --backup for production operations
  • Protected modules require --force to destroy
  • Test in dev environment before production
  • This permanently removes resources!

EOF
            ;;
        "plan")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
📋 PLAN ACTION - Preview Infrastructure Changes
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Shows what changes would be made to infrastructure without executing them.
  Essential for validating changes before applying them.

USAGE:
  ./infra plan <target> [flags]

BENEFITS:
  • Safe preview of all changes
  • No modifications to actual infrastructure
  • Validates Terragrunt configuration
  • Shows resource additions, modifications, deletions
  • Estimates cost impact of changes

FLAGS:
  --verbose [0|1]      Enhanced output with detailed resource information
  --no-color           Plain text output for logging/parsing

PLAN OUTPUT INDICATORS:
  + resource             Will be created
  ~ resource             Will be modified
  - resource             Will be destroyed
  +/- resource           Will be replaced (destroyed and recreated)

EXAMPLES:
  # Plan infrastructure changes
  ./infra plan dev:infrastructure
  
  # Detailed planning with debug info
  ./infra plan dev:all --verbose 1
  
  # Plan single module changes
  ./infra plan dev:athena
  
  # Pipeline-friendly output
  ./infra plan dev:infrastructure --no-color

WHEN TO USE PLAN:
  • Before any apply operation
  • To validate configuration changes
  • For code review and approval processes
  • Troubleshooting configuration issues
  • Understanding impact of changes

REQUIREMENTS:
  • Valid Terragrunt configuration
  • AWS credentials for state access
  • Existing Terraform state (for modifications)

PLAN VALIDATION CHECKLIST:
  ✓ Are the expected changes shown?
  ✓ Are there any unexpected changes?
  ✓ Will critical resources be destroyed?
  ✓ Are dependencies properly ordered?
  ✓ Do resource counts look reasonable?

EOF
            ;;
        "init")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🔧 INIT ACTION - Initialize Terraform Modules
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Downloads Terraform providers and initializes the backend configuration.
  Required before first use or after configuration changes.

USAGE:
  ./infra init <target> [flags]

WHEN TO RUN INIT:
  • First time setting up a new environment
  • After updating provider versions
  • When changing backend configuration
  • After cleaning Terragrunt cache
  • When encountering provider-related errors
  • Moving between different machines/environments

WHAT INIT DOES:
  1. Downloads and installs Terraform providers
  2. Configures remote state backend (S3)
  3. Sets up provider configurations
  4. Validates Terragrunt configuration syntax
  5. Creates .terragrunt-cache directories

FLAGS:
  --verbose [0|1]      Show detailed initialization output
  --no-color           Plain text output

EXAMPLES:
  # Initialize all modules
  ./infra init dev:all
  
  # Initialize infrastructure only
  ./infra init dev:infrastructure
  
  # Initialize with detailed output
  ./infra init dev:athena --verbose 1
  
  # Initialize production environment
  ./infra init dev:all

TROUBLESHOOTING INIT ISSUES:
  • Provider download failures: Check internet connectivity
  • Backend access issues: Verify AWS credentials
  • Configuration errors: Check terragrunt.hcl syntax
  • Cache corruption: Run ./infra clean first

INITIALIZATION ORDER:
  Generally safe to initialize in any order, but recommended:
  1. Infrastructure modules first
  2. Instance modules second

REQUIREMENTS:
  • Valid Terragrunt configuration files
  • AWS credentials for backend access
  • Internet connectivity for provider downloads
  • S3 bucket for Terraform state (configured in backend)

POST-INITIALIZATION:
  • Providers are cached locally
  • Backend is configured and validated
  • Ready for plan/apply operations
  • .terragrunt-cache directories created

EOF
            ;;
        "output")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
📤 OUTPUT ACTION - Generate Terraform Outputs
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Generates JSON output files from Terraform state for use by other operations.
  Essential for inter-module communication and external tool integration.

USAGE:
  ./infra output <target> [flags]

OUTPUT FILE LOCATIONS:
  All outputs are saved as: <environment>/outputs/<module>.json

CRITICAL OUTPUTS NEEDED:
  dev:ebss               EBS volume IDs and configurations
                         Required for: volume operations
  
  dev:athena             Instance IDs, IPs, and configurations  
  dev:aegis              Required for: reboot operations
  dev:mnemosyne          Required for: volume attachment
  
  dev:infrastructure     VPC, security groups, networking info
                         Required for: instance deployment

OUTPUT DEPENDENCIES:
  • Volume operations require EBS outputs
  • Reboot operations require instance outputs  
  • Instance deployment requires infrastructure outputs
  • Cross-module references need respective outputs

FLAGS:
  --refresh              Refresh Terraform state before generating outputs
                         • Calls 'terragrunt refresh' before 'terragrunt output'
                         • Updates state from current cloud resources
                         • Ensures outputs reflect actual infrastructure state
                         
  --verbose [0|1]        Show detailed output generation process
  --no-color             Plain text output for parsing

EXAMPLES:
  # Generate all infrastructure outputs
  ./infra output dev:infrastructure
  
  # Generate refreshed EBS volume outputs (recommended for volume operations)
  ./infra output dev:ebss --refresh
  
  # Generate refreshed instance outputs (recommended for reboot)
  ./infra output dev:athena --refresh
  
  # Generate all outputs with refresh
  ./infra output dev:all --refresh
  
  # Production outputs with state refresh
  ./infra output dev:infrastructure --refresh

TYPICAL OUTPUT WORKFLOW:
  1. After applying infrastructure: ./infra output dev:infrastructure
  2. After applying instances: ./infra output dev:instances  
  3. Before volume operations: ./infra output dev:ebss
  4. Before reboots: ./infra output dev:<instance>

OUTPUT FILE STRUCTURE:
  {
    "output_name": {
      "sensitive": false,
      "type": "string|object|list",
      "value": "actual_output_value"
    }
  }

COMMON OUTPUT USES:
  • Volume management needs volume_ids from ebss
  • Instance reboots need instance_ids from instances
  • Security group references from infrastructure
  • Network configuration for new resources

REQUIREMENTS:
  • Applied Terraform state for target modules
  • Read access to Terraform state backend
  • Output definitions in Terraform modules

⚠️  IMPORTANT:
  • Outputs must be regenerated after infrastructure changes
  • Some operations will fail without current outputs
  • Output files are automatically created during apply operations

EOF
            ;;
        "clean")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🧹 CLEAN ACTION - Remove Cache, Outputs, Logs & Terraform State
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Removes .terragrunt-cache, output.json, logs, outputs/, and .terraform files.
  KISS approach for complete cleanup based on target scope.

USAGE:
  ./infra clean <target> [flags]

WHAT GETS CLEANED (Module Level):
  • .terragrunt-cache/     - Terragrunt cache directories
  • output.json           - Generated output files
  • .terraform/           - Terraform state and provider cache  
  • .terraform.lock.hcl   - Terraform dependency lock files
  • terraform.tfstate     - Local terraform state files
  • terraform.tfstate.backup - Local terraform state backup files

WHAT GETS CLEANED (Environment Level - only with 'all' target):
  • <env>/log/            - All operation logs
  • <env>/outputs/        - All consolidated outputs
  • <env>/.terraform*     - Environment-level terraform files
  • <env>/terraform.tfstate* - Environment-level terraform state files

TARGET-BASED CLEANING:
  dev:all                 Clean EVERYTHING in dev environment
  dev:infrastructure      Clean infrastructure modules only
  dev:instances          Clean instance modules only  
  dev:athena             Clean single module only

WHEN TO USE CLEAN:
  • Provider version conflicts
  • Cache corruption errors
  • Strange Terraform behavior
  • After major updates
  • Fresh start needed
  • Disk space cleanup
  • Troubleshooting

FLAGS:
  --dry-run            Preview what would be cleaned
  --verbose [0|1]      Show detailed cleaning process
  --no-color           Plain text output

EXAMPLES:
  # Clean everything in dev environment
  ./infra clean dev:all
  
  # Clean infrastructure modules only
  ./infra clean dev:infrastructure
  
  # Clean instance modules only
  ./infra clean dev:instances
  
  # Clean single module
  ./infra clean dev:athena
  
  # Preview cleaning with dry-run
  ./infra clean dev:all --dry-run
  
  # Clean with detailed output
  ./infra clean dev:all --verbose 1

TYPICAL CLEAN WORKFLOW:
  1. ./infra clean dev:all               # Full cleanup
  2. ./infra init dev:all                # Re-initialize
  3. ./infra plan dev:infrastructure     # Plan infrastructure
  4. ./infra apply dev:infrastructure    # Apply infrastructure
  5. ./infra output dev:infrastructure   # Generate outputs

WHAT HAPPENS AFTER CLEANING:
  • Must run init again before plan/apply
  • Providers will be re-downloaded
  • Cache will be rebuilt
  • Output files must be regenerated
  • Fresh start for all operations

⚠️  CONSIDERATIONS:
  • Requires internet connectivity for re-initialization
  • Output files needed for volume/instance operations will be deleted
  • Logs will be deleted (all target only)
  • No impact on actual infrastructure
  • No impact on remote Terraform state

DISK SPACE RECOVERY:
  Significant disk space recovery from:
  • Terragrunt cache directories
  • Downloaded providers
  • Generated output files
  • Operation logs
  • Terraform plugin cache

REQUIREMENTS:
  • No special requirements for cleaning
  • Safe to run at any time
  • Does not affect remote state or infrastructure

EOF
            ;;
        "volume")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
💾 VOLUME ACTION - Manage EBS Volume Attachments
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Attach and detach EBS volumes to/from EC2 instances.
  Supports both Terragrunt-based and AWS CLI-based operations.

USAGE:
  ./infra volume <env:instance> <volume-name> <--attach|--detach> [flags]

PARAMETERS:
  <env:instance>        Target instance specification (required)
                        Format: <environment>:<instance-name>
  <volume-name>         Volume name or ID (required)
                        Accepts: volume names or volume IDs (vol-xxxxxxxx)
  <--attach|--detach>   Volume operation (required)

SUPPORTED TARGETS:
  dev:athena           Primary compute instance
  dev:aegis            Security/monitoring instance
  dev:mnemosyne        Memory/storage instance
  dev:metis            Analytics instance
  prod:athena          Production compute instance
  prod:aegis           Production security instance

VOLUME OPERATIONS:

  ATTACH - Attach volume to instance
    Usage: ./infra volume <env:instance> <volume-name> --attach [flags]
    
    Process:
      1. Validates volume and instance compatibility
      2. Finds next available device (/dev/sdf, /dev/sdg, etc.)
      3. Attaches volume using Terragrunt or AWS CLI
      4. Updates volume configuration files
    
    Examples:
      ./infra volume dev:athena my-volume --attach
      ./infra volume prod:aegis data-volume --attach --backup
      ./infra volume dev:mnemosyne temp-volume --attach --dry-run

  DETACH - Detach volume from instance
    Usage: ./infra volume <env:instance> <volume-name> --detach [flags]
    
    Process:
      1. Validates volume is currently attached
      2. Detaches using Terragrunt (standard) or AWS CLI (--force)
      3. Updates volume configuration files
      4. Cleans up device mappings
    
    Examples:
      ./infra volume dev:athena my-volume --detach
      ./infra volume dev:athena my-volume --detach --force
      ./infra volume prod:aegis data-volume --detach --backup

FLAGS:
  --attach              Attach volume to instance
                       • Automatic device assignment
                       • Next available device (/dev/sdf, /dev/sdg, etc.)
  
  --detach              Detach volume from instance
                       • Standard Terragrunt detachment
                       • Use --force for AWS CLI detachment
  
  --force               Force operations (AWS CLI detachment)
                       • Volume: Use AWS CLI force detachment for stuck volumes
                       • Bypasses normal safety checks
                       • Use when Terragrunt detachment fails
  
  --dry-run            Preview operation without executing
                       • Shows exact commands that would run
                       • Safe for testing and validation
                       • No state modifications
  
  --verbose [0|1]      Control output detail level
                       • 0: Standard output (default)
                       • 1: Debug output with command tracing
  
  --backup             Create backup files before operation
                       • Recommended for production operations
                       • Creates timestamped backups
                       • Includes volume configurations
  
  --no-color           Disable colored output for logging/CI
  
  --refresh            Refresh state/outputs before operation
                       • Updates Terraform state before operation
                       • Regenerates outputs before operation
                       • Useful for stale state issues
  
  --bell               Ring terminal bell on completion
                       • Audio notification for long operations
                       • Useful for background operations
  
  --dns                Update DNS records after operation
                       • Automatically updates DNS after changes
                       • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                       Disable known_hosts cleanup for SSH operations
                       • Keeps SSH known_hosts entries
                       • Useful for debugging SSH connections
  
  --test-mode          Enable test mode (errors return instead of exit)
                       • Useful for testing and automation
                       • Errors return exit codes instead of exiting
  
  --region <aws-region> Manually specify AWS region
                       • Override automatic region detection
                       • Format: us-west-2, us-east-1, etc.

DEVICE ASSIGNMENT:
  Automatic assignment to next available device:
    • /dev/sdf (first available)
    • /dev/sdg (second available)
    • /dev/sdh (third available)
    • ... through /dev/sdp (maximum 16 devices)

VOLUME RESOLUTION:
  Accepts both volume names and volume IDs:
    • Volume names: "my-volume", "data-volume"
    • Volume IDs: "vol-12345678", "vol-abcdef12"

EXAMPLES:
  # Standard volume operations
  ./infra volume dev:athena my-volume --attach
  ./infra volume dev:athena my-volume --detach
  
  # Production with safety
  ./infra volume prod:aegis data-volume --attach --backup
  ./infra volume prod:aegis data-volume --detach --backup
  
  # Force operations for stuck volumes
  ./infra volume dev:athena stuck-volume --detach --force
  
  # Testing and validation
  ./infra volume dev:mnemosyne temp-volume --attach --dry-run
  ./infra volume dev:athena my-volume --detach --verbose 1
  
  # With notifications and DNS
  ./infra volume dev:athena my-volume --attach --bell --dns

REQUIREMENTS:
  • EBS outputs must exist: ./infra output <env>:ebss
  • Instance outputs must exist: ./infra output <env>:<instance>
  • Volume must be in same AZ as instance
  • AWS CLI required for --force operations

POST-OPERATION:
  • Volume configurations are updated automatically
  • Device mappings are tracked in volume files
  • DNS records updated if --dns flag used

EOF
            ;;
        "shutdown")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🔄 SHUTDOWN ACTION - Infrastructure Recreation Management
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Unified command for infrastructure recreation operations with different behaviors 
  based on flags. All operations use infrastructure management (destroy → apply → output).

USAGE:
  ./infra shutdown <env:instance> [flags]

PARAMETERS:
  <env:instance>        Target instance specification (required)
                        Format: <environment>:<instance-name>

SUPPORTED TARGETS:
  dev:athena           Primary compute instance
  dev:aegis            Security/monitoring instance
  dev:mnemosyne        Memory/storage instance
  dev:metis            Analytics instance
  prod:athena          Production compute instance
  prod:aegis           Production security instance

OPERATION MODES:

  🏗️  BOUNCE MODE (--bounce)
    Infrastructure recreation sequence: destroy → apply → output
    Purpose: Complete infrastructure rebuild with fresh state
    
    Process:
      1. Destroy instance infrastructure
      2. Apply instance infrastructure (recreate)
      3. Generate outputs
    
    Use for: Major changes, troubleshooting, complete rebuilds
  
  🔄 REBOOT MODE (--reboot)  
    Infrastructure recreation for restart: destroy → apply → output
    Purpose: Restart instances with fresh infrastructure state
    
    Process:
      1. Destroy instance infrastructure
      2. Apply instance infrastructure (recreate)
      3. Generate outputs
    
    Use for: Software updates, troubleshooting, application restarts
  
  🧹 FLUSH MODE (--flush)
    Infrastructure recreation for cleanup: destroy → apply → output
    Purpose: Clean instance state with fresh infrastructure
    
    Process:
      1. Destroy instance infrastructure
      2. Apply instance infrastructure (recreate)
      3. Generate outputs
    
    Use for: State cleanup, preparation, maintenance
  
  🛑 DEFAULT MODE (no flags)
    Infrastructure recreation: destroy → apply → output
    Purpose: Standard infrastructure recreation
    
    Process:
      1. Destroy instance infrastructure
      2. Apply instance infrastructure (recreate)
      3. Generate outputs
    
    Use for: Normal infrastructure recreation, maintenance

FLAGS:
  --bounce              Complete infrastructure rebuild
                       • destroy → apply → output
                       • Full infrastructure recreation
                       • Use for major changes or troubleshooting
  
  --reboot              Restart with infrastructure recreation
                       • destroy → apply → output
                       • Fresh infrastructure state
                       • Use for software updates or troubleshooting
  
  --flush               Clean state with infrastructure recreation
                       • destroy → apply → output
                       • Fresh infrastructure state
                       • Use for state cleanup or preparation
  
  --no-volumes          Recreate without volumes
                       • Instances recreated without EBS volumes
                       • Useful for testing or migration scenarios
  
  --force               Force operations (bypass safety checks)
                       • Override confirmation prompts
                       • Bypasses normal safety checks
                       • Use with caution!
  
  --dry-run             Preview operation without executing
                       • Shows exact commands that would run
                       • Safe for testing and validation
                       • No state modifications
  
  --verbose [0|1]       Control output detail level
                       • 0: Standard output (default)
                       • 1: Debug output with command tracing
  
  --backup              Create backup files before operation
                       • Recommended for production operations
                       • Creates timestamped backups
                       • Includes volume configurations
  
  --no-color            Disable colored output for logging/CI
  
  --bell                Ring terminal bell on completion
                       • Audio notification for long operations
                       • Useful for background operations
  
  --dns                 Update DNS records after operation
                       • Automatically updates DNS after changes
                       • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                        Disable known_hosts cleanup for SSH operations
                        • Keeps SSH known_hosts entries
                        • Useful for debugging SSH connections
  
  --test-mode           Enable test mode (errors return instead of exit)
                       • Useful for testing and automation
                       • Errors return exit codes instead of exiting
  
  --region <aws-region> Manually specify AWS region
                       • Override automatic region detection
                       • Format: us-west-2, us-east-1, etc.

EXAMPLES:
  # Standard infrastructure recreation
  ./infra shutdown dev:athena
  ./infra shutdown prod:aegis --backup
  
  # Complete infrastructure rebuild
  ./infra shutdown dev:athena --bounce
  ./infra shutdown prod:aegis --bounce --backup
  
  # Restart with infrastructure recreation
  ./infra shutdown dev:mnemosyne --reboot
  ./infra shutdown prod:athena --reboot --bell
  
  # Clean state with infrastructure recreation
  ./infra shutdown dev:metis --flush
  ./infra shutdown dev:athena --flush --verbose 1
  
  # Recreate without volumes
  ./infra shutdown dev:athena --bounce --no-volumes
  
  # Testing and validation
  ./infra shutdown dev:athena --bounce --dry-run
  ./infra shutdown dev:athena --reboot --verbose 1

REQUIREMENTS:
  • Valid Terragrunt configuration
  • Appropriate AWS credentials
  • Target environment must exist

POST-OPERATION:
  • Outputs are regenerated automatically
  • DNS records updated if --dns flag used
  • Volume configurations preserved (unless --no-volumes)

⚠️  SAFETY REMINDERS:
  • Use --dry-run to preview operations
  • Use --backup for production operations
  • Infrastructure recreation destroys and recreates instances
  • Test in dev environment before production

EOF
            ;;
        "reboot")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🔄 REBOOT ACTION - Restart AWS Instances
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Restart EC2 instances using AWS CLI.

USAGE:
  ./infra reboot <env:instance> [flags]

PARAMETERS:
  <env:instance>         Target instance (e.g., dev:athena, dev:aegis)

FLAGS:
  --verbose [0|1]        Show detailed output during operations
  --no-color             Disable colored output

EXAMPLES:
  # Reboot instance
  ./infra reboot dev:athena
  
  # Reboot with detailed output
  ./infra reboot dev:aegis --verbose 1
  
  # Preview reboot command
  ./infra reboot dev:mnemosyne --dry-run

REQUIREMENTS:
  • AWS CLI installed and configured
  • Instance outputs must exist: ./infra output <env>:<instance>
  • AWS credentials with EC2 reboot permissions

EOF
            ;;
        "query")
            cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════
🔍 QUERY ACTION - Retrieve Infrastructure Data
═══════════════════════════════════════════════════════════════════════════

PURPOSE:
  Retrieve data from infrastructure modules based on a query path.

USAGE:
  ./infra query <env>:<target>[,<target2>...] <path>

PARAMETERS:
  <env>:<target>[,<target2>...]
                        Target specification (required)
                        Format: <environment>:<module-type|module-name>[,<module-type|module-name>...]
  <path>                Query path (required)
                        Format: <module-path>.<output-name>

SUPPORTED TARGETS:
  dev:infrastructure     All infrastructure modules (VPC, security, networking)
  dev:instances         All instance modules (athena, aegis, mnemosyne) 
  dev:all              All modules (infrastructure + instances)
  dev:athena           Single module deployment
  prod:infrastructure   Production infrastructure
  prod:all             All production modules

FLAGS:
  --dry-run            Preview what would be queried without executing
                       • Shows exact commands that would run
                       • Safe for testing and validation
                       • No state changes made
  
  --verbose [0|1]      Control output verbosity
                         • 0: Standard output (default)
                         • 1: Debug output with detailed logging
                         • Shows command execution, timing, paths
  
  --no-color           Disable colored output
                         • Useful for logging to files
                         • Better for CI/CD environments
  
  --backup             Create backup files
                         • Recommended for production operations
                         • Backs up volume configurations
                         • Creates timestamped backups
  
  --bell               Ring terminal bell on completion
                         • Audio notification for long operations
                         • Useful for background operations
  
  --dns                Update DNS records after operation
                         • Automatically updates DNS after changes
                         • Requires DNS module to be configured
  
  --no-known-hosts-cleanup
                         Disable known_hosts cleanup for SSH operations
                         • Keeps SSH known_hosts entries
                         • Useful for debugging SSH connections
  
  --test-mode          Enable test mode (errors return instead of exit)
                         • Useful for testing and automation
                         • Errors return exit codes instead of exiting
  
  --ssm                Enable SSM-related endpoints
                         • Enables SSM, SSM Messages, EC2 Messages, and Secrets Manager endpoints
                         • Only affects endpoints module deployment
                         • Use when instances need Systems Manager access
  
  --ecr                Enable ECR-related endpoints
                         • Enables ECR endpoint for container registry access
                         • Only affects endpoints module deployment
                         • Use when instances need to pull/push container images
  
  --region <aws-region> Manually specify AWS region
                         • Override automatic region detection
                         • Format: us-west-2, us-east-1, etc.

EXAMPLES:
  # Query infrastructure data
  ./infra query dev:infrastructure.eips
  ./infra query dev:instances.athena.ip
  ./infra query dev:all.security_groups.sg-1
  
  # Query multiple targets
  ./infra query dev:infrastructure,instances.athena.ip,security_groups.sg-1
  
  # Query production data
  ./infra query prod:infrastructure --backup --bell --dns

REQUIREMENTS:
  • Valid Terragrunt configuration
  • Appropriate AWS credentials
  • Target environment must exist

POST-QUERY:
  • Outputs are automatically generated
  • Volume configurations are preserved
  • DNS records updated if --dns flag used

EOF
            ;;
        *)
            echo "No detailed help available for action: $action"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export  
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Args module loaded successfully"

