#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Target Resolution & Exclusions
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Target resolution, exclusion generation, and operation validation
# Author: Infrastructure Management System v2.0  
# Last Updated: January 2, 2025

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Terragrunt Exclusion Generation - DRY KISS Implementation
# ─────────────────────────────────────────────────────────────────────────────

# Generate terragrunt exclusion flags for target operations
# Usage: generate_terragrunt_exclusions "infrastructure"
generate_terragrunt_exclusions() {
    local target_type="$1"
    
    debug_message "Generating terragrunt exclusions for target: $target_type"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    local exclusions=()
    
    # Always exclude disabled modules from all operations
    while IFS= read -r module; do
        [[ -n "$module" ]] && exclusions+=("$module")
    done < <(get_disabled_modules)
    
    # Add target-specific exclusions
    case "$target_type" in
        "infrastructure"|"instances")
            # For infrastructure or instances, exclude the other type
            if [[ "$target_type" == "infrastructure" ]]; then
                while IFS= read -r module; do
                    [[ -n "$module" ]] && exclusions+=("$module")
                done < <(get_instance_modules)
            else
                while IFS= read -r module; do
                    [[ -n "$module" ]] && exclusions+=("$module")
                done < <(get_infrastructure_modules)
            fi
            
            # For destroy operations, handle protection logic
            if [[ "${OP_ACTION:-}" == "destroy" ]]; then
                debug_message "Destroy operation detected - checking for protected and destroy-disabled modules"
                
                # CRITICAL: Always exclude destroy-disabled modules, regardless of --force
                local target_modules=()
                if [[ "$target_type" == "infrastructure" ]]; then
                    while IFS= read -r module; do
                        [[ -n "$module" ]] && target_modules+=("$module")
                    done < <(get_infrastructure_modules)
                else
                    while IFS= read -r module; do
                        [[ -n "$module" ]] && target_modules+=("$module")
                    done < <(get_instance_modules)
                fi
                
                for module in "${target_modules[@]}"; do
                    if is_module_destroy_disabled "$module"; then
                        exclusions+=("$module")
                        debug_message "Found destroy-disabled module: $module - ALWAYS excluded from terragrunt"
                    fi
                done
                
                # For protected modules, only exclude if --force is not used
                if ! (declare -f is_force >/dev/null 2>&1 && is_force); then
                    local protected_modules=()
                    while IFS= read -r module; do
                        if [[ -n "$module" ]] && ! is_module_destroy_disabled "$module"; then
                            protected_modules+=("$module")
                            debug_message "Found protected module: $module"
                        fi
                    done < <(get_protected_modules)
                    
                    if [[ ${#protected_modules[@]} -gt 0 ]]; then
                        debug_message "Adding protected modules to exclusions: ${protected_modules[*]}"
                        for module in "${protected_modules[@]}"; do
                            exclusions+=("$module")
                        done
                    else
                        debug_message "No protected modules found"
                    fi
                else
                    debug_message "--force is enabled - skipping protected module exclusions (but keeping destroy-disabled exclusions)"
                fi
            else
                debug_message "Not a destroy operation - skipping protection checks"
            fi
            ;;
            
        "all")
            # For 'all' operations, only exclude disabled and protected modules as needed
            
            # Always exclude disabled modules from all operations
            while IFS= read -r module; do
                [[ -n "$module" ]] && exclusions+=("$module")
            done < <(get_disabled_modules)
            
            # For destroy operations, handle protection logic
            if [[ "${OP_ACTION:-}" == "destroy" ]]; then
                debug_message "Destroy operation detected for 'all' target - checking for protected and destroy-disabled modules"
                
                # CRITICAL: Always exclude destroy-disabled modules, regardless of --force
                local all_modules=()
                while IFS= read -r module; do
                    [[ -n "$module" ]] && all_modules+=("$module")
                done < <(get_all_modules)
                
                for module in "${all_modules[@]}"; do
                    if is_module_destroy_disabled "$module"; then
                        exclusions+=("$module")
                        debug_message "Found destroy-disabled module: $module - ALWAYS excluded from terragrunt"
                    fi
                done
                
                # For protected modules, only exclude if --force is not used
                if ! (declare -f is_force >/dev/null 2>&1 && is_force); then
                    local protected_modules=()
                    while IFS= read -r module; do
                        if [[ -n "$module" ]] && ! is_module_destroy_disabled "$module"; then
                            protected_modules+=("$module")
                            debug_message "Found protected module: $module"
                        fi
                    done < <(get_protected_modules)
                    
                    if [[ ${#protected_modules[@]} -gt 0 ]]; then
                        debug_message "Adding protected modules to exclusions: ${protected_modules[*]}"
                        for module in "${protected_modules[@]}"; do
                            exclusions+=("$module")
                        done
                    else
                        debug_message "No protected modules found"
                    fi
                else
                    debug_message "--force is enabled - skipping protected module exclusions (but keeping destroy-disabled exclusions)"
                fi
            else
                debug_message "Not a destroy operation - skipping protection checks"
            fi
            ;;
            
        *)
            # Single module operation - exclude everything else, plus disabled modules
            while IFS= read -r module; do
                if [[ "$module" != "$target_type" ]]; then
                    exclusions+=("$module")
                fi
            done < <(get_all_modules)
            
            # Always exclude disabled modules
            while IFS= read -r module; do
                [[ -n "$module" ]] && exclusions+=("$module")
            done < <(get_disabled_modules)
            
            # For destroy operations, check if target module is protected or destroy-disabled
            if [[ "${OP_ACTION:-}" == "destroy" ]]; then
                debug_message "Destroy operation detected for single module '$target_type' - checking protection status"
                
                # CRITICAL: Always exclude destroy-disabled modules from terragrunt operations
                if is_module_destroy_disabled "$target_type"; then
                    exclusions+=("$target_type")
                    debug_message "Target module $target_type has destroy: false - ALWAYS excluded from terragrunt destroy"
                elif ! (declare -f is_force >/dev/null 2>&1 && is_force) && is_module_protected "$target_type"; then
                    # Only exclude protected modules if --force is not used
                    exclusions+=("$target_type")
                    debug_message "Target module $target_type is protected - added to exclusions (no --force)"
                else
                    debug_message "Target module $target_type will be processed by terragrunt destroy"
                fi
            else
                debug_message "Not a destroy operation - skipping protection checks"
            fi
            ;;
    esac
    
    # Remove duplicates and build terragrunt flags
    if safe_array_has_elements "exclusions"; then
        local unique_exclusions=()
        while IFS= read -r exclusion; do
            local already_added=false
            if safe_array_has_elements "unique_exclusions"; then
                while IFS= read -r unique_exclusion; do
                    if [[ "$exclusion" == "$unique_exclusion" ]]; then
                        already_added=true
                        break
                    fi
                done < <(safe_array_iterate "unique_exclusions")
            fi
            if [[ "$already_added" == false ]]; then
                unique_exclusions+=("$exclusion")
            fi
        done < <(safe_array_iterate "exclusions")
        
        # Build exclusion flags
        local exclusion_list=$(IFS=','; echo "$(safe_array_string "unique_exclusions")")
        local exclusion_flags=" --queue-exclude-dir=$exclusion_list"
        debug_message "Generated terragrunt exclusion flags: $exclusion_flags"
        echo "$exclusion_flags"
    else
        debug_message "No exclusions needed for target: $target_type"
        echo ""
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Operation Validation - DRY KISS Implementation  
# ─────────────────────────────────────────────────────────────────────────────

# Validate destroy operation against protected modules
# Usage: validate_destroy_operation "infrastructure" "destroy"
validate_destroy_operation() {
    local target_type="$1"
    local action="$2"
    
    debug_message "Validating destroy operation: target=$target_type, action=$action"
    
    # Only validate destroy operations
    if [[ "$action" != "destroy" ]]; then
        debug_message "Not a destroy operation - skipping protection check"
        return 0
    fi
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    # Get target modules that would be affected
    local target_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && target_modules+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    # Get protected modules from the target list
    local protected_in_target=()
    while IFS= read -r target_module; do
        if is_module_protected "$target_module"; then
            protected_in_target+=("$target_module")
        fi
    done < <(safe_array_iterate "target_modules")
    
    # If no protected modules in target, allow operation
    if ! safe_array_has_elements "protected_in_target"; then
        debug_message "No protected modules in target - operation allowed"
        return 0
    fi
    
    # Get non-protected modules that will be destroyed
    local non_protected_in_target=()
    while IFS= read -r target_module; do
        if ! is_module_protected "$target_module"; then
            non_protected_in_target+=("$target_module")
        fi
    done < <(safe_array_iterate "target_modules")
    
    # Check if force flag is enabled - allows destroying protected modules
    if declare -f is_force >/dev/null 2>&1 && is_force; then
        warn_message "Protected modules will be destroyed due to --force flag:"
        while IFS= read -r module; do
            warn_message "  ⚠️  $module (protected: true)"
        done < <(safe_array_iterate "protected_in_target")
        return 0
    fi
    
    # If there are non-protected modules to destroy, show warning but allow operation
    if safe_array_has_elements "non_protected_in_target"; then
        warn_message "The following modules are protected from destruction:"
        while IFS= read -r module; do
            warn_message "  🛡️  $module (protected: true)"
        done < <(safe_array_iterate "protected_in_target")
        warn_message ""
        warn_message "These modules will be SKIPPED. The following modules will be destroyed:"
        while IFS= read -r module; do
            info_message "  ✅ $module"
        done < <(safe_array_iterate "non_protected_in_target")
        warn_message ""
        warn_message "To destroy protected modules as well, use: --force"
        return 0
    fi
    
    # All target modules are protected - block operation
    warn_message "All target modules are protected from destruction:"
    while IFS= read -r module; do
        warn_message "  🛡️  $module (protected: true)"
    done < <(safe_array_iterate "protected_in_target")
    warn_message ""
    warn_message "To destroy these modules anyway, use: --force"
    
    handle_error "Destroy operation blocked - all target modules are protected"
}

# ─────────────────────────────────────────────────────────────────────────────
# Directory Validation - Simple Implementation
# ─────────────────────────────────────────────────────────────────────────────

# Validate module directories exist - simple check
# Usage: validate_module_directories "dev"
validate_module_directories() {
    local env="$1"
    
    debug_message "Validating module directories for environment: $env"
    
    if ! is_modules_loaded; then
        handle_error "Modules not loaded. Call load_modules() first"
    fi
    
    local env_path="$(get_environment_path "$env")"
    local missing_modules=()
    
    # Check enabled modules have directories
    while IFS= read -r module; do
        local module_path="$env_path/$module"
        if [[ ! -d "$module_path" ]]; then
            missing_modules+=("$module")
            debug_message "Missing directory for enabled module: $module_path"
        fi
    done < <(get_all_modules)
    
    # Report missing modules
    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        handle_error "Missing directories for enabled modules: ${missing_modules[*]}"
    fi
    
    debug_message "All enabled module directories validated successfully"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

debug_message "Target resolution and exclusion system loaded (DRY KISS implementation)" 