#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Cache Management Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Terragrunt cache cleaning and management
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Cache Cleaning Operations
# ─────────────────────────────────────────────────────────────────────────────

# Execute clean operation - removes cache, output files, logs, and terraform state
# Usage: execute_clean_operation
execute_clean_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    log_phase "Cleaning terragrunt cache, outputs, logs, and terraform state"
    
    local env_path="$(get_environment_path "$OP_ENV")"
    
    # KISS: Always clean global environment files (outputs/, logs/, .terraform*)
    info_message "🧹 Cleaning global environment files for: $OP_ENV"
    
    # Remove global environment folders and terraform state files
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would remove: $env_path/log/"
        is_outputs && dry_run_message "[DRY-RUN] Would remove: $env_path/outputs/"
        dry_run_message "[DRY-RUN] Would remove: $env_path/.terraform*"
        [[ -f "$env_path/terraform.tfstate" ]] && dry_run_message "[DRY-RUN] Would remove: $env_path/terraform.tfstate"
        [[ -f "$env_path/terraform.tfstate.backup" ]] && dry_run_message "[DRY-RUN] Would remove: $env_path/terraform.tfstate.backup"
    else
        rm -rf "$env_path/log" 2>/dev/null || true
        is_outputs && rm -rf "$env_path/outputs" 2>/dev/null || true
        rm -rf "$env_path"/.terraform* 2>/dev/null || true
        rm -f "$env_path/terraform.tfstate" 2>/dev/null || true
        rm -f "$env_path/terraform.tfstate.backup" 2>/dev/null || true
        info_message "✅ Cleaned global environment files"
    fi
    
    # Get target modules for module-specific cleaning
    local target_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && target_modules+=("$module")
    done < <(get_modules_for_target "$OP_TARGET_TYPE")
    
    if ! safe_array_has_elements "target_modules"; then
        warn_message "No modules found for target: $OP_TARGET_TYPE"
        return 0
    fi
    
    info_message "🧹 Cleaning cache and output files for $(safe_array_length "target_modules") modules: $(safe_array_string "target_modules")"
    
    # Clean cache and output files for each module
    local success_count=0
    local failure_count=0
    
    while IFS= read -r module; do
        log_module_processing "$module" "start" "Cleaning files"
        
        if clean_module_files "$module"; then
            log_module_processing "$module" "success" "Files cleaned"
            ((success_count++))
        else
            log_module_processing "$module" "error" "File cleaning failed"
            ((failure_count++))
        fi
    done < <(safe_array_iterate "target_modules")
    
    # Report results
    if [[ $failure_count -eq 0 ]]; then
        success_message "🎯 Clean operation completed: $success_count successful"
    else
        warn_message "⚠️ Clean operation completed: $success_count successful, $failure_count failed"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Cache Management
# ─────────────────────────────────────────────────────────────────────────────

# Clean cache, output files, and terraform state for a single module (KISS approach)
# Usage: clean_module_files "athena"
clean_module_files() {
    local module="$1"
    
    # Change to module directory
    local original_dir=$(pwd)
    cd "$module"
    
    local success=true
    
    # KISS: Remove files with simple commands
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would remove in $module:"
        [[ -d ".terragrunt-cache" ]] && dry_run_message "[DRY-RUN]   .terragrunt-cache/"
        is_outputs && [[ -f "output.json" ]] && dry_run_message "[DRY-RUN]   output.json"
        [[ -d ".terraform" ]] && dry_run_message "[DRY-RUN]   .terraform/"
        [[ -f ".terraform.lock.hcl" ]] && dry_run_message "[DRY-RUN]   .terraform.lock.hcl"
        [[ -f "terraform.tfstate" ]] && dry_run_message "[DRY-RUN]   terraform.tfstate"
        [[ -f "terraform.tfstate.backup" ]] && dry_run_message "[DRY-RUN]   terraform.tfstate.backup"
    else
        local removed_items=()
        
        # Remove .terragrunt-cache directories
        if [[ -d ".terragrunt-cache" ]]; then
            if rm -rf .terragrunt-cache 2>/dev/null; then
                removed_items+=(".terragrunt-cache/")
            else
                success=false
            fi
        fi
        
        # Remove output.json files (handle both symlinks and actual files)
        if is_outputs && [[ -f "output.json" ]]; then
            if rm -f output.json 2>/dev/null; then
                removed_items+=("output.json")
            else
                success=false
            fi
        fi
        
        # Remove .terraform directories and lock files
        if [[ -d ".terraform" ]]; then
            if rm -rf .terraform 2>/dev/null; then
                removed_items+=(".terraform/")
            else
                success=false
            fi
        fi
        
        if [[ -f ".terraform.lock.hcl" ]]; then
            if rm -f .terraform.lock.hcl 2>/dev/null; then
                removed_items+=(".terraform.lock.hcl")
            else
                success=false
            fi
        fi
        
        # Remove terraform.tfstate files (local state files)
        if [[ -f "terraform.tfstate" ]]; then
            if rm -f terraform.tfstate 2>/dev/null; then
                removed_items+=("terraform.tfstate")
            else
                success=false
            fi
        fi
        
        if [[ -f "terraform.tfstate.backup" ]]; then
            if rm -f terraform.tfstate.backup 2>/dev/null; then
                removed_items+=("terraform.tfstate.backup")
            else
                success=false
            fi
        fi
        
        # Report what was cleaned
        if [[ ${#removed_items[@]} -gt 0 ]]; then
            info_message "✅ Cleaned from $module: ${removed_items[*]}"
        fi
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}