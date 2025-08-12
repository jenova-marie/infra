#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Clean Operations
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Clean cache files, terraform state, and optionally output files
# Author: Infrastructure Management System v2.0
# Last Updated: January 21, 2025

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Clean Operation Execution Functions
# ─────────────────────────────────────────────────────────────────────────────

# Execute clean operation
# Usage: execute_clean_operation
execute_clean_operation() {
    debug_message "Executing clean operation"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Cleaning environment: $OP_ENV, target type: $OP_TARGET_TYPE"
    
    # Get modules to process based on target type
    local modules_to_process=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules_to_process+=("$module")
    done < <(get_modules_for_target "$OP_TARGET_TYPE")
    
    if [[ $(safe_array_length "modules_to_process") -eq 0 ]]; then
        warn_message "No modules found for target: $OP_TARGET_TYPE"
        return 1
    fi
    
    local module_count=$(safe_array_length "modules_to_process")
    
    # Clean global environment files first
    clean_global_environment_files "$OP_ENV"
    
    # Clean module-specific files
    info_message "🧹 Cleaning cache and terraform files for $module_count modules: $(safe_array_elements "modules_to_process" | tr '\n' ' ')"
    
    local success_count=0
    local failed_modules=()
    
    # Process each module - USE SAFE ITERATION
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            if clean_module_files "$OP_ENV" "$module"; then
                success_count=$((success_count + 1))
            else
                failed_modules+=("$module")
            fi
        fi
    done < <(safe_array_iterate "modules_to_process")
    
    # Report results
    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        success_message "🎯 Clean operation completed: $success_count successful"
    else
        warn_message "⚠️  Clean operation completed with failures: $success_count successful, ${#failed_modules[@]} failed"
        warn_message "Failed modules: ${failed_modules[*]}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Clean Implementation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Clean global environment files (logs, state files, outputs directory)
# Usage: clean_global_environment_files "dev"
clean_global_environment_files() {
    local env="$1"
    
    debug_message "Cleaning global environment files for: $env"
    info_message "🧹 Cleaning global environment files for: $env"
    
    local env_path="$(get_environment_path "$env")"
    
    # Clean environment-level terraform files
    clean_environment_terraform_files "$env_path"
    
    # Clean logs directory
    clean_environment_logs "$env_path"
    
    # Clean outputs directory if --outputs flag is used or if it's empty
    if is_outputs; then
        clean_environment_outputs "$env_path"
    else
        debug_message "Outputs cleaning disabled by --no-outputs flag"
    fi
    
    success_message "✅ Cleaned global environment files"
}

# Clean terraform files at environment level
# Usage: clean_environment_terraform_files "/path/to/env"
clean_environment_terraform_files() {
    local env_path="$1"
    
    debug_message "Cleaning environment terraform files in: $env_path"
    
    local files_to_clean=(
        ".terraform"
        ".terraform.lock.hcl"
        "terraform.tfstate"
        "terraform.tfstate.backup"
        ".terragrunt-cache"
    )
    
    for file in "${files_to_clean[@]}"; do
        local file_path="$env_path/$file"
        if [[ -e "$file_path" ]]; then
            execute_with_dry_run "rm -rf '$file_path'" "Would remove: $file_path"
            debug_message "Removed environment file: $file"
        fi
    done
}

# Clean environment logs directory
# Usage: clean_environment_logs "/path/to/env"
clean_environment_logs() {
    local env_path="$1"
    local logs_dir="$env_path/log"
    
    debug_message "Cleaning environment logs in: $logs_dir"
    
    if [[ -d "$logs_dir" ]]; then
        execute_with_dry_run "rm -rf '$logs_dir'" "Would remove logs directory: $logs_dir"
        debug_message "Removed logs directory: $logs_dir"
    fi
}

# Clean environment outputs directory
# Usage: clean_environment_outputs "/path/to/env"
clean_environment_outputs() {
    local env_path="$1"
    local outputs_dir="$env_path/outputs"
    
    debug_message "Cleaning environment outputs in: $outputs_dir"
    
    if [[ -d "$outputs_dir" ]]; then
        execute_with_dry_run "rm -rf '$outputs_dir'" "Would remove outputs directory: $outputs_dir"
        debug_message "Removed outputs directory: $outputs_dir"
    fi
}

# Clean files for a specific module
# Usage: clean_module_files "dev" "athena"
clean_module_files() {
    local env="$1"
    local module="$2"
    
    debug_message "Cleaning files for module: $module"
    
    # Get module path using KISS utilities
    local module_path="$(get_module_path "$env" "$module")"
    
    if [[ ! -d "$module_path" ]]; then
        debug_message "Module directory not found: $module_path"
        return 1
    fi
    
    local cleaned_files=()
    
    # Define files to clean (cache and terraform files always cleaned)
    local cache_files=(
        ".terragrunt-cache"
        ".terraform"
        ".terraform.lock.hcl"
        "terraform.tfstate"
        "terraform.tfstate.backup"
    )
    
    # Clean cache and terraform files
    for file in "${cache_files[@]}"; do
        local file_path="$module_path/$file"
        if [[ -e "$file_path" ]]; then
            execute_with_dry_run "rm -rf '$file_path'" "Would remove: $file_path"
            cleaned_files+=("$(basename "$file")")
            debug_message "Removed from $module: $file"
        fi
    done
    
    # Clean output.json only if --outputs flag is used
    if is_outputs; then
        local output_file="$module_path/output.json"
        if [[ -f "$output_file" ]]; then
            execute_with_dry_run "rm -f '$output_file'" "Would remove: $output_file"
            cleaned_files+=("output.json")
            debug_message "Removed from $module: output.json"
        fi
    fi

    # Clean instance volumes.yml only if --volumes flag is used
    if is_volumes; then
        local volumes_file="$module_path/volumes.yml"
        if [[ -f "$volumes_file" ]]; then
            execute_with_dry_run "rm -f '$volumes_file'" "Would remove: $volumes_file"
            cleaned_files+=("volumes.yml")
            debug_message "Removed from $module: volumes.yml"
        fi
    fi
    
    # Report cleaned files for this module
    if [[ ${#cleaned_files[@]} -gt 0 ]]; then
        success_message "✅ Cleaned from $module: ${cleaned_files[*]}"
    else
        debug_message "No files to clean for module: $module"
    fi
    
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Clean module loaded successfully"
