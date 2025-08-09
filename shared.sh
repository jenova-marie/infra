#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Shared Utilities
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Centralized utilities for parsing, formatting, validation, and messaging
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Global Variables and Constants
# ─────────────────────────────────────────────────────────────────────────────

# Color codes for output formatting
declare -r RED='\033[0;31m'
declare -r BRIGHT_RED='\033[1;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r GRAY='\033[0;90m'
declare -r NEON_PINK='\033[1;95m'
declare -r LIGHT_PINK_BLUE='\033[0;96m'
declare -r NC='\033[0m' # No Color

# System constants
declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Use LIVE_HOME environment variable if set, otherwise fallback to PROJECT_ROOT/src/live
declare -r LIVE_ROOT="${LIVE_HOME:-$PROJECT_ROOT/src/live}"

# Global state variables (set by other modules)
VERBOSE_LEVEL=0
NO_COLOR=false
DRY_RUN=false
CURRENT_ENV=""
DEBUG_LOG_FILE=""
HUMAN_LOG_FILE=""

# ─────────────────────────────────────────────────────────────────────────────
# Array Helper Functions - DRY KISS Empty Array Handling
# ─────────────────────────────────────────────────────────────────────────────

# Safely iterate over array elements (handles empty arrays properly)
# Usage: safe_array_elements "ARRAY_NAME" -> outputs each element on new line
safe_array_elements() {
    local array_name="$1"
    
    # Use eval to access the array safely
    eval "printf '%s\n' \"\${${array_name}[@]:-}\""
}

# Safely get array elements for for-loops (handles empty arrays properly) 
# Usage: for item in $(safe_array_iterate "ARRAY_NAME"); do ... done
safe_array_iterate() {
    local array_name="$1"
    
    # Use eval to access the array safely
    eval "printf '%s\n' \"\${${array_name}[@]:-}\""
}

# Safely get array length (handles empty arrays properly)
# Usage: safe_array_length "ARRAY_NAME" -> returns length as integer
safe_array_length() {
    local array_name="$1"
    
    # Use eval to get array length safely
    eval "echo \"\${#${array_name}[@]}\""
}

# Safely get array elements as space-separated string (handles empty arrays properly)
# Usage: safe_array_string "ARRAY_NAME" -> returns elements separated by spaces
safe_array_string() {
    local array_name="$1"
    local result
    
    # Use eval to access the array safely as string
    result=$(eval "printf '%s' \"\${${array_name}[*]:-}\"")
    
    # Return "none" if empty, otherwise return the string
    if [[ -z "$result" ]]; then
        echo "none"
    else
        echo "$result"
    fi
}

# Check if array has elements (handles empty arrays properly)
# Usage: safe_array_has_elements "ARRAY_NAME" -> returns 0 if has elements, 1 if empty
safe_array_has_elements() {
    local array_name="$1"
    local length
    
    length=$(safe_array_length "$array_name")
    [[ $length -gt 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# KISS Helper Functions - Operation Context 💖
# ─────────────────────────────────────────────────────────────────────────────

# Get all operation context variables in one call (KISS approach)
# Usage: get_operation_context -> sets OP_ACTION, OP_ENV, OP_TARGET_TYPE, OP_ENV_PATH
get_operation_context() {
    debug_message "Gathering operation context variables"
    
    # Check if getter functions are available
    if ! declare -f get_action >/dev/null 2>&1; then
        handle_error "get_action function not available - args module not loaded"
    fi
    
    OP_ACTION=$(get_action)
    OP_ENV=$(get_environment)
    OP_TARGET_TYPE=$(get_target_type)
    OP_ENV_PATH="$(get_environment_path "$OP_ENV")"
    
    debug_message "Operation context: action=$OP_ACTION, env=$OP_ENV, target=$OP_TARGET_TYPE"
    debug_message "Environment path: $OP_ENV_PATH"
    
    # Export for use in subprocesses
    export OP_ACTION OP_ENV OP_TARGET_TYPE OP_ENV_PATH
}

# Check if we're in dry-run mode (standardized check)
# Usage: is_dry_run
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Execute command with consistent dry-run handling
# Usage: execute_with_dry_run "rm -f file.txt" "Would delete file.txt"
execute_with_dry_run() {
    local command="$1"
    local dry_run_message_text="$2"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] $dry_run_message_text"
        return 0
    else
        debug_message "Executing: $command"
        eval "$command"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# KISS Helper Functions - File Operations 💖  
# ─────────────────────────────────────────────────────────────────────────────

# Check if file exists and is not empty (common pattern)
# Usage: file_exists_and_readable "/path/to/file"
file_exists_and_readable() {
    local file_path="$1"
    [[ -f "$file_path" && -r "$file_path" ]]
}

# Check if file exists and has content (common pattern)  
# Usage: file_exists_and_has_content "/path/to/file"
file_exists_and_has_content() {
    local file_path="$1"
    [[ -f "$file_path" && -s "$file_path" ]]
}

# Get standardized output file path for module
# Usage: get_module_output_path "dev" "athena" -> /path/to/dev/outputs/athena.json
get_module_output_path() {
    local env="$1"
    local module="$2"
    local env_path="$(get_environment_path "$env")"
    echo "$env_path/outputs/$module.json"
}

# Get standardized module directory path  
# Usage: get_module_path "dev" "athena" -> /path/to/dev/athena
get_module_path() {
    local env="$1"
    local module="$2"
    local env_path="$(get_environment_path "$env")"
    echo "$env_path/$module"
}

# Ensure output directory exists for environment
# Usage: ensure_output_directory "dev"
ensure_output_directory() {
    local env="$1"
    local env_path="$(get_environment_path "$env")"
    local output_dir="$env_path/outputs"
    ensure_directory "$output_dir"
}

# ─────────────────────────────────────────────────────────────────────────────
# KISS Helper Functions - Logging Integration 💖
# ─────────────────────────────────────────────────────────────────────────────

# Check if logging system is available and active
# Usage: is_logging_active
is_logging_active() {
    [[ "${LOGGING_INITIALIZED:-false}" == "true" && -n "${DEBUG_LOG_FILE:-}" ]]
}

# Get terragrunt log file path (if logging is active)
# Usage: get_terragrunt_log_file
get_terragrunt_log_file() {
    if is_logging_active; then
        echo "${TERRAGRUNT_LOG_FILE:-}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# KISS Helper Functions - Post-Operation Actions 💖
# ─────────────────────────────────────────────────────────────────────────────

# Execute all post-operation cleanup/notification actions in one call
# Usage: execute_post_operation_actions "Terragrunt apply completed successfully"
execute_post_operation_actions() {
    local message="$1"
    
    debug_message "Executing post-operation actions: $message"
    
    # Ring completion bell if enabled
    ring_completion_bell "$message"
    
    # Update DNS records if enabled  
    update_dns_records "$message"
    
    # Clean SSH known_hosts entries if enabled
    cleanup_known_hosts "$message"
    
    debug_message "Post-operation actions completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Core Messaging Functions
# ─────────────────────────────────────────────────────────────────────────────

# Print formatted message with optional color and logging
# Usage: print_message "message" [color] [log_level]
print_message() {
    local message="$1"
    local color="${2:-}"
    local log_level="${3:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format message for display
    local display_message="$message"
    if [[ "$NO_COLOR" != true && -n "$color" ]]; then
        display_message="${color}${message}${NC}"
    fi
    
    # Print to stdout
    echo -e "$display_message"
    
    # Log to files if available (ensure directories exist)
    if [[ -n "$DEBUG_LOG_FILE" ]]; then
        # Ensure log directory exists before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        echo "[$timestamp] [$log_level] $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    fi
    
    if [[ -n "$HUMAN_LOG_FILE" ]]; then
        # Ensure log directory exists before writing
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        echo "[$timestamp] $message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    fi
}

# Print debug message (only shown in verbose mode)
# Usage: debug_message "debug info"
debug_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Always log to debug file (ensure directory exists)
    if [[ -n "$DEBUG_LOG_FILE" ]]; then
        # Ensure log directory exists before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        echo "[$timestamp] [DEBUG] $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    fi
    
    # Only print to stderr if verbose mode is enabled
    if [[ "$VERBOSE_LEVEL" -ge 1 ]]; then
        local display_message="🔍 DEBUG: $message"
        if [[ "$NO_COLOR" != true ]]; then
            display_message="${PURPLE}🔍 DEBUG: $message${NC}"
        fi
        echo -e "$display_message" >&2
    fi
}

# Print error message and optionally exit
# Usage: handle_error "error message" [exit_code]
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format error message
    local error_msg="❌ ERROR: $message"
    if [[ "$NO_COLOR" != true ]]; then
        error_msg="${RED}❌ ERROR: $message${NC}"
    fi
    
    # Print to stderr
    echo -e "$error_msg" >&2
    
    # Log to files (ensure directories exist)
    if [[ -n "$DEBUG_LOG_FILE" ]]; then
        # Ensure log directory exists before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        echo "[$timestamp] [ERROR] $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    fi
    
    if [[ -n "$HUMAN_LOG_FILE" ]]; then
        # Ensure log directory exists before writing
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        echo "[$timestamp] ERROR: $message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    fi
    
    # Check if test mode is enabled (from args module)
    if declare -f is_test_mode >/dev/null 2>&1 && is_test_mode; then
        debug_message "Test mode: returning error code $exit_code instead of exiting"
        return "$exit_code"
    fi
    
    # Exit if exit code provided (production behavior)
    if [[ "$exit_code" -gt 0 ]]; then
        exit "$exit_code"
    fi
}

# Print warning message
# Usage: warn_message "warning message"
warn_message() {
    local message="$1"
    print_message "⚠️  WARNING: $message" "$YELLOW" "WARN"
}

# Print success message
# Usage: success_message "success message"
success_message() {
    local message="$1"
    print_message "✅ $message" "$GREEN" "SUCCESS"
}

# Print info message
# Usage: info_message "info message"
info_message() {
    local message="$1"
    print_message "ℹ️  $message" "$BLUE" "INFO"
}

# Print dry-run message (always yellow, never red)
# Usage: dry_run_message "dry-run info"
dry_run_message() {
    local message="$1"
    print_message "🟡 $message" "$YELLOW" "DRY-RUN"
}

# ─────────────────────────────────────────────────────────────────────────────
# Target Parsing Functions
# ─────────────────────────────────────────────────────────────────────────────

# Parse target string into environment and target components
# Usage: parse_target "dev:infrastructure" -> sets PARSED_ENV and PARSED_TARGET
# Usage: parse_target "dev" -> sets PARSED_ENV="dev" and PARSED_TARGET="all"
parse_target() {
    local target_string="$1"
    
    debug_message "Parsing target string: $target_string"
    
    if [[ "$target_string" =~ ^([^:]+):(.+)$ ]]; then
        # Full format: env:target
        PARSED_ENV="${BASH_REMATCH[1]}"
        PARSED_TARGET="${BASH_REMATCH[2]}"
        debug_message "Parsed environment: $PARSED_ENV, target: $PARSED_TARGET"
    elif [[ "$target_string" =~ ^[^:]+$ ]]; then
        # Shorthand format: env (implies :all)
        PARSED_ENV="$target_string"
        PARSED_TARGET="all"
        debug_message "Parsed shorthand - environment: $PARSED_ENV, target: $PARSED_TARGET (implied)"
    else
        handle_error "Invalid target format: $target_string. Expected format: env:target or env"
        return 1
    fi
}

# Validate environment exists
# Usage: validate_environment "dev"
validate_environment() {
    local env="$1"
    local env_path="$LIVE_ROOT/$env"
    
    debug_message "Validating environment: $env at path: $env_path"
    
    if [[ ! -d "$env_path" ]]; then
        handle_error "Environment directory not found: $env_path"
        return 1
    fi
    
    if [[ ! -f "$env_path/modules.yml" ]]; then
        handle_error "Modules file not found: $env_path/modules.yml"
        return 1
    fi
    
    debug_message "Environment validation successful: $env"
    return 0
}

# Get absolute path for environment
# Usage: get_environment_path "dev"
get_environment_path() {
    local env="$1"
    echo "$LIVE_ROOT/$env"
}

# ─────────────────────────────────────────────────────────────────────────────
# File and Directory Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Ensure directory exists, create if needed
# Usage: ensure_directory "/path/to/dir"
ensure_directory() {
    local dir_path="$1"
    
    debug_message "Ensuring directory exists: $dir_path"
    
    if [[ ! -d "$dir_path" ]]; then
        execute_with_dry_run "mkdir -p '$dir_path'" "Would create directory: $dir_path"
        if [[ ! is_dry_run ]]; then
            debug_message "Created directory: $dir_path"
        fi
    else
        debug_message "Directory already exists: $dir_path"
    fi
}

# Check if file exists and is readable
# Usage: validate_file "/path/to/file"
validate_file() {
    local file_path="$1"
    
    debug_message "Validating file: $file_path"
    
    if [[ ! -f "$file_path" ]]; then
        debug_message "File not found: $file_path"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        debug_message "File not readable: $file_path"
        return 1
    fi
    
    debug_message "File validation successful: $file_path"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Command Validation Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Check if command exists
# Usage: command_exists "terragrunt"
command_exists() {
    local cmd="$1"
    debug_message "Checking if command exists: $cmd"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        debug_message "Command found: $cmd"
        return 0
    else
        debug_message "Command not found: $cmd"
        return 1
    fi
}

# Validate required commands are available
# Usage: validate_required_commands
validate_required_commands() {
    local required_commands=("terragrunt" "yq" "jq")
    local missing_commands=()
    
    debug_message "Validating required commands: ${required_commands[*]}"
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        handle_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    debug_message "All required commands are available"
}

# ─────────────────────────────────────────────────────────────────────────────
# Action Validation Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Check if action modifies state
# Usage: action_modifies_state "apply"
action_modifies_state() {
    local action="$1"
    local state_modifying_actions=("apply" "destroy" "volume" "shutdown")
    
    debug_message "Checking if action modifies state: $action"
    
    for modifying_action in "${state_modifying_actions[@]}"; do
        if [[ "$action" == "$modifying_action" ]]; then
            debug_message "Action modifies state: $action"
            return 0
        fi
    done
    
    debug_message "Action does not modify state: $action"
    return 1
}

# Validate that action is supported
# Usage: validate_action "apply"
validate_action() {
    local action="$1"
    
    debug_message "Validating action: $action"
    
    case "$action" in
        "apply"|"destroy"|"plan"|"init"|"output"|"clean"|"volume"|"shutdown"|"verify"|"status"|"reboot"|"query"|"diag")
            debug_message "Action validation successful: $action"
            return 0
            ;;
        *)
            handle_error "Invalid action: $action. Supported actions: apply, destroy, plan, init, output, clean, volume, shutdown, verify, status, reboot, query, diag"
            return 1
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Initialization and Setup
# ─────────────────────────────────────────────────────────────────────────────

# Initialize shared utilities
# Usage: init_shared_utilities
init_shared_utilities() {
    debug_message "Initializing shared utilities"
    
    # Validate required commands
    validate_required_commands
    
    debug_message "Shared utilities initialized successfully"
}

# Set global variables from other modules
# Usage: set_global_vars verbose_level no_color dry_run current_env debug_log human_log
set_global_vars() {
    VERBOSE_LEVEL="$1"
    NO_COLOR="$2"
    DRY_RUN="$3"
    CURRENT_ENV="$4"
    DEBUG_LOG_FILE="$5"
    HUMAN_LOG_FILE="$6"
    
    # Export DRY_RUN as environment variable for all subprocesses and functions
    export DRY_RUN
    
    debug_message "Global variables set - Verbose: $VERBOSE_LEVEL, No Color: $NO_COLOR, Dry Run: $DRY_RUN"
    debug_message "Current Environment: $CURRENT_ENV"
    debug_message "Debug Log: $DEBUG_LOG_FILE"
    debug_message "Human Log: $HUMAN_LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Terragrunt Execution Functions
# ─────────────────────────────────────────────────────────────────────────────

# Execute terragrunt command with centralized flag handling and intelligent target selection
# Usage: execute_terragrunt "apply" "command_args" "target_type"
execute_terragrunt() {
    local action="$1"
    local command_args="$2"
    local target_type="${3:-}"  # Optional third parameter for target type
    
    debug_message "Terragrunt execution requested: action=$action, args=$command_args, target_type=$target_type"
    
    # Store current directory for restoration (no longer needed but kept for compatibility)
    local original_dir=$(pwd)
    
    # Single execution strategy: Always use --all with exclusions as needed
    local full_command="terragrunt $action --all"
    debug_message "Strategy: unified --all approach with exclusions"
    
    # Add action-specific flags (simplified - no performance optimizations)
    case "$action" in
        "apply"|"destroy")
            # State-modifying operations get auto-approve only
            full_command+=" --auto-approve"
            debug_message "Added auto-approve for state-modifying action: $action"
            ;;
        "plan"|"init"|"output")
            # Read-only operations - no auto-approve needed
            debug_message "No auto-approve flags for read-only action: $action"
            ;;
    esac
    
    # Always add provider cache flag for performance optimization
    full_command+=" --provider-cache"
    debug_message "Added provider-cache flag for performance optimization"
    
    # Always add non-interactive flag to prevent prompts
    full_command+=" --non-interactive"
    
    # Add color handling
    if [[ "$NO_COLOR" == true ]]; then
        full_command+=" --no-color"
        debug_message "Added no-color flag"
    fi
    
    # CRITICAL FIX: Set endpoint flag environment variables when endpoints module is included
    # Check if endpoints module will be processed by this operation
    local endpoints_included=false
    
    # Determine if endpoints module is included based on target type
    case "$target_type" in
        "endpoints")
            # Direct endpoints targeting
            endpoints_included=true
            debug_message "Endpoints module targeted directly"
            ;;
        "all"|"infrastructure")
            # Check if endpoints is part of infrastructure group and not excluded
            if is_modules_loaded; then
                # Check if endpoints is in infrastructure modules
                local infrastructure_modules=()
                while IFS= read -r module; do
                    [[ -n "$module" ]] && infrastructure_modules+=("$module")
                done < <(get_infrastructure_modules)
                
                # Check if endpoints is in the infrastructure list
                for module in "${infrastructure_modules[@]}"; do
                    if [[ "$module" == "endpoints" ]]; then
                        endpoints_included=true
                        debug_message "Endpoints module found in infrastructure group"
                        break
                    fi
                done
            fi
            ;;
        *)
            # Single module targeting - not endpoints
            debug_message "Single module targeting - endpoints not included"
            ;;
    esac
    
    # Set endpoint flag environment variables if endpoints module is included
    if [[ "$endpoints_included" == true ]]; then
        debug_message "Setting endpoint flag environment variables for endpoints module"
        
        # Set environment variables that terragrunt can access
        if is_ssm; then
            export TG_VAR_ssm=true
            debug_message "Set environment variable: TG_VAR_ssm=true"
        else
            export TG_VAR_ssm=false
            debug_message "Set environment variable: TG_VAR_ssm=false"
        fi
        if is_ecr; then
            export TG_VAR_ecr=true
            debug_message "Set environment variable: TG_VAR_ecr=true"
        else
            export TG_VAR_ecr=false
            debug_message "Set environment variable: TG_VAR_ecr=false"
        fi
    else
        debug_message "Endpoints module not included - skipping endpoint flag environment variables"
    fi
    
    # Append exclusion flags if provided
    if [[ -n "$command_args" ]]; then
        # Convert our custom format to proper terragrunt flags
        if [[ "$command_args" == *"--queue-exclude-dir="* ]]; then
            # Extract the excluded directories
            local exclude_args="${command_args}"
            exclude_args="${exclude_args#*--queue-exclude-dir=}"  # Get the excluded dirs
            
            # Convert comma-separated list to individual --queue-exclude-dir flags  
            IFS=',' read -ra EXCLUDED_DIRS <<< "$exclude_args"
            for dir in "${EXCLUDED_DIRS[@]}"; do
                [[ -n "$dir" ]] && full_command+=" --queue-exclude-dir $dir"
            done
            debug_message "Added exclusion flags: ${exclude_args}"
        else
            # For other args, add as-is
            full_command+=" $command_args"
            debug_message "Added command args: $command_args"
        fi
    fi
    
    debug_message "Final terragrunt command: $full_command"
    
    # Check if we're in dry-run mode (using standardized function)
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would execute: $full_command"
        return 0  # Always succeed in dry-run mode
    fi
    
    # Execute with logging if available (simplified)
    local exit_code=0
    if is_logging_active; then
        debug_message "Executing with logging: $full_command"
        $full_command 2>&1 | filter_terragrunt_output | tee -a "$(get_terragrunt_log_file)"
        exit_code=${PIPESTATUS[0]}
    else
        debug_message "Executing without logging: $full_command"
        $full_command 2>&1 | filter_terragrunt_output
        exit_code=${PIPESTATUS[0]}
    fi
    
    # No directory changes needed - terragrunt handles working directory
    debug_message "Terragrunt execution completed"
    
    return $exit_code
}

# ─────────────────────────────────────────────────────────────────────────────
# Terminal Bell Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Ring terminal bell if bell mode is enabled
# Usage: ring_completion_bell [message]
ring_completion_bell() {
    local message="${1:-}"
    
    # Check if bell function is available from args module
    if declare -f is_bell >/dev/null 2>&1 && is_bell; then
        debug_message "Ringing terminal bell for operation completion"
        
        # Ring the bell (ASCII 7 - BEL character)
        printf '\a'
        
        # Optional message with bell indicator
        if [[ -n "$message" ]]; then
            info_message "🔔 $message"
        else
            debug_message "Terminal bell rung for completion notification"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# DNS Update Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Update DNS records if DNS mode is enabled
# Usage: update_dns_records [message]
update_dns_records() {
    local message="${1:-}"
    
    # Check if DNS function is available from args module
    if declare -f is_dns >/dev/null 2>&1 && is_dns; then
        debug_message "Starting DNS update operation"
        
        # Show DNS update message with icon
        if [[ -n "$message" ]]; then
            info_message "🌐 $message - updating DNS records..."
        else
            info_message "🌐 Updating DNS records after operation completion..."
        fi
        
        # Check if we're in dry-run mode (using standardized function)
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would execute: infra apply global:dns"
            return 0
        fi
        
        # Store current directory
        local original_dir="$(pwd)"
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        # Execute DNS update by calling the main infra script recursively
        debug_message "Executing DNS update: $script_dir/infra apply global:dns"
        
        # Temporarily disable DNS flag to prevent infinite recursion
        local original_dns="$DNS"
        DNS=false
        
        # Execute the DNS update
        local dns_exit_code=0
        if "$script_dir/infra" apply global:dns --no-color; then
            success_message "🌐 DNS records updated successfully"
        else
            dns_exit_code=$?
            warn_message "🌐 DNS update failed with exit code: $dns_exit_code"
        fi
        
        # Restore original DNS flag
        DNS="$original_dns"
        
        # Return to original directory
        cd "$original_dir"
        
        return $dns_exit_code
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SSH Known Hosts Cleanup Utilities
# ─────────────────────────────────────────────────────────────────────────────

# Clean SSH known_hosts entries for applied instances
# Usage: cleanup_known_hosts [message]
cleanup_known_hosts() {
    local message="${1:-}"
    
    # Check if known_hosts cleanup function is available from args module
    if declare -f is_known_hosts_cleanup >/dev/null 2>&1 && is_known_hosts_cleanup; then
        debug_message "Starting SSH known_hosts cleanup operation"
        
        # Show cleanup message with icon
        if [[ -n "$message" ]]; then
            info_message "🧹 $message - cleaning SSH known_hosts entries..."
        else
            info_message "🧹 Cleaning SSH known_hosts entries for applied instances..."
        fi
        
        # Get environment and target information from operation context
        local env="${OP_ENV:-}"
        local target_type="${OP_TARGET_TYPE:-}"
        
        if [[ -z "$env" ]]; then
            debug_message "No environment specified, skipping known_hosts cleanup"
            return 0
        fi
        
        # Check if we're in dry-run mode (using standardized function)
        if is_dry_run; then
            # In dry-run mode, still determine which instances would be cleaned and show details
            local instances_to_clean=()
            
            case "$target_type" in
                "all"|"instances")
                    # Get all instance modules from the environment
                    instances_to_clean=($(get_instance_modules_for_cleanup "$env"))
                    ;;
                "infrastructure")
                    # Infrastructure changes don't affect instances directly
                    debug_message "Infrastructure target, skipping known_hosts cleanup"
                    return 0
                    ;;
                *)
                    # Check if target is a single instance module
                    if is_instance_module "$target_type"; then
                        instances_to_clean=("$target_type")
                    else
                        debug_message "Target '$target_type' is not an instance module, skipping known_hosts cleanup"
                        return 0
                    fi
                    ;;
            esac
            
            if [[ ${#instances_to_clean[@]} -eq 0 ]]; then
                debug_message "No instances to clean, skipping known_hosts cleanup"
                return 0
            fi
            
            # Show what would be cleaned in dry-run mode
            dry_run_message "[DRY-RUN] Would clean SSH known_hosts entries for ${#instances_to_clean[@]} instance(s): ${instances_to_clean[*]}"
            
            # Show details for each instance
            for instance in "${instances_to_clean[@]}"; do
                dry_run_message "[DRY-RUN] Would clean known_hosts for $instance:"
                
                # Generate what would be cleaned (same logic as real cleanup but just show it)
                local env_path="$(get_environment_path "$env")"
                local output_file="$env_path/outputs/$instance.json"
                
                if [[ -f "$output_file" ]]; then
                    # Extract potential IPs and hostnames to show what would be cleaned
                    local ips_and_hosts=()
                    
                    # Get public IP
                    local public_ip=$(jq -r '.public_ips.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
                    if [[ -n "$public_ip" && "$public_ip" != "null" ]]; then
                        ips_and_hosts+=("$public_ip (public IP)")
                    fi
                    
                    # Get EIP address
                    local eip_address=$(jq -r '.eip_addresses.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
                    if [[ -n "$eip_address" && "$eip_address" != "null" && "$eip_address" != "$public_ip" ]]; then
                        ips_and_hosts+=("$eip_address (EIP)")
                    fi
                    
                    # Get private IP
                    local private_ip=$(jq -r '.private_ips.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
                    if [[ -n "$private_ip" && "$private_ip" != "null" ]]; then
                        ips_and_hosts+=("$private_ip (private IP)")
                    fi
                    
                    # Add potential FQDNs
                    ips_and_hosts+=(
                        "$instance.cmd"
                        "$instance.dev"
                        "$instance.prod"
                        "$instance.recoverysky.dev"
                        "$instance-$env.recoverysky.dev"
                        "$instance.$env.recoverysky.dev"
                    )
                    
                    # Show what would be cleaned
                    for host_or_ip in "${ips_and_hosts[@]}"; do
                        dry_run_message "[DRY-RUN]   - $host_or_ip"
                    done
                else
                    dry_run_message "[DRY-RUN]   - No output file found: $output_file"
                fi
            done
            
            return 0
        fi
        
        # Determine which instances to clean based on target type
        local instances_to_clean=()
        
        case "$target_type" in
            "all"|"instances")
                # Get all instance modules from the environment
                instances_to_clean=($(get_instance_modules_for_cleanup "$env"))
                ;;
            "infrastructure")
                # Infrastructure changes don't affect instances directly
                debug_message "Infrastructure target, skipping known_hosts cleanup"
                return 0
                ;;
            *)
                # Check if target is a single instance module
                if is_instance_module "$target_type"; then
                    instances_to_clean=("$target_type")
                else
                    debug_message "Target '$target_type' is not an instance module, skipping known_hosts cleanup"
                    return 0
                fi
                ;;
        esac
        
        if [[ ${#instances_to_clean[@]} -eq 0 ]]; then
            debug_message "No instances to clean, skipping known_hosts cleanup"
            return 0
        fi
        
        # Clean known_hosts entries for each instance
        local cleanup_count=0
        for instance in "${instances_to_clean[@]}"; do
            if cleanup_instance_known_hosts "$env" "$instance"; then
                ((cleanup_count++))
            fi
        done
        
        if [[ $cleanup_count -gt 0 ]]; then
            success_message "🧹 Cleaned SSH known_hosts entries for $cleanup_count instance(s)"
        else
            debug_message "No SSH known_hosts entries needed cleaning"
        fi
        
        return 0
    fi
}

# Get list of instance modules for cleanup
# Usage: get_instance_modules_for_cleanup "dev"
get_instance_modules_for_cleanup() {
    local env="$1"
    local env_path="$(get_environment_path "$env")"
    
    # Look for instance modules by checking for output files
    local instances=()
    local outputs_dir="$env_path/outputs"
    
    if [[ -d "$outputs_dir" ]]; then
        # Find instance output files (exclude infrastructure modules)
        for output_file in "$outputs_dir"/*.json; do
            if [[ -f "$output_file" ]]; then
                local module_name=$(basename "$output_file" .json)
                # Check if this is an instance module (has instance_ids output)
                if jq -e '.instance_ids' "$output_file" >/dev/null 2>&1; then
                    instances+=("$module_name")
                fi
            fi
        done
    fi
    
    # Only print array elements if array has content (KISS fix for unbound variable)
    if [[ ${#instances[@]} -gt 0 ]]; then
        printf '%s\n' "${instances[@]}"
    fi
}

# Check if a module is an instance module
# Usage: is_instance_module "athena"
is_instance_module() {
    local module="$1"
    local env="${OP_ENV:-}"
    
    if [[ -z "$env" ]]; then
        return 1
    fi
    
    local env_path="$(get_environment_path "$env")"
    local output_file="$env_path/outputs/$module.json"
    
    # Check if the module has instance_ids output (indicates it's an instance module)
    if [[ -f "$output_file" ]] && jq -e '.instance_ids' "$output_file" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Clean known_hosts entries for a specific instance
# Usage: cleanup_instance_known_hosts "dev" "athena"
cleanup_instance_known_hosts() {
    local env="$1"
    local instance="$2"
    local env_path="$(get_environment_path "$env")"
    local output_file="$env_path/outputs/$instance.json"
    
    debug_message "Cleaning known_hosts entries for instance: $instance"
    
    # Check if output file exists
    if [[ ! -f "$output_file" ]]; then
        debug_message "Output file not found for instance $instance: $output_file"
        return 1
    fi
    
    # Check if known_hosts file exists
    local known_hosts_file="$HOME/.ssh/known_hosts"
    if [[ ! -f "$known_hosts_file" ]]; then
        debug_message "SSH known_hosts file not found: $known_hosts_file"
        return 0
    fi
    
    # Extract IP addresses and FQDNs for this instance
    local ips_and_hosts=()
    
    # Get public IP (EIP or regular public IP)
    local public_ip=$(jq -r '.public_ips.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
    if [[ -n "$public_ip" && "$public_ip" != "null" ]]; then
        ips_and_hosts+=("$public_ip")
        debug_message "Found public IP for $instance: $public_ip"
    fi
    
    # Get EIP address (might be same as public IP)
    local eip_address=$(jq -r '.eip_addresses.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
    if [[ -n "$eip_address" && "$eip_address" != "null" && "$eip_address" != "$public_ip" ]]; then
        ips_and_hosts+=("$eip_address")
        debug_message "Found EIP address for $instance: $eip_address"
    fi
    
    # Get private IP
    local private_ip=$(jq -r '.private_ips.value.'"$instance"' // empty' "$output_file" 2>/dev/null)
    if [[ -n "$private_ip" && "$private_ip" != "null" ]]; then
        ips_and_hosts+=("$private_ip")
        debug_message "Found private IP for $instance: $private_ip"
    fi
    
    # Generate potential FQDNs based on instance name and environment
    local potential_fqdns=(
        "$instance.recoverysky.dev"
        "$instance-$env.recoverysky.dev"
        "$instance.$env.recoverysky.dev"
    )
    
    # Add FQDNs to cleanup list
    for fqdn in "${potential_fqdns[@]}"; do
        ips_and_hosts+=("$fqdn")
        debug_message "Will check FQDN for $instance: $fqdn"
    done
    
    if [[ ${#ips_and_hosts[@]} -eq 0 ]]; then
        debug_message "No IPs or hostnames found for instance $instance"
        return 0
    fi
    
    # Remove entries from known_hosts
    local removed_count=0
    for host_or_ip in "${ips_and_hosts[@]}"; do
        if ssh-keygen -R "$host_or_ip" >/dev/null 2>&1; then
            debug_message "Removed known_hosts entry for: $host_or_ip"
            ((removed_count++))
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        debug_message "Removed $removed_count known_hosts entries for instance $instance"
        return 0
    else
        debug_message "No known_hosts entries found to remove for instance $instance"
        return 0
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Volume Management Functions 💖
# ─────────────────────────────────────────────────────────────────────────────

# Enhanced instance module check that doesn't rely on global ENVIRONMENT variable
# Usage: is_instance_module_enhanced "dev" "athena"
is_instance_module_enhanced() {
    local env="$1"
    local module="$2"
    
    debug_message "Checking if module is an instance module: $module"
    
    # Check if modules system is available
    if ! declare -f get_module_type >/dev/null 2>&1; then
        # Fallback: check output file for instance_ids (indicates instance module)
        local env_path="$(get_environment_path "$env")"
        local output_file="$env_path/outputs/$module.json"
        
        if [[ -f "$output_file" ]] && jq -e '.instance_ids' "$output_file" >/dev/null 2>&1; then
            debug_message "Module $module appears to be an instance module (has instance_ids output)"
            return 0
        else
            debug_message "Module $module does not appear to be an instance module (no instance_ids output)"
            return 1
        fi
    fi
    
    # Use modules system if available
    if ! is_modules_loaded; then
        debug_message "Modules not loaded - using fallback method"
        # Fallback method
        local env_path="$(get_environment_path "$env")"
        local output_file="$env_path/outputs/$module.json"
        
        if [[ -f "$output_file" ]] && jq -e '.instance_ids' "$output_file" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
    
    # Use modules system
    local module_type=$(get_module_type "$module" 2>/dev/null || echo "unknown")
    if [[ "$module_type" == "instance" ]]; then
        debug_message "Module $module is confirmed as instance module via modules system"
        return 0
    else
        debug_message "Module $module is not an instance module (type: $module_type)"
        return 1
    fi
}

# Empty volumes.yml files for target instances when --no-volumes flag is used
# Usage: empty_volumes_files "dev" "instances"
empty_volumes_files() {
    local env="$1"
    local target_type="$2"
    
    debug_message "Emptying volumes.yml files for target: $target_type"
    
    # Get modules to process
    local modules_to_process=()
    
    # Check if modules system is available and loaded
    if ! declare -f get_modules_for_target >/dev/null 2>&1; then
        warn_message "get_modules_for_target function not available - using fallback approach"
        # Fallback: directly process the target if it's a single module
        if [[ "$target_type" != "all" && "$target_type" != "instances" ]]; then
            if is_instance_module_enhanced "$env" "$target_type"; then
                modules_to_process=("$target_type")
            else
                debug_message "Target '$target_type' is not an instance module - no volumes.yml to empty"
                return 0
            fi
        else
            warn_message "Cannot process 'all' or 'instances' without modules system - skipping"
            return 0
        fi
    elif ! declare -f is_modules_loaded >/dev/null 2>&1 || ! is_modules_loaded; then
        warn_message "Modules not loaded - using fallback approach"
        # Fallback: directly process the target if it's a single module
        if [[ "$target_type" != "all" && "$target_type" != "instances" ]]; then
            if is_instance_module_enhanced "$env" "$target_type"; then
                modules_to_process=("$target_type")
            else
                debug_message "Target '$target_type' is not an instance module - no volumes.yml to empty"
                return 0
            fi
        else
            warn_message "Cannot process 'all' or 'instances' without modules system - skipping"
            return 0
        fi
    else
        # Normal modules system processing
        case "$target_type" in
            "all"|"instances")
                # Get all instance modules using modules system
                while IFS= read -r module; do
                    if [[ -n "$module" ]]; then
                        modules_to_process+=("$module")
                    fi
                done < <(get_modules_for_target "instances")
                ;;
            *)
                # Single module - check if it's an instance module
                if is_instance_module_enhanced "$env" "$target_type"; then
                    modules_to_process=("$target_type")
                else
                    debug_message "Target '$target_type' is not an instance module - no volumes.yml to empty"
                    return 0
                fi
                ;;
        esac
    fi
    
    if [[ ${#modules_to_process[@]} -eq 0 ]]; then
        debug_message "No instance modules found for volumes.yml cleanup"
        return 0
    fi
    
    local env_path="$(get_environment_path "$env")"
    local processed_count=0
    local error_count=0
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would empty volumes.yml files for ${#modules_to_process[@]} instance(s): ${modules_to_process[*]}"
        for module in "${modules_to_process[@]}"; do
            local volumes_file="$env_path/$module/volumes.yml"
            if [[ -f "$volumes_file" ]]; then
                dry_run_message "[DRY-RUN] Would empty: $volumes_file"
            else
                dry_run_message "[DRY-RUN] Would create empty: $volumes_file"
            fi
        done
        return 0
    fi
    
    info_message "🗑️  Emptying volumes.yml files for ${#modules_to_process[@]} instance(s) (--no-volumes mode)"
    
    # Process each instance module
    for module in "${modules_to_process[@]}"; do
        local volumes_file="$env_path/$module/volumes.yml"
        local backup_file=""
        
        debug_message "Processing volumes.yml for module: $module"
        
        # Create backup if file exists and has content
        if [[ -f "$volumes_file" && -s "$volumes_file" ]]; then
            # Check if backup function is available and enabled
            if declare -f is_backup >/dev/null 2>&1 && is_backup; then
                backup_file="${volumes_file}.backup-$(date +%Y%m%d-%H%M%S)"
                if cp "$volumes_file" "$backup_file"; then
                    debug_message "Created backup: $backup_file"
                else
                    warn_message "Failed to create backup for $volumes_file - continuing anyway"
                fi
            else
                debug_message "Backup mode disabled or not available - not creating backup for $volumes_file"
            fi
        fi
        
        # Empty the volumes.yml file (create as empty string, not empty YAML object)
        if : > "$volumes_file"; then
            ((processed_count++))
            success_message "✅ Emptied volumes.yml for $module"
            
            if [[ -n "$backup_file" ]]; then
                info_message "   Backup saved: $backup_file"
            fi
        else
            ((error_count++))
            warn_message "❌ Failed to empty volumes.yml for $module"
            
            # Restore backup on failure if it exists
            if [[ -n "$backup_file" && -f "$backup_file" ]]; then
                cp "$backup_file" "$volumes_file" || true
                warn_message "Restored backup due to write failure"
            fi
        fi
    done
    
    # Summary
    info_message "✅ Volumes cleanup summary:"
    info_message "   Processed: $processed_count/${#modules_to_process[@]} modules"
    
    if [[ $error_count -gt 0 ]]; then
        warn_message "   Errors: $error_count modules failed"
        return 1
    else
        success_message "🎯 All volumes.yml files successfully emptied"
        return 0
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Beautiful Terragrunt Output Filtering 💖✨
# ─────────────────────────────────────────────────────────────────────────────

# Filter terragrunt output to make it beautiful with neon pink infra: labels
# Usage: filter_terragrunt_output
filter_terragrunt_output() {
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "${NO_COLOR:-false}" != "true" ]]; then
            # Simple replacement for terragrunt log lines with neon pink infra: and light pink-blue text
            if echo "$line" | grep -q "STDOUT tofu:"; then
                # Replace tofu: with colored infra: and make the message light pink-blue
                # We need to use printf to properly handle the color codes
                local prefix=$(echo "$line" | sed -E 's/(.*STDOUT )tofu:(.*)/\1/')
                local suffix=$(echo "$line" | sed -E 's/(.*STDOUT )tofu:(.*)/\2/')
                printf "%s%sinfra:%s%s%s%s\n" "$prefix" "$NEON_PINK" "$NC" "$LIGHT_PINK_BLUE" "$suffix" "$NC"
            else
                # For other lines, just pass through as-is
                echo "$line"
            fi
        else
            # No color mode - just replace tofu: with infra:
            echo "$line" | sed 's/tofu:/infra:/g'
        fi
    done
}



# Export functions for use by other modules

debug_message "Shared utilities module loaded successfully" 