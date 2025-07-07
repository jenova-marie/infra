#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Shutdown Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Unified shutdown operations - AWS CLI-based and infrastructure recreation
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

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
    
    # Check if bounce flag is enabled - if so, do destroy->apply->output sequence
    if is_bounce; then
        debug_message "Bounce flag enabled - executing AWS CLI terminate→destroy→apply→output sequence"
        
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
    
    # Check if terminate mode is enabled - AWS CLI terminate only
    if is_terminate; then
        debug_message "Terminate mode enabled - AWS CLI terminate"
        
        # For terminate mode, validate we have instance targets
        if [[ "$OP_TARGET_TYPE" == "infrastructure" ]]; then
            handle_error "Terminate mode operations only apply to instances, not infrastructure modules"
        fi
        
        # Determine target instances
        local instances=()
        while IFS= read -r instance; do
            [[ -n "$instance" ]] && instances+=("$instance")
        done < <(get_modules_for_target "$OP_TARGET_TYPE")
        
        if [[ ${#instances[@]} -eq 0 ]]; then
            handle_error "No instances found for target: $OP_TARGET_TYPE"
        fi
        
        info_message "🔴 Starting terminate sequence for ${#instances[@]} instance(s)"
        
        # Execute terminate operation
        execute_terminate_operation "$OP_ENV" "${instances[@]}"
        
        # Finalize shutdown operation
        finalize_shutdown_operation "Terminate operation completed"
        return $?
    fi
    
    # Check if hard mode is enabled - use AWS CLI only
    if is_hard; then
        debug_message "Hard mode enabled - using AWS CLI only"
        
        # For hard mode, validate we have instance targets
        if [[ "$OP_TARGET_TYPE" == "infrastructure" ]]; then
            handle_error "Hard mode operations only apply to instances, not infrastructure modules"
        fi
        
        # Determine target instances
        local instances=()
        while IFS= read -r instance; do
            [[ -n "$instance" ]] && instances+=("$instance")
        done < <(get_modules_for_target "$OP_TARGET_TYPE")
        
        if [[ ${#instances[@]} -eq 0 ]]; then
            handle_error "No instances found for target: $OP_TARGET_TYPE"
        fi
        
        info_message "🔧 Starting hard mode AWS CLI operation for ${#instances[@]} instance(s)"
        
        if is_reboot; then
            info_message "🔄 Hard reboot mode - using AWS CLI to reboot instances"
            execute_hard_reboot_operations "$OP_ENV" "${instances[@]}"
        else
            info_message "🛑 Hard shutdown mode - using AWS CLI to terminate instances"
            execute_hard_shutdown_operations "$OP_ENV" "${instances[@]}"
        fi
        
        # Finalize shutdown operation
        finalize_shutdown_operation "Hard mode AWS CLI operation completed"
        return $?
    fi
    
    # Default mode: AWS CLI terminate operations
    debug_message "Executing AWS CLI shutdown operation"
    log_phase "AWS CLI shutdown operation"
    
    # For AWS CLI operations, validate we have instance targets
    if [[ "$OP_TARGET_TYPE" == "infrastructure" ]]; then
        handle_error "AWS CLI operations only apply to instances, not infrastructure modules"
    fi
    
    # Determine target instances
    local instances=()
    while IFS= read -r instance; do
        [[ -n "$instance" ]] && instances+=("$instance")
    done < <(get_modules_for_target "$OP_TARGET_TYPE")
    
    if [[ ${#instances[@]} -eq 0 ]]; then
        handle_error "No instances found for target: $OP_TARGET_TYPE"
    fi
    
    info_message "🔄 Starting AWS CLI operation for ${#instances[@]} instance(s)"
    
    # Execute AWS CLI operations for all target instances
    if is_reboot; then
        info_message "🔄 Reboot mode - using AWS CLI to reboot instances"
        execute_hard_reboot_operations "$OP_ENV" "${instances[@]}"
    else
        info_message "🛑 Shutdown mode - using AWS CLI to terminate instances"
        execute_hard_shutdown_operations "$OP_ENV" "${instances[@]}"
    fi
    
    # Finalize shutdown operation
    finalize_shutdown_operation "AWS CLI shutdown operation completed"
}

# Execute bounce sequence (AWS CLI terminate -> wait -> destroy -> apply -> output)
# Usage: execute_bounce_sequence "instances"
execute_bounce_sequence() {
    local target_type="$1"
    
    debug_message "Executing bounce sequence for target: $target_type"
    log_phase "Bounce sequence: AWS CLI terminate -> wait -> destroy -> apply -> output"
    
    info_message "🔄 Starting bounce sequence: AWS CLI terminate -> wait -> destroy -> apply -> output"
    
    # Step 1: AWS CLI terminate instances
    info_message "🛑 Step 1/4: AWS CLI termination of instances..."
    log_phase "Bounce: AWS CLI termination"
    
    local env=$(get_environment)
    if aws_terminate_instances_for_bounce "$env" "$target_type"; then
        success_message "✅ AWS CLI termination phase completed - instances terminating"
    else
        warn_message "⚠️  AWS CLI termination had issues, but continuing with bounce sequence..."
    fi
    
    # Step 2: Execute destroy using standard operation logic
    info_message "🗑️  Step 2/4: Destroying target infrastructure..."
    log_phase "Bounce: Executing destroy"
    
    if execute_standard_operation_with_params "destroy" "$env" "$target_type"; then
        success_message "✅ Destroy phase completed"
    else
        handle_error "❌ Destroy phase failed during bounce sequence"
    fi
    
    # Step 3: Execute apply using standard operation logic (includes --no-volumes handling)
    info_message "🚀 Step 3/4: Applying target infrastructure..."
    log_phase "Bounce: Executing apply"
    
    if execute_standard_operation_with_params "apply" "$env" "$target_type"; then
        success_message "✅ Apply phase completed"
    else
        handle_error "❌ Apply phase failed during bounce sequence"
    fi
    
    # Step 4: Output generation is already handled by the apply step
    info_message "📤 Step 4/4: Output generation (already completed by apply step)"
    log_phase "Bounce: Output generation (automatic)"
    
    success_message "✅ Output generation completed (handled automatically by apply step)"
    success_message "🎉 Bounce sequence completed successfully: AWS CLI terminate -> destroy -> apply -> output"
    
    # Ring completion bell if enabled
    ring_completion_bell "Bounce sequence completed successfully"
    
    # Update DNS records if enabled
    update_dns_records "Bounce sequence completed successfully"
    
    # Clean SSH known_hosts entries if enabled
    cleanup_known_hosts "Bounce sequence completed successfully"
}

# AWS CLI terminate instances for bounce operations
# Usage: aws_terminate_instances_for_bounce "dev" "instances"
aws_terminate_instances_for_bounce() {
    local env="$1"
    local target_type="$2"
    
    debug_message "AWS CLI terminate instances for bounce, target: $target_type"
    
    # Determine target instances
    local instances=()
    case "$target_type" in
        "all"|"instances")
            # Get all instance modules
            instances=($(get_modules_for_target "instances"))
            ;;
        "infrastructure")
            # Infrastructure target doesn't include instances, return success
            debug_message "Infrastructure target doesn't include instances - no termination needed"
            return 0
            ;;
        *)
            # Single instance module
            if is_valid_module "$target_type"; then
                instances=("$target_type")
            else
                warn_message "Target '$target_type' is not a valid instance module"
                return 1
            fi
            ;;
    esac
    
    if [[ $(safe_array_length "instances") -eq 0 ]]; then
        debug_message "No instances found for AWS CLI termination"
        return 0
    fi
    
    info_message "🔄 AWS CLI termination for $(safe_array_length "instances") instance(s)..."
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would terminate instances via AWS CLI: $(safe_array_string "instances")"
        dry_run_message "[DRY-RUN] Would wait for instances to reach terminated state"
        info_message "ℹ️  [DRY-RUN] AWS CLI termination phase would complete successfully"
        return 0
    fi
    
    # Execute AWS CLI termination for all target instances
    if [[ $(safe_array_length "instances") -eq 1 ]]; then
        # Single instance - execute directly
        if execute_hard_shutdown_single_instance "$env" "${instances[0]}"; then
            success_message "✅ AWS CLI termination completed for ${instances[0]}"
        else
            warn_message "❌ AWS CLI termination failed for ${instances[0]}, continuing..."
        fi
    else
        # Multiple instances - execute in parallel
        if execute_hard_shutdown_operations "$env" $(safe_array_elements "instances"); then
            success_message "✅ AWS CLI termination completed for $(safe_array_length "instances") instances"
        else
            warn_message "❌ AWS CLI termination failed for some instances, continuing..."
        fi
    fi
    
    return 0  # Always continue with bounce even if termination has issues
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS CLI Operation Functions (using existing aws.sh functions)
# ─────────────────────────────────────────────────────────────────────────────

# Execute hard shutdown operations for multiple instances
# Usage: execute_hard_shutdown_operations "dev" "athena" "metis"
execute_hard_shutdown_operations() {
    local env="$1"
    shift
    local instances=("$@")
    
    debug_message "Executing hard shutdown operations for ${#instances[@]} instance(s): ${instances[*]}"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would terminate instances via AWS CLI: ${instances[*]}"
        for instance in "${instances[@]}"; do
            dry_run_message "[DRY-RUN] Would execute: aws ec2 terminate-instances --instance-ids {$instance-id}"
        done
        info_message "ℹ️  [DRY-RUN] Hard shutdown operations would complete successfully"
        return 0
    fi
    
    # Execute termination for each instance
    local success_count=0
    local total_count=${#instances[@]}
    
    for instance in "${instances[@]}"; do
        if execute_hard_shutdown_single_instance "$env" "$instance"; then
            ((success_count++))
        else
            warn_message "⚠️  Failed to terminate instance: $instance"
        fi
    done
    
    if [[ $success_count -eq $total_count ]]; then
        success_message "✅ Hard shutdown operations completed successfully for all $total_count instance(s)"
        return 0
    else
        warn_message "⚠️  Hard shutdown operations completed with $((total_count - success_count)) failure(s) out of $total_count"
        return 1
    fi
}

# Execute hard reboot operations for multiple instances
# Usage: execute_hard_reboot_operations "dev" "athena" "metis"
execute_hard_reboot_operations() {
    local env="$1"
    shift
    local instances=("$@")
    
    debug_message "Executing hard reboot operations for ${#instances[@]} instance(s): ${instances[*]}"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would reboot instances via AWS CLI: ${instances[*]}"
        for instance in "${instances[@]}"; do
            dry_run_message "[DRY-RUN] Would execute: aws ec2 reboot-instances --instance-ids {$instance-id}"
        done
        info_message "ℹ️  [DRY-RUN] Hard reboot operations would complete successfully"
        return 0
    fi
    
    # Execute reboot for each instance
    local success_count=0
    local total_count=${#instances[@]}
    
    for instance in "${instances[@]}"; do
        if execute_hard_reboot_single_instance "$env" "$instance"; then
            ((success_count++))
        else
            warn_message "⚠️  Failed to reboot instance: $instance"
        fi
    done
    
    if [[ $success_count -eq $total_count ]]; then
        success_message "✅ Hard reboot operations completed successfully for all $total_count instance(s)"
        return 0
    else
        warn_message "⚠️  Hard reboot operations completed with $((total_count - success_count)) failure(s) out of $total_count"
        return 1
    fi
}

# Execute hard shutdown for a single instance
# Usage: execute_hard_shutdown_single_instance "dev" "athena"
execute_hard_shutdown_single_instance() {
    local env="$1"
    local instance="$2"
    
    debug_message "Executing hard shutdown for single instance: $instance"
    
    # Use AWS_REGION environment variable
    local aws_region="${AWS_REGION:-us-east-1}"
    debug_message "Using AWS region: $aws_region"
    
    # Get instance ID using outputs API (if available)
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance"); then
        warn_message "Could not get instance ID for $instance from outputs - AWS CLI may fail"
        return 1
    fi
    
    debug_message "Instance ID: $instance_id"
    
    # Use existing terminate_instance function from aws.sh
    if terminate_instance "$instance_id" "$instance" "$aws_region"; then
        success_message "✅ Hard shutdown completed for $instance"
        return 0
    else
        warn_message "❌ Hard shutdown failed for $instance"
        return 1
    fi
}

# Execute hard reboot for a single instance
# Usage: execute_hard_reboot_single_instance "dev" "athena"
execute_hard_reboot_single_instance() {
    local env="$1"
    local instance="$2"
    
    debug_message "Executing hard reboot for single instance: $instance"
    
    # Use AWS_REGION environment variable
    local aws_region="${AWS_REGION:-us-east-1}"
    debug_message "Using AWS region: $aws_region"
    
    # Get instance ID using outputs API (if available)
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance"); then
        warn_message "Could not get instance ID for $instance from outputs - AWS CLI may fail"
        return 1
    fi
    
    debug_message "Instance ID: $instance_id"
    
    # Use existing reboot_instance function from aws.sh
    if reboot_instance "$instance_id" "$instance" "$aws_region"; then
        success_message "✅ Hard reboot completed for $instance"
        return 0
    else
        warn_message "❌ Hard reboot failed for $instance"
        return 1
    fi
}

# Execute terminate operation for multiple instances
# Usage: execute_terminate_operation "dev" "athena" "metis"
execute_terminate_operation() {
    local env="$1"
    shift
    local instances=("$@")
    
    debug_message "Executing terminate operation for ${#instances[@]} instance(s): ${instances[*]}"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would terminate instances via AWS CLI: ${instances[*]}"
        for instance in "${instances[@]}"; do
            dry_run_message "[DRY-RUN] Would execute: aws ec2 terminate-instances --instance-ids {$instance-id}"
        done
        info_message "ℹ️  [DRY-RUN] Terminate operation would complete successfully"
        return 0
    fi
    
    # Execute termination for each instance
    local success_count=0
    local total_count=${#instances[@]}
    
    for instance in "${instances[@]}"; do
        if execute_terminate_single_instance "$env" "$instance"; then
            ((success_count++))
        else
            warn_message "⚠️  Failed to terminate instance: $instance"
        fi
    done
    
    if [[ $success_count -eq $total_count ]]; then
        success_message "✅ Terminate operation completed successfully for all $total_count instance(s)"
        return 0
    else
        warn_message "⚠️  Terminate operation completed with $((total_count - success_count)) failure(s) out of $total_count"
        return 1
    fi
}

# Execute terminate for a single instance
# Usage: execute_terminate_single_instance "dev" "athena"
execute_terminate_single_instance() {
    local env="$1"
    local instance="$2"
    
    debug_message "Executing terminate for single instance: $instance"
    
    # Use AWS_REGION environment variable
    local aws_region="${AWS_REGION:-us-east-1}"
    debug_message "Using AWS region: $aws_region"
    
    # Get instance ID using outputs API (if available)
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance"); then
        warn_message "Could not get instance ID for $instance from outputs - AWS CLI may fail"
        return 1
    fi
    
    debug_message "Instance ID: $instance_id"
    
    # Use existing terminate_instance function from aws.sh
    if terminate_instance "$instance_id" "$instance" "$aws_region"; then
        success_message "✅ Terminate completed for $instance"
        return 0
    else
        warn_message "❌ Terminate failed for $instance"
        return 1
    fi
}

# Execute bounce operation (AWS CLI terminate -> wait -> destroy -> apply -> output)
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
