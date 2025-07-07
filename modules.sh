#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Module Management (DRY KISS)
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Load and categorize modules from modules.yml - SIMPLE AND FOCUSED
# Author: Infrastructure Management System v2.0
# Last Updated: January 2, 2025

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Global Module Arrays - Simple and Clear
# ─────────────────────────────────────────────────────────────────────────────

# Module state tracking
MODULES_LOADED=false
CURRENT_MODULES_ENV=""

# Enabled modules (the main lists to use)
ALL_INFRASTRUCTURE_MODULES=()
ALL_INSTANCE_MODULES=()
ALL_MODULES=()

# Special module categories
PROTECTED_MODULES=()     # modules with protected: true
DISABLED_MODULES=()      # modules with disabled: true

# ─────────────────────────────────────────────────────────────────────────────
# Core Module Loading - DRY KISS Implementation
# ─────────────────────────────────────────────────────────────────────────────

# Load modules from environment modules.yml file
# Usage: load_modules "dev"
load_modules() {
    local env="$1"
    
    debug_message "Loading modules for environment: $env"
    
    # Skip if already loaded for this environment  
    if [[ "$MODULES_LOADED" == "true" && "$CURRENT_MODULES_ENV" == "$env" ]]; then
        debug_message "Modules already loaded for environment: $env"
        return 0
    fi
    
    # Get modules file path
    local env_path="$(get_environment_path "$env")"
    local modules_file="$env_path/modules.yml"
    
    # Validate file exists
    if [[ ! -f "$modules_file" ]]; then
        handle_error "Modules file not found: $modules_file"
    fi
    
    # Clear all arrays
    clear_module_arrays
    
    # Load infrastructure modules
    load_infrastructure_modules "$modules_file"
    
    # Load instance modules  
    load_instance_modules "$modules_file"
    
    # Build combined list safely (handle empty arrays properly)
    ALL_MODULES=()
    # Add infrastructure modules safely
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            ALL_MODULES+=("$module")
        fi
    done < <(safe_array_iterate "ALL_INFRASTRUCTURE_MODULES")
    
    # Add instance modules safely  
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            ALL_MODULES+=("$module")
        fi
    done < <(safe_array_iterate "ALL_INSTANCE_MODULES")
    
    # Validate we loaded something
    if [[ $(safe_array_length "ALL_MODULES") -eq 0 ]]; then
        handle_error "No enabled modules found in: $modules_file"
    fi
    
    # Mark as loaded
    MODULES_LOADED=true
    CURRENT_MODULES_ENV="$env"
    
    debug_message "Modules loaded successfully:"
    debug_message "  Infrastructure: $(safe_array_string "ALL_INFRASTRUCTURE_MODULES")"
    debug_message "  Instances: $(safe_array_string "ALL_INSTANCE_MODULES")"
    debug_message "  Protected: $(safe_array_string "PROTECTED_MODULES")"
    debug_message "  Disabled: $(safe_array_string "DISABLED_MODULES")"
    debug_message "  Total enabled: $(safe_array_length "ALL_MODULES")"
}

# Load infrastructure modules from YAML
# Usage: load_infrastructure_modules "/path/to/modules.yml"
load_infrastructure_modules() {
    local modules_file="$1"
    
    debug_message "Loading infrastructure modules from: $modules_file"
    
    # Load all infrastructure modules (now all are objects with name field)
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            # Check if disabled
            local is_disabled=$(yq eval ".infrastructure[] | select(.name == \"$module\") | .disabled // false" "$modules_file" 2>/dev/null || echo "false")
            
            if [[ "$is_disabled" == "true" ]]; then
                DISABLED_MODULES+=("$module")
                debug_message "Disabled infrastructure module: $module"
            else
                ALL_INFRASTRUCTURE_MODULES+=("$module")
                debug_message "Added infrastructure module: $module"
                
                # Check if protected from destroy
                local is_protected=$(yq eval ".infrastructure[] | select(.name == \"$module\") | .protected // false" "$modules_file" 2>/dev/null || echo "false")
                debug_message "Module $module protection check: is_protected=$is_protected"
                if [[ "$is_protected" == "true" ]]; then
                    PROTECTED_MODULES+=("$module")
                    debug_message "Protected infrastructure module: $module"
                else
                    debug_message "Module $module is NOT protected (protected: false or not set)"
                fi
            fi
        fi
    done < <(yq eval '.infrastructure[].name' "$modules_file" 2>/dev/null || true)
}

# Load instance modules from YAML
# Usage: load_instance_modules "/path/to/modules.yml"
load_instance_modules() {
    local modules_file="$1"
    
    debug_message "Loading instance modules from: $modules_file"
    
    # Load all instance modules (now all are objects with name field)
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            # Check if disabled
            local is_disabled=$(yq eval ".instances[] | select(.name == \"$module\") | .disabled // false" "$modules_file" 2>/dev/null || echo "false")
            
            if [[ "$is_disabled" == "true" ]]; then
                DISABLED_MODULES+=("$module")
                debug_message "Disabled instance module: $module"
            else
                ALL_INSTANCE_MODULES+=("$module") 
                debug_message "Added instance module: $module"
                
                # Check if protected from destroy
                local is_protected=$(yq eval ".instances[] | select(.name == \"$module\") | .protected // false" "$modules_file" 2>/dev/null || echo "false")
                if [[ "$is_protected" == "true" ]]; then
                    PROTECTED_MODULES+=("$module")
                    debug_message "Protected instance module: $module"
                fi
            fi
        fi
    done < <(yq eval '.instances[].name' "$modules_file" 2>/dev/null || true)
}

# Clear all module arrays
# Usage: clear_module_arrays
clear_module_arrays() {
    ALL_INFRASTRUCTURE_MODULES=()
    ALL_INSTANCE_MODULES=()
    ALL_MODULES=()
    PROTECTED_MODULES=()
    DISABLED_MODULES=()
}

# ─────────────────────────────────────────────────────────────────────────────
# Simple Validation Functions - Clear and Focused
# ─────────────────────────────────────────────────────────────────────────────

# Check if modules are loaded
# Usage: is_modules_loaded
is_modules_loaded() {
    [[ "$MODULES_LOADED" == "true" ]]
}

# Check if a module is enabled (exists in enabled lists)
# Usage: is_module_enabled "athena"
is_module_enabled() {
    local module="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    while IFS= read -r enabled_module; do
        if [[ -n "$enabled_module" && "$module" == "$enabled_module" ]]; then
            return 0
        fi
    done < <(safe_array_iterate "ALL_MODULES")
    
    return 1
}

# Check if a module is valid (alias for is_module_enabled for compatibility)
# Usage: is_valid_module "athena"
is_valid_module() {
    local module="$1"
    is_module_enabled "$module"
}

# Check if a module is disabled  
# Usage: is_module_disabled "eips"
is_module_disabled() {
    local module="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first" 
    fi
    
    while IFS= read -r disabled_module; do
        if [[ -n "$disabled_module" && "$module" == "$disabled_module" ]]; then
            return 0
        fi
    done < <(safe_array_iterate "DISABLED_MODULES")
    
    return 1
}

# Check if a module is protected from destroy
# Usage: is_module_protected "ebss"  
is_module_protected() {
    local module="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    while IFS= read -r protected_module; do
        if [[ -n "$protected_module" && "$module" == "$protected_module" ]]; then
            return 0
        fi
    done < <(safe_array_iterate "PROTECTED_MODULES")
    
    return 1
}

# Get module type (infrastructure or instance)
# Usage: get_module_type "athena"
get_module_type() {
    local module="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    # Check infrastructure modules
    while IFS= read -r infra_module; do
        if [[ -n "$infra_module" && "$module" == "$infra_module" ]]; then
            echo "infrastructure"
            return 0
        fi
    done < <(safe_array_iterate "ALL_INFRASTRUCTURE_MODULES")
    
    # Check instance modules
    while IFS= read -r instance_module; do
        if [[ -n "$instance_module" && "$module" == "$instance_module" ]]; then
            echo "instance"
            return 0
        fi
    done < <(safe_array_iterate "ALL_INSTANCE_MODULES")
    
    # Not found in enabled modules - check if it's disabled
    if is_module_disabled "$module"; then
        handle_error "Module '$module' is disabled in this environment"
    else
        handle_error "Module '$module' not found in modules.yml"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Simple Getter Functions - Direct Array Access
# ─────────────────────────────────────────────────────────────────────────────

# Get all enabled infrastructure modules
# Usage: get_infrastructure_modules  
get_infrastructure_modules() {
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    safe_array_elements "ALL_INFRASTRUCTURE_MODULES"
}

# Get all enabled instance modules
# Usage: get_instance_modules
get_instance_modules() {
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    safe_array_elements "ALL_INSTANCE_MODULES"
}

# Get all enabled modules
# Usage: get_all_modules
get_all_modules() {
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    safe_array_elements "ALL_MODULES"
}

# Get protected modules
# Usage: get_protected_modules
get_protected_modules() {
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    safe_array_elements "PROTECTED_MODULES"
}

# Get disabled modules  
# Usage: get_disabled_modules
get_disabled_modules() {
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    safe_array_elements "DISABLED_MODULES"
}

# Get modules for target type - simple compatibility function
# Usage: get_modules_for_target "infrastructure"
get_modules_for_target() {
    local target_type="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    case "$target_type" in
        "infrastructure")
            get_infrastructure_modules
            ;;
        "instances")
            get_instance_modules
            ;;
        "all")
            get_all_modules
            ;;
        *)
            # Single module - validate it's enabled first
            if is_module_enabled "$target_type"; then
                echo "$target_type"
            else
                if is_module_disabled "$target_type"; then
                    handle_error "Module '$target_type' is disabled in this environment"
                else
                    handle_error "Module '$target_type' not found in modules.yml"
                fi
            fi
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export - DRY KISS Complete
# ─────────────────────────────────────────────────────────────────────────────

# Get command for a specific module from modules.yml
# Usage: get_module_cmd "security_groups"
get_module_cmd() {
    local module="$1"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    local env_path="$(get_environment_path "$CURRENT_MODULES_ENV")"
    local modules_file="$env_path/modules.yml"
    
    # Check infrastructure modules first
    local cmd=$(yq eval ".infrastructure[] | select(.name == \"$module\") | .cmd // \"\"" "$modules_file" 2>/dev/null || echo "")
    
    # If not found in infrastructure, check instances
    if [[ -z "$cmd" ]]; then
        cmd=$(yq eval ".instances[] | select(.name == \"$module\") | .cmd // \"\"" "$modules_file" 2>/dev/null || echo "")
    fi
    
    echo "$cmd"
}

# Execute pre-processing commands for target modules
# Usage: execute_module_cmds "infrastructure" "apply"
execute_module_cmds() {
    local target_type="$1"
    local operation="$2"
    
    debug_message "Checking for module commands to execute for target: $target_type, operation: $operation"
    
    # Only execute for apply operations (KISS - keep it simple)
    if [[ "$operation" != "apply" ]]; then
        debug_message "Skipping module commands for operation: $operation (only applied to 'apply' operations)"
        return 0
    fi
    
    # Get modules for the target type
    local modules_to_process=()
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            modules_to_process+=("$module")
        fi
    done < <(get_modules_for_target "$target_type")
    
    # Execute cmd for each module that has one
    local original_dir="$(pwd)"
    local env_path="$(get_environment_path "$CURRENT_MODULES_ENV")"
    
    for module in "${modules_to_process[@]}"; do
        local cmd=$(get_module_cmd "$module")
        
        if [[ -n "$cmd" ]]; then
            local module_path="$env_path/$module"
            
            if [[ ! -d "$module_path" ]]; then
                handle_error "Module directory not found: $module_path"
            fi
            
            info_message "🔧 Executing pre-processing command for module '$module': $cmd"
            debug_message "Changing to module directory: $module_path"
            
            # Change to module directory and execute command
            if cd "$module_path" 2>/dev/null; then
                # Check if we're in dry-run mode
                if is_dry_run; then
                    dry_run_message "[DRY-RUN] Would execute in $module_path: $cmd"
                else
                    debug_message "Executing command: $cmd"
                    if eval "$cmd"; then
                        success_message "✅ Command completed successfully for module '$module'"
                    else
                        handle_error "Command failed for module '$module': $cmd"
                    fi
                fi
                
                # Return to original directory
                cd "$original_dir" || handle_error "Failed to return to original directory: $original_dir"
            else
                handle_error "Failed to change to module directory: $module_path"
            fi
        else
            debug_message "No command defined for module: $module"
        fi
    done
    
    debug_message "Module command execution completed"
}

debug_message "Modules management system loaded (DRY KISS implementation)" 