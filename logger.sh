#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Logging System
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Automatic dual logging system (debug + human-readable)
# Author: Infrastructure Management System v2.0
# Last Updated: May 26, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Global Variables
# ─────────────────────────────────────────────────────────────────────────────

# Logging state
LOG_SESSION_ID=""
LOG_DIRECTORY=""
DEBUG_LOG_FILE=""
HUMAN_LOG_FILE=""
TERRAGRUNT_LOG_FILE=""
LOGGING_INITIALIZED=false

# ─────────────────────────────────────────────────────────────────────────────
# Core Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

# Initialize logging for an operation
# Usage: setup_logging "dev" "apply" "infrastructure"
setup_logging() {
    local env="$1"
    local action="$2"
    local target="$3"
    
    # Generate session ID and timestamp
    LOG_SESSION_ID=$(date '+%Y%m%d-%H%M%S')
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Set up log directory
    LOG_DIRECTORY="$(get_environment_path "$env")/log"
    ensure_directory "$LOG_DIRECTORY"
    
    # Set up log file paths
    DEBUG_LOG_FILE="$LOG_DIRECTORY/debug.log"
    HUMAN_LOG_FILE="$LOG_DIRECTORY/infra.log"
    TERRAGRUNT_LOG_FILE="$LOG_DIRECTORY/terragrunt.log"
    
    # Initialize log files with headers
    init_debug_log "$env" "$action" "$target" "$timestamp"
    init_human_log "$env" "$action" "$target" "$timestamp"
    
    # Mark logging as initialized
    LOGGING_INITIALIZED=true
    
    # Update shared utilities with log file paths
    set_global_vars "$VERBOSE_LEVEL" "$NO_COLOR" "$DRY_RUN" "$env" "$DEBUG_LOG_FILE" "$HUMAN_LOG_FILE"
    
    debug_message "Logging initialized for session: $LOG_SESSION_ID"
    if [[ "${QUIET_MODE:-0}" -eq 1 ]]; then return; fi
    info_message "Logs will be written to: $LOG_DIRECTORY"
}

# Initialize debug log file
# Usage: init_debug_log "dev" "apply" "infrastructure" "timestamp"
init_debug_log() {
    local env="$1"
    local action="$2"
    local target="$3"
    local timestamp="$4"
    
    # Ensure log directory exists before writing
    local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
    [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
    
    cat > "$DEBUG_LOG_FILE" << EOF
# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Debug Log
# ═══════════════════════════════════════════════════════════════════════════
# Session ID: $LOG_SESSION_ID
# Started: $timestamp
# Environment: $env
# Action: $action
# Target: $target
# ═══════════════════════════════════════════════════════════════════════════

[$timestamp] [INFO] Debug logging session started
[$timestamp] [INFO] Session ID: $LOG_SESSION_ID
[$timestamp] [INFO] Environment: $env
[$timestamp] [INFO] Action: $action
[$timestamp] [INFO] Target: $target
[$timestamp] [INFO] Log Directory: $LOG_DIRECTORY
[$timestamp] [DEBUG] Debug log file: $DEBUG_LOG_FILE
[$timestamp] [DEBUG] Human log file: $HUMAN_LOG_FILE
[$timestamp] [DEBUG] Terragrunt log file: $TERRAGRUNT_LOG_FILE
[$timestamp] [TEST_MARKER] LOGGING_SESSION_STARTED env=$env action=$action target=$target

EOF
}

# Initialize human-readable log file
# Usage: init_human_log "dev" "apply" "infrastructure" "timestamp"
init_human_log() {
    local env="$1"
    local action="$2"
    local target="$3"
    local timestamp="$4"
    
    # Ensure log directory exists before writing
    local human_dir="$(dirname "$HUMAN_LOG_FILE")"
    [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
    
    cat > "$HUMAN_LOG_FILE" << EOF
Infrastructure Management System v2.0 - Operation Log
═══════════════════════════════════════════════════════════════════════════

Session: $LOG_SESSION_ID
Started: $timestamp
Environment: $env
Action: $action
Target: $target

═══════════════════════════════════════════════════════════════════════════

[$timestamp] Operation started: $action $env:$target
[$timestamp] [TEST_MARKER] HUMAN_LOG_INITIALIZED env=$env action=$action target=$target

EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Specialized Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

# Log command execution
# Usage: log_command "terragrunt apply --all"
log_command() {
    local command="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        # Ensure log directories exist before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        
        echo "[$timestamp] [COMMAND] Executing: $command" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
        echo "[$timestamp] Executing: $command" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    fi
}

# Log command result
# Usage: log_command_result "terragrunt apply" 0 "Success"
log_command_result() {
    local command="$1"
    local exit_code="$2"
    local result_message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        # Ensure log directories exist before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        
        if [[ "$exit_code" -eq 0 ]]; then
            echo "[$timestamp] [SUCCESS] Command completed: $command - $result_message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] ✅ $result_message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        else
            echo "[$timestamp] [ERROR] Command failed: $command - Exit code: $exit_code - $result_message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] ❌ Command failed: $result_message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        fi
    fi
}

# Log operation phase
# Usage: log_phase "Generating outputs"
log_phase() {
    local phase="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        # Ensure log directories exist before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        
        echo "[$timestamp] [PHASE] $phase" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
        echo "[$timestamp] [TEST_MARKER] PHASE_LOGGED phase=\"$phase\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
        echo "" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        echo "[$timestamp] 📋 $phase" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        echo "───────────────────────────────────────────────────────────────────────────" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    fi
}

# Log module processing
# Usage: log_module_processing "athena" "start|success|error" "message"
log_module_processing() {
    local module="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        # Ensure log directories exist before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        
        case "$status" in
            "start")
                echo "[$timestamp] [MODULE] Processing module: $module" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] [TEST_MARKER] MODULE_PROCESSING module=\"$module\" status=\"start\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] 🔄 Processing: $module" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
                ;;
            "success")
                echo "[$timestamp] [MODULE] Module completed successfully: $module - $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] [TEST_MARKER] MODULE_PROCESSING module=\"$module\" status=\"success\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] ✅ Completed: $module - $message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
                ;;
            "error")
                echo "[$timestamp] [MODULE] Module failed: $module - $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] [TEST_MARKER] MODULE_PROCESSING module=\"$module\" status=\"error\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] ❌ Failed: $module - $message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
                ;;
            "skip")
                echo "[$timestamp] [MODULE] Module skipped: $module - $message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] [TEST_MARKER] MODULE_PROCESSING module=\"$module\" status=\"skip\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
                echo "[$timestamp] ⏭️  Skipped: $module - $message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
                ;;
        esac
    fi
}

# Log exclusion information
# Usage: log_exclusions "infrastructure" "athena,aegis,metis"
log_exclusions() {
    local target_type="$1"
    local exclusions="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        # Ensure log directories exist before writing
        local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
        local human_dir="$(dirname "$HUMAN_LOG_FILE")"
        [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
        [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
        
        echo "[$timestamp] [EXCLUSIONS] Target: $target_type, Excluding: $exclusions" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
        echo "[$timestamp] 🎯 Target: $target_type" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        if [[ -n "$exclusions" ]]; then
            echo "[$timestamp] 🚫 Excluding: $exclusions" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        else
            echo "[$timestamp] 📦 Processing all modules" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Terragrunt Output Capture
# ─────────────────────────────────────────────────────────────────────────────

# Execute command with output capture
# Usage: execute_with_logging "terragrunt apply --all"
execute_with_logging() {
    local command="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" != true ]]; then
        echo "ERROR: Logging not initialized" >&2
        return 1
    fi
    
    # Log command execution
    log_command "$command"
    
    # Ensure terragrunt log directory exists before writing
    local terragrunt_dir="$(dirname "$TERRAGRUNT_LOG_FILE")"
    [[ ! -d "$terragrunt_dir" ]] && mkdir -p "$terragrunt_dir" 2>/dev/null || true
    
    # Create terragrunt log header
    cat >> "$TERRAGRUNT_LOG_FILE" << EOF

[$timestamp] ═══════════════════════════════════════════════════════════════════════════
[$timestamp] Executing: $command
[$timestamp] ═══════════════════════════════════════════════════════════════════════════

EOF
    
    # Execute command and capture output
    local exit_code=0
    if [[ "$DRY_RUN" == true ]]; then
        echo "[$timestamp] [DRY-RUN] Would execute: $command" >> "$TERRAGRUNT_LOG_FILE"
        echo "[$timestamp] [DRY-RUN] Command simulation completed successfully" >> "$TERRAGRUNT_LOG_FILE"
        log_command_result "$command" 0 "Dry-run simulation completed"
    else
        # Execute command with output capture
        if eval "$command" >> "$TERRAGRUNT_LOG_FILE" 2>&1; then
            exit_code=0
            log_command_result "$command" 0 "Command completed successfully"
        else
            exit_code=$?
            log_command_result "$command" $exit_code "Command failed with exit code $exit_code"
        fi
    fi
    
    # Add footer to terragrunt log
    local end_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat >> "$TERRAGRUNT_LOG_FILE" << EOF

[$end_timestamp] ═══════════════════════════════════════════════════════════════════════════
[$end_timestamp] Command completed with exit code: $exit_code
[$end_timestamp] ═══════════════════════════════════════════════════════════════════════════

EOF
    
    return $exit_code
}

# ─────────────────────────────────────────────────────────────────────────────
# Session Management
# ─────────────────────────────────────────────────────────────────────────────

# Finalize logging session
# Usage: finalize_logging "success|error" "Final message"
finalize_logging() {
    local status="$1"
    local final_message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$LOGGING_INITIALIZED" != true ]]; then
        return 0
    fi
    
    # Ensure log directories exist before writing
    local debug_dir="$(dirname "$DEBUG_LOG_FILE")"
    local human_dir="$(dirname "$HUMAN_LOG_FILE")"
    [[ ! -d "$debug_dir" ]] && mkdir -p "$debug_dir" 2>/dev/null || true
    [[ ! -d "$human_dir" ]] && mkdir -p "$human_dir" 2>/dev/null || true
    
    # Log session completion
    case "$status" in
        "success")
            echo "[$timestamp] [SUCCESS] Operation completed successfully: $final_message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] [TEST_MARKER] LOGGING_FINALIZED status=\"success\" message=\"$final_message\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] ✅ Operation completed successfully" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] $final_message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            ;;
        "error")
            echo "[$timestamp] [ERROR] Operation failed: $final_message" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] [TEST_MARKER] LOGGING_FINALIZED status=\"error\" message=\"$final_message\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
            echo "" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] ❌ Operation failed" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            echo "[$timestamp] $final_message" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
            ;;
    esac
    
    # Add session footer
    echo "" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    echo "[$timestamp] [INFO] Logging session ended: $LOG_SESSION_ID" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    echo "[$timestamp] [TEST_MARKER] LOGGING_SESSION_ENDED session_id=\"$LOG_SESSION_ID\"" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    echo "═══════════════════════════════════════════════════════════════════════════" >> "$DEBUG_LOG_FILE" 2>/dev/null || true
    
    echo "" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    echo "═══════════════════════════════════════════════════════════════════════════" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    echo "[$timestamp] Session ended: $LOG_SESSION_ID" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    echo "═══════════════════════════════════════════════════════════════════════════" >> "$HUMAN_LOG_FILE" 2>/dev/null || true
    
    # Display log file locations with beautiful colors
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${WHITE}Operation logs saved to:${NC}"
        echo -e "${WHITE}  Debug log: ${YELLOW}$DEBUG_LOG_FILE${NC}"
        echo -e "${WHITE}  Human log: ${YELLOW}$HUMAN_LOG_FILE${NC}"
        echo -e "${WHITE}  Terragrunt log: ${YELLOW}$TERRAGRUNT_LOG_FILE${NC}"
    else
        info_message "Operation logs saved to:"
        info_message "  Debug log: $DEBUG_LOG_FILE"
        info_message "  Human log: $HUMAN_LOG_FILE"
        info_message "  Terragrunt log: $TERRAGRUNT_LOG_FILE"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Log File Management
# ─────────────────────────────────────────────────────────────────────────────

# Clean up old log files (keep last 10 sessions)
# Usage: cleanup_old_logs "dev"
cleanup_old_logs() {
    local env="$1"
    local log_dir="$(get_environment_path "$env")/log"
    
    if [[ ! -d "$log_dir" ]]; then
        return 0
    fi
    
    debug_message "Cleaning up old log files in: $log_dir"
    
    # Rotate terragrunt.log if it gets too large (>10MB)
    local terragrunt_log="$log_dir/terragrunt.log"
    if [[ -f "$terragrunt_log" ]] && [[ $(stat -f%z "$terragrunt_log" 2>/dev/null || echo 0) -gt 10485760 ]]; then
        debug_message "Rotating large terragrunt log file"
        mv "$terragrunt_log" "$terragrunt_log.old"
    fi
    
    debug_message "Log cleanup completed"
}

# Get log file paths for current session
# Usage: get_log_files -> returns array of log file paths
get_log_files() {
    if [[ "$LOGGING_INITIALIZED" == true ]]; then
        echo "$DEBUG_LOG_FILE"
        echo "$HUMAN_LOG_FILE"
        echo "$TERRAGRUNT_LOG_FILE"
    fi
}

# Check if logging is active
# Usage: is_logging_active
is_logging_active() {
    [[ "$LOGGING_INITIALIZED" == true ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get current session ID
# Usage: get_session_id
get_session_id() {
    echo "$LOG_SESSION_ID"
}

# Get log directory for environment
# Usage: get_log_directory "dev"
get_log_directory() {
    local env="$1"
    echo "$(get_environment_path "$env")/log"
}

# Get terragrunt log file path
# Usage: get_terragrunt_log_file
get_terragrunt_log_file() {
    echo "$TERRAGRUNT_LOG_FILE"
}

# Display recent log entries
# Usage: show_recent_logs "debug|human|terragrunt" [lines]
show_recent_logs() {
    local log_type="$1"
    local lines="${2:-20}"
    
    if [[ "$LOGGING_INITIALIZED" != true ]]; then
        warn_message "No active logging session"
        return 1
    fi
    
    case "$log_type" in
        "debug")
            tail -n "$lines" "$DEBUG_LOG_FILE"
            ;;
        "human")
            tail -n "$lines" "$HUMAN_LOG_FILE"
            ;;
        "terragrunt")
            tail -n "$lines" "$TERRAGRUNT_LOG_FILE"
            ;;
        *)
            handle_error "Invalid log type: $log_type. Use: debug, human, or terragrunt"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Logger module loaded successfully - debug_message not available yet 