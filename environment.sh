#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Environment Management Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Environment setup, validation, and configuration management
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Environment Setup Functions
# ─────────────────────────────────────────────────────────────────────────────

# Set up global environment variables
# Usage: setup_global_environment
setup_global_environment() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    local verbose_level=$(get_verbose_level)
    local no_color="false"
    local dry_run="false"
    
    # Check boolean flags properly
    if is_no_color; then
        no_color="true"
    fi
    
    if is_dry_run; then
        dry_run="true"
    fi
    
    debug_message "Setting up global environment"
    debug_message "Environment: $OP_ENV, Verbose: $verbose_level, No Color: $no_color, Dry Run: $dry_run"
    
    # Set global variables in shared utilities (will be updated with log files later)
    set_global_vars "$verbose_level" "$no_color" "$dry_run" "$OP_ENV" "" ""
    
    # Change to environment directory for consistent context (using KISS variable)
    debug_message "Changing to environment directory: $OP_ENV_PATH"
    cd "$OP_ENV_PATH"
    
    # Load modules for the environment
    load_modules "$OP_ENV"
    
    # Validate target type after modules are loaded
    validate_target_after_loading
    
    debug_message "Global environment setup completed"
}

# Set up logging for the operation
# Usage: setup_operation_logging
setup_operation_logging() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Setting up operation logging"
    
    # Initialize logging system (using KISS variables)
    setup_logging "$OP_ENV" "$OP_ACTION" "$OP_TARGET_TYPE"
    
    # Clean up old log files
    cleanup_old_logs "$OP_ENV"
    
    debug_message "Operation logging setup completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Validate target type after modules are loaded
# Usage: validate_target_after_loading
validate_target_after_loading() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Validating target type after loading modules: $OP_TARGET_TYPE"
    
    # Standard targets don't need validation
    case "$OP_TARGET_TYPE" in
        "infrastructure"|"instances"|"all")
            debug_message "Standard target type validated: $OP_TARGET_TYPE"
            return 0
            ;;
    esac
    
    # For single modules, validate they exist
    if ! is_module_enabled "$OP_TARGET_TYPE"; then
        handle_error "Module '$OP_TARGET_TYPE' not found in modules.yml"
    fi
    
    # For volume operations, validate target is an instance module
    if [[ "$OP_ACTION" == "volume" ]]; then
        local module_type=$(get_module_type "$OP_TARGET_TYPE")
        if [[ "$module_type" != "instance" ]]; then
            handle_error "Volume operations require an instance module. '$OP_TARGET_TYPE' is a $module_type module"
        fi
    fi
    
    debug_message "Target type validation successful: $OP_TARGET_TYPE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Environment management module loaded successfully" 