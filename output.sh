#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Output Management Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Centralized output generation, management, and cleanup
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Core Output Generation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Generate outputs for a single module
# Usage: generate_module_outputs "athena"
generate_module_outputs() {
    local module="$1"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Generating outputs for module: $module"
    
    # Check if module directory exists
    if [[ ! -d "$module" ]]; then
        debug_message "Module directory not found: $module"
        return 1
    fi
    
    # Change to module directory
    local original_dir=$(pwd)
    cd "$module"
    
    # Perform refresh if requested
    if is_refresh; then
        info_message "🔄 Refreshing state for module: $module"
        debug_message "Executing terragrunt refresh for module: $module"
        
        # Use a temporary approach to capture both the output and exit code
        set +e  # Temporarily disable exit on error
        terragrunt refresh 2>&1 | filter_terragrunt_output
        local refresh_exit_code=${PIPESTATUS[0]}
        set -e  # Re-enable exit on error
        
        if [[ $refresh_exit_code -ne 0 ]]; then
            warn_message "Terragrunt refresh failed for module: $module - continuing with output generation"
        else
            debug_message "Terragrunt refresh completed successfully for module: $module"
        fi
    fi
    
    # Generate outputs using simple terragrunt redirect (cleanest approach)
    local output_file="output.json"
    local success=true
    
    debug_message "Generating outputs: terragrunt output --json > $output_file"
        
    # Use simple redirect - terragrunt sends JSON to stdout and logs to stderr
    if terragrunt output --json > "$output_file" 2>/dev/null; then
        # Check if the output file was created and has content (using KISS utility)
        if file_exists_and_has_content "$output_file"; then
            debug_message "Outputs generated successfully for module: $module"
            
            # Copy to centralized location (using KISS variable)
            copy_module_outputs_to_centralized "$module" "$OP_ENV"
        else
            debug_message "No outputs available for module: $module (creating empty JSON for automation)"
            # Create empty JSON object for automation consistency instead of deleting
            echo "{}" > "$output_file"
            
            # Copy to centralized location (empty JSON is still valid)
            copy_module_outputs_to_centralized "$module" "$OP_ENV"
        fi
    else
        debug_message "Terragrunt output command failed for module: $module (creating empty JSON for automation)"
        # Create empty JSON object even on failure for automation consistency
        echo "{}" > "$output_file"
        
        # Copy to centralized location (empty JSON indicates no resources)
        copy_module_outputs_to_centralized "$module" "$OP_ENV"
        success=false
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Generate outputs for a single module (background-safe version)
# Usage: generate_module_outputs_bg "athena" "result_file"
generate_module_outputs_bg() {
    local module="$1"
    local result_file="$2"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Generating outputs for module (background): $module"
    
    # Store original directory and make result_file absolute to prevent module directory pollution
    local original_dir=$(pwd)
    local absolute_result_file="$original_dir/$result_file"
    
    # Check if module directory exists
    if [[ ! -d "$module" ]]; then
        debug_message "Module directory not found: $module"
        echo "FAIL" > "$absolute_result_file"
        return 1
    fi
    
    # Change to module directory
    cd "$module"
    
    # Perform refresh if requested
    if is_refresh; then
        debug_message "Executing terragrunt refresh for module (background): $module"
        
        # Use a temporary approach to capture both the output and exit code
        set +e  # Temporarily disable exit on error
        terragrunt refresh 2>&1 | filter_terragrunt_output
        local refresh_exit_code=${PIPESTATUS[0]}
        set -e  # Re-enable exit on error
        
        if [[ $refresh_exit_code -ne 0 ]]; then
            debug_message "Terragrunt refresh failed for module (background): $module - continuing with output generation"
        else
            debug_message "Terragrunt refresh completed successfully for module (background): $module"
        fi
    fi
    
    # Generate outputs using simple terragrunt redirect (cleanest approach)
    local output_file="output.json"
    local success=true
    
    debug_message "Generating outputs (background): terragrunt output --json > $output_file"
        
    # Use simple redirect - terragrunt sends JSON to stdout and logs to stderr
    if terragrunt output --json > "$output_file" 2>/dev/null; then
        # Check if the output file was created and has content (using KISS utility)
        if file_exists_and_has_content "$output_file"; then
            debug_message "Outputs generated successfully for module (background): $module"
            
            # Copy to centralized location (using KISS variable)
            copy_module_outputs_to_centralized "$module" "$OP_ENV"
            echo "SUCCESS" > "$absolute_result_file"
        else
            debug_message "No outputs available for module (background): $module (creating empty JSON for automation)"
            # Create empty JSON object for automation consistency instead of deleting
            echo "{}" > "$output_file"
            
            # Copy to centralized location (empty JSON is still valid)
            copy_module_outputs_to_centralized "$module" "$OP_ENV"
            echo "SUCCESS" > "$absolute_result_file"
        fi
    else
        debug_message "Terragrunt output command failed for module (background): $module (creating empty JSON for automation)"
        # Create empty JSON object even on failure for automation consistency
        echo "{}" > "$output_file"
        
        # Copy to centralized location (empty JSON indicates no resources)
        copy_module_outputs_to_centralized "$module" "$OP_ENV"
        echo "SUCCESS" > "$absolute_result_file"
        success=false
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Copy module outputs to centralized location
# Usage: copy_module_outputs_to_centralized "athena" "dev"
copy_module_outputs_to_centralized() {
    local module="$1"
    local env="$2"
    
    debug_message "Copying outputs to centralized location for module: $module"
    
    # Use KISS utility functions for standardized paths
    local module_output_file="$(get_module_path "$env" "$module")/output.json"
    local centralized_file="$(get_module_output_path "$env" "$module")"
    
    # Ensure centralized outputs directory exists using KISS function
    ensure_output_directory "$env"
    
    # Copy outputs if they exist
    if file_exists_and_readable "$module_output_file"; then
        execute_with_dry_run "cp '$module_output_file' '$centralized_file'" "Would copy outputs: $module_output_file -> $centralized_file"
        if ! is_dry_run; then
            debug_message "Copied outputs: $module_output_file -> $centralized_file"
        fi
    else
        debug_message "No outputs file to copy for module: $module"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Parallel Output Generation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Generate outputs for multiple modules in parallel
# Usage: generate_outputs_parallel "module1" "module2" "module3"
generate_outputs_parallel() {
    debug_message "Generating outputs in parallel for modules"
    
    # Convert arguments to array safely
    local modules=("$@")
    
    if [[ $(safe_array_length "modules") -eq 0 ]]; then
        debug_message "No modules provided for parallel generation"
        return 0
    fi
    
    info_message "🚀 Generating outputs for $(safe_array_length "modules") module(s) in parallel..."
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    # Track result files for cleanup
    local result_files=()
    
    # Start background processes for each module - USE SAFE ITERATION
    local pids=()
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            debug_message "Starting parallel output generation for module: $module"
            
            # Create unique result file for this module
            local result_file="$OP_ENV.$module.result"
            result_files+=("$result_file")
            
            # Start generation in background and capture PID
            (
                if generate_module_outputs_bg "$module" "$result_file"; then
                    success_message "✅ Generated output for module: $module"
                else
                    warn_message "⚠️  Failed to generate output for module: $module"
                fi
            ) &
            pids+=($!)
        fi
    done < <(safe_array_iterate "modules")
    
    # Wait for all background processes to complete - USE SAFE ITERATION
    debug_message "Waiting for $(safe_array_length "pids") parallel processes to complete"
    
    local wait_count=0
    while IFS= read -r pid; do
        if [[ -n "$pid" ]]; then
            wait "$pid"
            ((wait_count++))
        fi
    done < <(safe_array_iterate "pids")
    
    # Clean up temporary result files
    debug_message "Cleaning up temporary result files"
    for result_file in "${result_files[@]}"; do
        if [[ -f "$result_file" ]]; then
            rm -f "$result_file"
            debug_message "Removed temporary file: $result_file"
        fi
    done
    
    # Also clean up any stray result files in module directories (from previous buggy runs)
    cleanup_stray_result_files $(safe_array_elements "modules")
    
    success_message "🎉 Parallel output generation completed for $wait_count module(s)"
}

# Generate outputs for multiple modules sequentially
# Usage: generate_outputs_sequential "module1" "module2" "module3"
generate_outputs_sequential() {
    debug_message "Generating outputs sequentially for modules"
    
    # Convert arguments to array safely
    local modules=("$@")
    
    if [[ $(safe_array_length "modules") -eq 0 ]]; then
        debug_message "No modules provided for sequential generation"
        return 0
    fi
    
    # Generate outputs one by one - USE SAFE ITERATION
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            debug_message "Generating output for module: $module"
            
            if generate_module_outputs "$module"; then
                success_message "✅ Generated output for module: $module"
            else
                warn_message "⚠️  Failed to generate output for module: $module"
            fi
        fi
    done < <(safe_array_iterate "modules")
    
    debug_message "Sequential output generation completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Output Cleanup Functions
# ─────────────────────────────────────────────────────────────────────────────

# Clean up output files for destroyed modules
# Usage: cleanup_destroyed_module_outputs "target_type"
cleanup_destroyed_module_outputs() {
    local target_type="$1"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Removing output files for destroyed modules"
    
    # Get target modules that were processed
    local processed_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && processed_modules+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    if [[ ${#processed_modules[@]} -eq 0 ]]; then
        debug_message "No modules to remove outputs for"
        return 0
    fi
    
    info_message "🗑️  Removing output files for ${#processed_modules[@]} destroyed modules"
    
    # Remove output files for each destroyed module
    local processed_count=0
    
    for module in "${processed_modules[@]}"; do
        # Use KISS utilities for standardized paths
        local module_output_file="$(get_module_path "$OP_ENV" "$module")/output.json"
        local centralized_file="$(get_module_output_path "$OP_ENV" "$module")"
        local files_removed=0
        
        # Remove local output.json file
        if [[ -f "$module_output_file" ]]; then
            execute_with_dry_run "rm -f '$module_output_file'" "Would remove output file: $module_output_file"
            if ! is_dry_run; then
                debug_message "Removed local output file: $module_output_file"
            fi
            ((files_removed++))
        fi
        
        # Remove centralized output file
        if [[ -f "$centralized_file" ]]; then
            execute_with_dry_run "rm -f '$centralized_file'" "Would remove centralized output: $centralized_file"
            if ! is_dry_run; then
                debug_message "Removed centralized output file: $centralized_file"
            fi
            ((files_removed++))
        fi
        
        if [[ $files_removed -gt 0 ]]; then
            debug_message "Removed output files for module: $module"
            ((processed_count++))
        fi
    done
    
    if [[ $processed_count -gt 0 ]]; then
        if is_dry_run; then
            dry_run_message "Would remove output files for $processed_count modules"
        else
            success_message "✅ Removed output files for $processed_count destroyed modules"
        fi
    else
        debug_message "No output files to remove"
    fi
    
    debug_message "Output file removal completed"
    return 0
}

# Validate and maintain output file consistency
# Usage: validate_output_files "target_type"
validate_output_files() {
    local target_type="$1"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Validating output file consistency"
    
    # Get target modules - USE SAFE ARRAY BUILDING
    local target_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && target_modules+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    if [[ $(safe_array_length "target_modules") -eq 0 ]]; then
        debug_message "No modules to validate outputs for"
        return 0
    fi
    
    info_message "🔍 Validating output file consistency for automation..."
    
    local validation_count=0
    
    # USE SAFE ARRAY ITERATION
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            # Use KISS utilities for standardized paths
            local module_output_file="$(get_module_path "$OP_ENV" "$module")/output.json"
            local centralized_file="$(get_module_output_path "$OP_ENV" "$module")"
            
            # Ensure both local and centralized output files exist (create empty JSON if missing)
            if [[ ! -f "$module_output_file" ]]; then
                execute_with_dry_run "ensure_directory '$(dirname "$module_output_file")' && echo '{}' > '$module_output_file'" "Would create missing output file: $module_output_file"
                if ! is_dry_run; then
                    debug_message "Created missing local output file: $module_output_file"
                fi
                ((validation_count++))
            fi
            
            if [[ ! -f "$centralized_file" ]]; then
                execute_with_dry_run "ensure_directory '$(dirname "$centralized_file")' && echo '{}' > '$centralized_file'" "Would create missing centralized output: $centralized_file"
                if ! is_dry_run; then
                    debug_message "Created missing centralized output file: $centralized_file"
                fi
                ((validation_count++))
            fi
        fi
    done < <(safe_array_iterate "target_modules")
    
    if [[ $validation_count -gt 0 ]]; then
        if is_dry_run; then
            dry_run_message "Would validate and create $validation_count missing output files"
        else
            success_message "✅ Validated and created $validation_count missing output files for automation consistency"
        fi
    else
        debug_message "All output files are consistent and present"
    fi
    
    debug_message "Output file validation completed"
    return 0
}

# Clean up stray result files from module directories (from previous buggy runs)
# Usage: cleanup_stray_result_files "module1" "module2" "module3"
cleanup_stray_result_files() {
    local modules=("$@")
    
    if [[ ${#modules[@]} -eq 0 ]]; then
        debug_message "No modules provided for stray result file cleanup"
        return 0
    fi
    
    debug_message "Cleaning up stray result files from module directories and terragrunt cache"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    local cleaned_count=0
    
    # Check each module directory for stray result files
    for module in "${modules[@]}"; do
        if [[ -n "$module" && -d "$module" ]]; then
            # Look for any .result files in the module directory
            local result_pattern="$module/*.result"
            if compgen -G "$result_pattern" > /dev/null 2>&1; then
                for stray_file in $module/*.result; do
                    if [[ -f "$stray_file" ]]; then
                        rm -f "$stray_file"
                        debug_message "Removed stray result file: $stray_file"
                        ((cleaned_count++))
                    fi
                done
            fi
            
            # Also clean up terragrunt cache directories within this module
            if [[ -d "$module/.terragrunt-cache" ]]; then
                local cache_result_files=$(find "$module/.terragrunt-cache" -name "*.result" -type f 2>/dev/null || true)
                if [[ -n "$cache_result_files" ]]; then
                    while IFS= read -r cache_file; do
                        if [[ -f "$cache_file" ]]; then
                            rm -f "$cache_file"
                            debug_message "Removed cached result file: $cache_file"
                            ((cleaned_count++))
                        fi
                    done <<< "$cache_result_files"
                fi
            fi
        fi
    done
    
    if [[ $cleaned_count -gt 0 ]]; then
        debug_message "Cleaned up $cleaned_count stray result files from module directories and cache"
    else
        debug_message "No stray result files found in module directories or cache"
    fi
    
    return 0
}

# Global cleanup of all stray result files in the entire environment
# Usage: cleanup_all_stray_result_files "env"
cleanup_all_stray_result_files() {
    local env="${1:-$OP_ENV}"
    
    debug_message "Performing global cleanup of all stray result files in environment: $env"
    
    local env_path="$(get_environment_path "$env")"
    local cleaned_count=0
    
    if [[ ! -d "$env_path" ]]; then
        debug_message "Environment path not found: $env_path"
        return 0
    fi
    
    # Find and remove all .result files in the environment
    local all_result_files=$(find "$env_path" -name "*.result" -type f 2>/dev/null || true)
    
    if [[ -n "$all_result_files" ]]; then
        while IFS= read -r result_file; do
            if [[ -f "$result_file" ]]; then
                rm -f "$result_file"
                debug_message "Removed global stray result file: $result_file"
                ((cleaned_count++))
            fi
        done <<< "$all_result_files"
    fi
    
    if [[ $cleaned_count -gt 0 ]]; then
        info_message "🧹 Cleaned up $cleaned_count stray result files from environment: $env"
    else
        debug_message "No stray result files found in environment: $env"
    fi
    
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# High-Level Output Operations
# ─────────────────────────────────────────────────────────────────────────────

# Execute output generation operation
# Usage: execute_output_operation
execute_output_operation() {
    # Check if this is a clean operation first
    if is_clean; then
        local target_type=$(get_target_type)
        debug_message "Clean flag detected - removing output files for target: $target_type"
        
        if is_dry_run; then
            dry_run_message "[DRY-RUN] Would clean output files for target: $target_type"
            return 0
        fi
        
        clean_output_files "$target_type"
        return $?
    fi
    
    # Check if we should skip output generation in dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would generate outputs for target: $(get_target_type)"
        return 0
    fi
    
    # Get target type and generate outputs
    local target_type=$(get_target_type)
    
    debug_message "Starting output generation for target: $target_type"
    
    # Get modules to generate outputs for - USE SAFE ARRAY BUILDING
    local modules_to_process=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules_to_process+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    if [[ $(safe_array_length "modules_to_process") -eq 0 ]]; then
        warn_message "No modules found for target: $target_type"
        return 1
    fi
    
    # Choose strategy based on number of modules
    if [[ $(safe_array_length "modules_to_process") -le 3 ]]; then
        # Sequential processing for small number of modules
        info_message "🔄 Generating outputs for $(safe_array_length "modules_to_process") module(s) sequentially..."
        generate_outputs_sequential $(safe_array_elements "modules_to_process")
    else
        # Parallel processing for larger number of modules
        generate_outputs_parallel $(safe_array_elements "modules_to_process")
    fi
    
    # Generate consolidated IPs file if we have relevant modules (EIPs or instances) - USE SAFE ITERATION
    local needs_ip_consolidation=false
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            if [[ "$module" == "eips" ]]; then
                needs_ip_consolidation=true
                break
            fi
            # Check if module is an instance module
            local module_type=$(get_module_type "$module")
            if [[ "$module_type" == "instance" ]]; then
                needs_ip_consolidation=true
                break
            fi
        fi
    done < <(safe_array_iterate "modules_to_process")
    
    if [[ "$needs_ip_consolidation" == true ]]; then
        debug_message "Generating consolidated IPs file due to EIPs or instance modules processing"
        generate_consolidated_ips_file "$OP_ENV"
    else
        debug_message "Skipping consolidated IPs file generation (no relevant modules processed)"
    fi
    
    # Perform proactive cleanup of stray result files
    debug_message "Performing post-operation cleanup of stray result files"
    cleanup_all_stray_result_files "$OP_ENV"
}

# Clean output files for target
# Usage: clean_output_files "infrastructure"
clean_output_files() {
    local target_type="$1"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    debug_message "Cleaning output files for target: $target_type"
    
    # Use KISS utility for environment path
    local outputs_dir="$OP_ENV_PATH/outputs"
    
    # Check if outputs directory exists
    if [[ ! -d "$outputs_dir" ]]; then
        info_message "No outputs directory found at: $outputs_dir"
        return 0
    fi
    
    # Get modules to clean outputs for - USE SAFE ARRAY BUILDING
    local modules_to_clean=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules_to_clean+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    if [[ $(safe_array_length "modules_to_clean") -eq 0 ]]; then
        warn_message "No modules found for target: $target_type"
        return 1
    fi
    
    local cleaned_count=0
    
    info_message "🧹 Cleaning output files for $(safe_array_length "modules_to_clean") module(s)..."
    
    # USE SAFE ARRAY ITERATION
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            # Use KISS utility for output path (using KISS variable)
            local output_file="$(get_module_output_path "$OP_ENV" "$module")"
            
            if file_exists_and_readable "$output_file"; then
                if is_dry_run; then
                    dry_run_message "[DRY-RUN] Would remove: $output_file"
                else
                    rm -f "$output_file"
                    debug_message "Removed output file: $output_file"
                fi
                ((cleaned_count++))
            fi
        fi
    done < <(safe_array_iterate "modules_to_clean")
    
    if [[ $cleaned_count -gt 0 ]]; then
        success_message "🧹 Cleaned $cleaned_count output file(s)"
    else
        info_message "No output files found to clean"
    fi
    
    return 0
}

# Execute automatic output generation after state-modifying operations
# Usage: execute_automatic_output_generation
execute_automatic_output_generation() {
    local target_type=$(get_target_type)
    
    debug_message "Executing automatic output generation"
    log_phase "Generating outputs (automatic)"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would execute automatic output generation for target: $target_type"
        info_message "ℹ️  [DRY-RUN] Automatic output generation would complete successfully"
        return 0
    fi
    
    # Get modules that were processed
    local processed_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && processed_modules+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    if [[ ${#processed_modules[@]} -eq 0 ]]; then
        debug_message "No modules to generate outputs for"
        return 0
    fi
    
    info_message "Automatically generating outputs for ${#processed_modules[@]} processed modules"
    
    # CRITICAL: Enable refresh for automatic output generation to avoid stale state
    # This prevents race conditions where EIP associations haven't propagated yet
    local original_refresh_flag="$REFRESH"
    REFRESH=true
    export REFRESH
    
    debug_message "Enabled refresh for automatic output generation to ensure fresh state"
    
    # Generate outputs in parallel for better performance
    generate_outputs_parallel "${processed_modules[@]}"
    
    # Generate consolidated IPs file if we have relevant modules (EIPs or instances)
    local needs_ip_consolidation=false
    for module in "${processed_modules[@]}"; do
        if [[ "$module" == "eips" ]]; then
            needs_ip_consolidation=true
            break
        fi
        # Check if module is an instance module
        local module_type=$(get_module_type "$module")
        if [[ "$module_type" == "instance" ]]; then
            needs_ip_consolidation=true
            break
        fi
    done
    
    if [[ "$needs_ip_consolidation" == true ]]; then
        debug_message "Generating consolidated IPs file due to EIPs or instance modules processing"
        generate_consolidated_ips_file "$OP_ENV"
    else
        debug_message "Skipping consolidated IPs file generation (no relevant modules processed)"
    fi
    
    # Restore original refresh flag
    REFRESH="$original_refresh_flag"
    export REFRESH
    
    debug_message "Restored original refresh flag: $original_refresh_flag"
}

# ─────────────────────────────────────────────────────────────────────────────
# IP Consolidation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Generate consolidated IPs file combining EIPs and public IPs
# Usage: generate_consolidated_ips_file "dev"
generate_consolidated_ips_file() {
    local env="$1"
    
    debug_message "Generating consolidated IPs file for environment: $env"
    
    # Use KISS approach - get operation context for consistent environment access
    get_operation_context
    
    local env_path="$OP_ENV_PATH"
    local ips_output_file="$env_path/outputs/ips.json"
    local eips_output_file="$env_path/outputs/eips.json"
    local modules_file="$env_path/modules.yml"
    local temp_ips_file="/tmp/ips_consolidation_$$"
    
    # Step 1: Read existing EIPs (already in [instance]-[env] format)
    if [[ -f "$eips_output_file" ]]; then
        debug_message "Reading EIPs from: $eips_output_file"
        
        # Extract EIP addresses and write to temp file
        jq -r '.eip_addresses.value // {} | to_entries[] | "\(.key)=\(.value)"' "$eips_output_file" 2>/dev/null > "$temp_ips_file" || touch "$temp_ips_file"
    else
        debug_message "No EIPs file found at: $eips_output_file"
        touch "$temp_ips_file"
    fi
    
    # Step 2: Read modules.yml to get active instances
    if [[ -f "$modules_file" ]]; then
        debug_message "Reading instances from: $modules_file"
        
        # Get list of active instances and process public IPs
        while IFS= read -r instance; do
            if [[ -n "$instance" ]]; then
                local instance_output_file="$env_path/outputs/$instance.json"
                local instance_key="${instance}-${env}"
                
                if [[ -f "$instance_output_file" ]]; then
                    # Extract public IP for this instance
                    local public_ip=$(jq -r --arg instance "$instance" '.public_ips.value[$instance] // empty' "$instance_output_file" 2>/dev/null || echo "")
                    
                    if [[ -n "$public_ip" && "$public_ip" != "null" && "$public_ip" != "empty" ]]; then
                        # Check if EIP already exists for this key
                        if ! grep -q "^${instance_key}=" "$temp_ips_file" 2>/dev/null; then
                            # Add public IP (EIPs take precedence, so only add if not exists)
                            echo "${instance_key}=${public_ip}" >> "$temp_ips_file"
                            debug_message "Added public IP: $instance_key -> $public_ip"
                        else
                            local existing_ip=$(grep "^${instance_key}=" "$temp_ips_file" | cut -d'=' -f2)
                            debug_message "Skipped public IP for $instance_key (EIP takes precedence): $existing_ip"
                        fi
                    else
                        debug_message "No public IP found for instance: $instance"
                    fi
                else
                    debug_message "Instance output file not found: $instance_output_file"
                fi
            fi
        done < <(yq eval '.instances[]' "$modules_file" 2>/dev/null || true)
    else
        debug_message "No modules file found at: $modules_file"
    fi
    
    # Step 3: Generate consolidated ips.json file
    local ip_count=$(wc -l < "$temp_ips_file" 2>/dev/null || echo "0")
    ip_count=$(echo "$ip_count" | tr -d ' ')  # Remove whitespace
    
    if [[ "$ip_count" -eq 0 ]]; then
        # Create empty structure for consistency
        local json_content='{"ip_addresses": {"sensitive": false, "type": ["object", {}], "value": {}}}'
        debug_message "No IP addresses found, creating empty ips.json"
    else
        # Build JSON structure
        debug_message "Building JSON structure for $ip_count IP addresses"
        
        # Start building the JSON content
        local json_content='{"ip_addresses": {"sensitive": false, "type": ["object", {}], "value": {'
        local first=true
        
        # Read from temp file and build JSON
        while IFS='=' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                if [[ "$first" == true ]]; then
                    first=false
                else
                    json_content+=','
                fi
                json_content+="\"$key\": \"$value\""
                debug_message "Added to JSON: $key -> $value"
            fi
        done < "$temp_ips_file"
        
        json_content+='}}}'
    fi
    
    # Step 4: Write to ips.json file
    execute_with_dry_run "echo '$json_content' | jq '.' > '$ips_output_file'" "Would create consolidated IPs file: $ips_output_file"
    
    if ! is_dry_run; then
        echo "$json_content" | jq '.' > "$ips_output_file"
        debug_message "Consolidated IPs file created: $ips_output_file"
        
        # Log the final result
        if [[ "$ip_count" -gt 0 ]]; then
            info_message "📍 Generated consolidated IPs file with $ip_count addresses: $(basename "$ips_output_file")"
        else
            info_message "📍 Generated empty consolidated IPs file: $(basename "$ips_output_file")"
        fi
    else
        dry_run_message "Would generate consolidated IPs file with $ip_count addresses"
    fi
    
    # Cleanup temp file
    rm -f "$temp_ips_file"
    
    debug_message "Consolidated IPs file generation completed"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Output module loaded successfully - debug_message not available yet 

# Clean output files that match the target pattern
# Usage: clean_target_outputs "all" -> cleans all output files
clean_target_outputs() {
    local target_type="$1"
    
    debug_message "Cleaning output files for target: $target_type"
    
    # Get modules to clean based on target
    local modules_to_clean=()
    case "$target_type" in
        "all")
            # Clean all module outputs
            while IFS= read -r module; do
                if [[ -n "$module" ]]; then
                    modules_to_clean+=("$module")
                fi
            done < <(get_all_modules)
            ;;
        "infrastructure")
            # Clean infrastructure module outputs
            while IFS= read -r module; do
                if [[ -n "$module" ]]; then
                    modules_to_clean+=("$module")
                fi
            done < <(get_infrastructure_modules)
            ;;
        "instances")
            # Clean instance module outputs
            while IFS= read -r module; do
                if [[ -n "$module" ]]; then
                    modules_to_clean+=("$module")
                fi
            done < <(get_instance_modules)
            ;;
        *)
            # Clean single module output
            if is_module_enabled "$target_type"; then
                modules_to_clean+=("$target_type")
            else
                warn_message "Module '$target_type' is not enabled, skipping cleanup"
                return 0
            fi
            ;;
    esac
    
    if [[ $(safe_array_length "modules_to_clean") -eq 0 ]]; then
        debug_message "No modules to clean for target: $target_type"
        return 0
    fi
    
    info_message "🧹 Cleaning output files for $(safe_array_length "modules_to_clean") module(s)..."
    
    local cleaned_count=0
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            local output_file="$(get_module_output_path "$OP_ENV" "$module")"
            
            if [[ -f "$output_file" ]]; then
                execute_with_dry_run "rm -f '$output_file'" "Would remove output file: $output_file"
                if [[ ! is_dry_run ]]; then
                    debug_message "Cleaned output file: $output_file"
                    ((cleaned_count++))
                fi
            else
                debug_message "Output file not found (already clean): $output_file"
            fi
        fi
    done < <(safe_array_iterate "modules_to_clean")
    
    if [[ $cleaned_count -gt 0 ]]; then
        success_message "🧹 Cleaned $cleaned_count output file(s)"
    else
        debug_message "No output files needed cleaning"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Output Data Access API Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get AWS region for a specific instance from its outputs
# Usage: get_instance_aws_region_from_outputs "dev" "athena"
get_instance_aws_region_from_outputs() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Getting AWS region for instance: $instance_name from outputs"
    
    # Use KISS utility for standardized path construction
    local instance_output_file="$(get_module_output_path "$env" "$instance_name")"
    
    # Strict validation - instance outputs must exist
    if ! file_exists_and_readable "$instance_output_file"; then
        handle_error "Instance outputs not found: $instance_output_file. Run: ./infra output $env:$instance_name"
    fi
    
    debug_message "Reading AWS region from: $instance_output_file"
    
    # Extract aws_region from instance outputs
    local aws_region=$(jq -r '.aws_region.value // empty' "$instance_output_file" 2>/dev/null)
    
    if [[ -n "$aws_region" && "$aws_region" != "null" ]]; then
        debug_message "Found AWS region for $instance_name: $aws_region"
        echo "$aws_region"
        return 0
    fi
    
    handle_error "Could not get AWS region for instance: $instance_name from outputs"
}

# Get instance ID for a specific instance from its outputs  
# Usage: get_instance_id_from_outputs "dev" "athena"
get_instance_id_from_outputs() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Getting instance ID for: $instance_name from outputs"
    
    # Use KISS utility for standardized path construction
    local instance_output_file="$(get_module_output_path "$env" "$instance_name")"
    
    if ! file_exists_and_readable "$instance_output_file"; then
        debug_message "Instance outputs file does not exist: $instance_output_file"
        return 1
    fi
    
    # Try multiple potential keys since JSON structure can vary
    local instance_id=""
    
    # Method 1: Try direct instance name key
    if instance_id=$(jq -r --arg instance_name "$instance_name" '.instance_ids.value[$instance_name] // empty' "$instance_output_file" 2>/dev/null) && [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
        debug_message "Found instance ID using direct key '$instance_name': $instance_id"
        echo "$instance_id"
        return 0
    fi
    
    # Method 2: Try with environment suffix (e.g., "athena-dev")
    local key_with_env="${instance_name}-${env}"
    if instance_id=$(jq -r --arg key "$key_with_env" '.instance_ids.value[$key] // empty' "$instance_output_file" 2>/dev/null) && [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
        debug_message "Found instance ID using environment key '$key_with_env': $instance_id"
        echo "$instance_id"
        return 0
    fi
    
    # Method 3: Try the first available instance ID if only one exists
    if instance_id=$(jq -r '.instance_ids.value | to_entries[0].value // empty' "$instance_output_file" 2>/dev/null) && [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
        debug_message "Found single instance ID (first available): $instance_id"
        echo "$instance_id"
        return 0
    fi
    
    debug_message "Could not get instance ID for instance: $instance_name"
    return 1
}

# Get volume ID for a specific volume from EBS outputs
# Usage: get_volume_id_from_outputs "dev" "athena-blog"
get_volume_id_from_outputs() {
    local env="$1"
    local volume_name="$2"
    
    debug_message "Getting volume ID for $volume_name from EBS outputs"
    
    # Use KISS utility for standardized path construction - EBS outputs are in ebss module
    local ebs_outputs_file="$(get_module_output_path "$env" "ebss")"
    
    # Strict validation - centralized outputs must exist
    if ! file_exists_and_readable "$ebs_outputs_file"; then
        handle_error "EBS outputs not found: $ebs_outputs_file. Run: ./infra output $env:ebss"
    fi
    
    debug_message "Reading volume ID from: $ebs_outputs_file"
    
    # Extract volume ID
    local volume_id=$(jq -r --arg volume_name "$volume_name" '
        .volume_ids.value[$volume_name] // empty
    ' "$ebs_outputs_file" 2>/dev/null)
    
    if [[ -n "$volume_id" && "$volume_id" != "null" ]]; then
        debug_message "Found volume ID: $volume_id"
        echo "$volume_id"
        return 0
    fi
    
    handle_error "Could not get volume ID for volume name: $volume_name in EBS outputs"
} 