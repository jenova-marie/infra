#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Shutdown Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Infrastructure recreation operations - destroy → apply → output
# Author: Infrastructure Management System v2.0
# Last Updated: January 3, 2025

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Main Shutdown Operation
# ─────────────────────────────────────────────────────────────────────────────

# Execute shutdown operation
# Usage: execute_shutdown_operation
execute_shutdown_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Executing shutdown operation for target: $OP_TARGET_TYPE"
    
    # Check if bounce flag is enabled - if so, do destroy→apply→output sequence
    if is_bounce; then
        debug_message "Bounce flag enabled - executing infrastructure recreation sequence"
        
        # Determine target instances for bounce operation
        local instances=()
        while IFS= read -r instance; do
            [[ -n "$instance" ]] && instances+=("$instance")
        done < <(get_modules_for_target "$OP_TARGET_TYPE")
        
        if [[ ${#instances[@]} -eq 0 ]]; then
            handle_error "No instances found for bounce target: $OP_TARGET_TYPE"
        fi
        
        # Execute the enhanced bounce operation with proper state handling
        execute_bounce_operation "$OP_ENV" "$OP_TARGET_TYPE" "${instances[@]}"
        return $?
    fi
    
    # Check if reboot flag is enabled - infrastructure recreation for restart
    if is_reboot; then
        debug_message "Reboot flag enabled - executing infrastructure recreation for restart"
        
        # Determine target instances for reboot operation
        local instances=()
        while IFS= read -r instance; do
            [[ -n "$instance" ]] && instances+=("$instance")
        done < <(get_modules_for_target "$OP_TARGET_TYPE")
        
        if [[ ${#instances[@]} -eq 0 ]]; then
            handle_error "No instances found for reboot target: $OP_TARGET_TYPE"
        fi
        
        info_message "🔄 Starting infrastructure recreation for restart of ${#instances[@]} instance(s)"
        
        # Execute bounce operation (same as bounce flag)
        execute_bounce_operation "$OP_ENV" "$OP_TARGET_TYPE" "${instances[@]}"
        
        # Finalize shutdown operation
        finalize_shutdown_operation "Infrastructure recreation restart completed"
        return $?
    fi
    
    # Check if flush flag is enabled - infrastructure recreation for cleanup
    if is_flush; then
        debug_message "Flush flag enabled - executing infrastructure recreation for cleanup"
        
        # Determine target instances for flush operation
        local instances=()
        while IFS= read -r instance; do
            [[ -n "$instance" ]] && instances+=("$instance")
        done < <(get_modules_for_target "$OP_TARGET_TYPE")
        
        if [[ ${#instances[@]} -eq 0 ]]; then
            handle_error "No instances found for flush target: $OP_TARGET_TYPE"
        fi
        
        info_message "🧹 Starting infrastructure recreation for cleanup of ${#instances[@]} instance(s)"
        
        # Execute bounce operation (same as bounce flag)
        execute_bounce_operation "$OP_ENV" "$OP_TARGET_TYPE" "${instances[@]}"
        
        # Finalize shutdown operation
        finalize_shutdown_operation "Infrastructure recreation cleanup completed"
        return $?
    fi
    
    # Default mode: Infrastructure recreation (destroy → apply → output)
    debug_message "Executing infrastructure recreation operation"
    log_phase "Infrastructure recreation operation"
    
    # Determine target instances
    local instances=()
    while IFS= read -r instance; do
        [[ -n "$instance" ]] && instances+=("$instance")
    done < <(get_modules_for_target "$OP_TARGET_TYPE")
    
    if [[ ${#instances[@]} -eq 0 ]]; then
        handle_error "No instances found for target: $OP_TARGET_TYPE"
    fi
    
    info_message "🔄 Starting infrastructure recreation for ${#instances[@]} instance(s)"
    
    # Execute infrastructure recreation (same as bounce operation)
    execute_bounce_operation "$OP_ENV" "$OP_TARGET_TYPE" "${instances[@]}"
    
    # Finalize shutdown operation
    finalize_shutdown_operation "Infrastructure recreation operation completed"
}

# Execute bounce sequence (destroy → apply → output)
# Usage: execute_bounce_sequence "instances"
execute_bounce_sequence() {
    local target_type="$1"
    
    debug_message "Executing bounce sequence for target: $target_type"
    log_phase "Bounce sequence: destroy → apply → output"
    
    info_message "🔄 Starting bounce sequence: destroy → apply → output"
    
    # Step 1: Execute destroy using standard operation logic
    info_message "🗑️  Step 1/3: Destroying target infrastructure..."
    log_phase "Bounce: Executing destroy"
    
    local env=$(get_environment)
    if execute_standard_operation_with_params "destroy" "$env" "$target_type"; then
        success_message "✅ Destroy phase completed"
    else
        handle_error "❌ Destroy phase failed during bounce sequence"
    fi
    
    # Step 2: Execute apply using standard operation logic (includes --no-volumes handling)
    info_message "🚀 Step 2/3: Applying target infrastructure..."
    log_phase "Bounce: Executing apply"
    
    if execute_standard_operation_with_params "apply" "$env" "$target_type"; then
        success_message "✅ Apply phase completed"
    else
        handle_error "❌ Apply phase failed during bounce sequence"
    fi
    
    # Step 3: Output generation is already handled by the apply step
    info_message "📤 Step 3/3: Output generation (already completed by apply step)"
    log_phase "Bounce: Output generation (automatic)"
    
    success_message "✅ Output generation completed (handled automatically by apply step)"
    success_message "🎉 Bounce sequence completed successfully: destroy → apply → output"
    
    # Ring completion bell if enabled
    ring_completion_bell "Bounce sequence completed successfully"
    
    # Update DNS records if enabled
    update_dns_records "Bounce sequence completed successfully"
    
    # Clean SSH known_hosts entries if enabled
    cleanup_known_hosts "Bounce sequence completed successfully"
}

# Execute bounce operation (destroy → apply → output)
# Usage: execute_bounce_operation "dev" "instances" "athena" "metis"
execute_bounce_operation() {
    local env="$1"
    local target_type="$2"
    shift 2
    local instances=("$@")
    
    debug_message "Executing bounce operation for target: $target_type with ${#instances[@]} instance(s)"
    
    # Use the existing bounce sequence function
    execute_bounce_sequence "$target_type"
    return $?
}

# ─────────────────────────────────────────────────────────────────────────────
# Operation Finalization
# ─────────────────────────────────────────────────────────────────────────────

# Finalize shutdown operation with cleanup and notifications
# Usage: finalize_shutdown_operation "operation completed"
finalize_shutdown_operation() {
    local message="$1"
    
    debug_message "Finalizing shutdown operation: $message"
    
    # Ring completion bell if enabled
    ring_completion_bell "$message"
    
    # Update DNS records if enabled
    update_dns_records "$message"
    
    # Clean SSH known_hosts entries if enabled
    cleanup_known_hosts "$message"
    
    debug_message "Shutdown operation finalization completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Shutdown module loaded successfully"
