#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Operations Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Main operation execution and coordination
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Operation Execution Dispatcher
# ─────────────────────────────────────────────────────────────────────────────

# Execute the appropriate operation
# Usage: execute_operation
execute_operation() {
    debug_message "Executing operation: $ACTION"
    
    case "$ACTION" in
        "apply"|"destroy"|"plan"|"init")
            execute_standard_operation
            ;;
        "output")
            execute_output_operation
            ;;
        "clean")
            execute_clean_operation
            ;;
        "volume")
            execute_volume_operation
            ;;
        "shutdown")
            execute_shutdown_operation
            ;;
        "verify")
            execute_verify_operation
            ;;
        "status")
            execute_status_operation
            ;;
        "reboot")
            execute_reboot_operation
            ;;
        "query")
            execute_query_operation
            ;;
        *)
            handle_error "Unsupported operation: $ACTION"
            ;;
    esac
}

# Add the query operation executor
execute_query_operation() {
    debug_message "Executing query operation"
    # Source the query module and run its main logic
    source "$SCRIPT_DIR/query.sh"
}

# ─────────────────────────────────────────────────────────────────────────────
# Standard Terragrunt Operations
# ─────────────────────────────────────────────────────────────────────────────

# Execute standard terragrunt operations (apply, destroy, plan, init)
# Usage: execute_standard_operation
execute_standard_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Executing standard operation: $OP_ACTION for target: $OP_TARGET_TYPE"
    log_phase "Executing terragrunt $OP_ACTION"
    
    # Execute module commands before terragrunt operation (for apply operations only)
    execute_module_cmds "$OP_TARGET_TYPE" "$OP_ACTION"
    
    # Handle --no-volumes flag for apply operations (empty volumes.yml files before apply)
    if [[ "$OP_ACTION" == "apply" ]] && is_no_volumes; then
        info_message "🗑️  --no-volumes flag detected: emptying volumes.yml files before apply"
        if ! empty_volumes_files "$OP_ENV" "$OP_TARGET_TYPE"; then
            handle_error "Failed to empty volumes.yml files"
        fi
    fi
    
    # Validate destroy operations against protected modules
    validate_destroy_operation "$OP_TARGET_TYPE" "$OP_ACTION"
    
    # Build command arguments based on target type
    local command_args=""
    
    case "$OP_TARGET_TYPE" in
        "all")
            # For all modules, check if we need to exclude protected modules during destroy
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
        "infrastructure"|"instances")
            # For infrastructure or instances, add exclusions
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
        *)
            # For single modules, check if the module is protected during destroy
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
    esac
    
    debug_message "Command arguments: $command_args"
    
    # Execute terragrunt command with centralized flag handling and intelligent targeting
    if execute_terragrunt "$OP_ACTION" "$command_args" "$OP_TARGET_TYPE"; then
        local success_message="Terragrunt $OP_ACTION completed successfully"
        success_message "$success_message"
        
        # Execute all post-operation actions in one call (KISS approach)
        execute_post_operation_actions "$success_message"
        
        # Handle post-operation actions based on the action type
        if [[ "$OP_ACTION" == "destroy" ]]; then
            # For destroy operations, clean up output files since resources are gone
            cleanup_destroyed_module_outputs "$OP_TARGET_TYPE"
            
            # CRITICAL: For destroy operations, DO NOT regenerate outputs for destroyed modules
            # The modules no longer exist, so there's nothing to generate outputs for
            debug_message "Destroy operation completed - skipping output generation for destroyed modules"
            info_message "ℹ️  Skipping output generation for destroyed modules (they no longer exist)"
        elif action_modifies_state "$OP_ACTION"; then
            # For other state-modifying operations (apply), generate outputs
            execute_automatic_output_generation
        fi
        # ─────────────────────────────────────────────────────────────────
        # Gateway Instance: Trigger VPCs Apply After Apply/Destroy
        # Only for single instance operations (not all/instances/infrastructure)
        if [[ "$OP_TARGET_TYPE" != "all" && "$OP_TARGET_TYPE" != "instances" && "$OP_TARGET_TYPE" != "infrastructure" ]]; then
            # Check if the target is an instance and a gateway
            if get_module_type "$OP_TARGET_TYPE" 2>/dev/null | grep -q "instance"; then
                if is_instance_gateway "$OP_TARGET_TYPE"; then
                    # Only apply VPCs if --vpcs flag is enabled
                    if is_vpcs; then
                        info_message "🚦 Gateway instance '$OP_TARGET_TYPE' modified; reapplying VPCs to sync routes."
                        # Always apply VPCs (not destroy) to update routing tables
                        if ! execute_standard_operation_with_params "apply" "$OP_ENV" "vpcs"; then
                            error_message "❌ Failed to reapply VPCs after gateway instance modification."
                        else
                            success_message "✅ VPCs reapplied after gateway instance modification."
                        fi
                    else
                        debug_message "Gateway instance '$OP_TARGET_TYPE' modified, but --vpcs flag not enabled - skipping VPCs apply"
                    fi
                fi
            fi
        fi
    else
        handle_error "Terragrunt $OP_ACTION failed"
    fi
}

# Execute standard operation with specific parameters (for use by other modules)
# Usage: execute_standard_operation_with_params "apply" "dev" "athena"
execute_standard_operation_with_params() {
    local action="$1"
    local env="$2"
    local target_type="$3"
    
    debug_message "Executing standard operation with params: action=$action, env=$env, target=$target_type"
    
    # Store original operation context
    local original_action="$OP_ACTION"
    local original_env="$OP_ENV"
    local original_target="$OP_TARGET_TYPE"
    local original_env_path="$OP_ENV_PATH"
    
    # Set operation context for this execution
    OP_ACTION="$action"
    OP_ENV="$env"
    OP_TARGET_TYPE="$target_type"
    OP_ENV_PATH="$(get_environment_path "$env")"
    
    # Export for use in subprocesses
    export OP_ACTION OP_ENV OP_TARGET_TYPE OP_ENV_PATH
    
    debug_message "Executing standard operation: $OP_ACTION for target: $OP_TARGET_TYPE"
    log_phase "Executing terragrunt $OP_ACTION"
    
    # Execute module commands before terragrunt operation (for apply operations only)
    execute_module_cmds "$OP_TARGET_TYPE" "$OP_ACTION"
    
    # Handle --no-volumes flag for apply operations (empty volumes.yml files before apply)
    if [[ "$OP_ACTION" == "apply" ]] && is_no_volumes; then
        info_message "🗑️  --no-volumes flag detected: emptying volumes.yml files before apply"
        if ! empty_volumes_files "$OP_ENV" "$OP_TARGET_TYPE"; then
            handle_error "Failed to empty volumes.yml files"
        fi
    fi
    
    # Validate destroy operations against protected modules
    validate_destroy_operation "$OP_TARGET_TYPE" "$OP_ACTION"
    
    # Build command arguments based on target type
    local command_args=""
    
    case "$OP_TARGET_TYPE" in
        "all")
            # For all modules, check if we need to exclude protected modules during destroy
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
        "infrastructure"|"instances")
            # For infrastructure or instances, add exclusions
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
        *)
            # For single modules, check if the module is protected during destroy
            local exclusions=$(generate_terragrunt_exclusions "$OP_TARGET_TYPE")
            if [[ -n "$exclusions" ]]; then
                command_args="$exclusions"
                log_exclusions "$OP_TARGET_TYPE" "$exclusions"
            fi
            ;;
    esac
    
    debug_message "Command arguments: $command_args"
    
    # Execute terragrunt command with centralized flag handling and intelligent targeting
    local result=0
    if execute_terragrunt "$OP_ACTION" "$command_args" "$OP_TARGET_TYPE"; then
        local success_message="Terragrunt $OP_ACTION completed successfully"
        success_message "$success_message"
        
        # Execute all post-operation actions in one call (KISS approach)
        execute_post_operation_actions "$success_message"
        
        # Handle post-operation actions based on the action type
        if [[ "$OP_ACTION" == "destroy" ]]; then
            # For destroy operations, clean up output files since resources are gone
            cleanup_destroyed_module_outputs "$OP_TARGET_TYPE"
            
            # CRITICAL: For destroy operations, DO NOT regenerate outputs for destroyed modules
            # The modules no longer exist, so there's nothing to generate outputs for
            debug_message "Destroy operation completed - skipping output generation for destroyed modules"
            info_message "ℹ️  Skipping output generation for destroyed modules (they no longer exist)"
        elif action_modifies_state "$OP_ACTION"; then
            # For other state-modifying operations (apply), generate outputs
            execute_automatic_output_generation
        fi
    else
        handle_error "Terragrunt $OP_ACTION failed"
        result=1
    fi
    
    # Restore original operation context
    OP_ACTION="$original_action"
    OP_ENV="$original_env"
    OP_TARGET_TYPE="$original_target"
    OP_ENV_PATH="$original_env_path"
    
    # Export for use in subprocesses
    export OP_ACTION OP_ENV OP_TARGET_TYPE OP_ENV_PATH
    
    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Specific Operation Handlers
# ─────────────────────────────────────────────────────────────────────────────

# Execute volume operation
# Usage: execute_volume_operation
execute_volume_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    local volume_name=$(get_volume_name)
    local volume_action=$(get_volume_action)
    
    debug_message "Executing volume operation: $volume_action volume $volume_name for instance $OP_TARGET_TYPE"
    log_phase "Volume operation: $volume_action $volume_name"
    
    # Execute the volume operation using the volume module and capture if changes were made
    local volume_result=0
    if execute_volume_operation_impl "$OP_ENV" "$OP_TARGET_TYPE" "$volume_name" "$volume_action"; then
        volume_result=0
        local success_message="Volume operation completed successfully"
        success_message "$success_message"
        
        # Execute all post-operation actions in one call (KISS approach)
        execute_post_operation_actions "$success_message"
        
        # Check if we need to regenerate outputs based on volume operation result
        # If volume was already in desired state (attached/detached), skip output generation for efficiency
        if [[ "$volume_action" == "attach" ]]; then
            # For attach operations, check if volume was already attached
            if is_volume_attached_fast "$OP_ENV" "$OP_TARGET_TYPE" "$volume_name"; then
                debug_message "Volume $volume_name already attached to $OP_TARGET_TYPE - skipping output regeneration"
                info_message "ℹ️  Volume already attached - outputs are current, no regeneration needed"
                return 0
            fi
        elif [[ "$volume_action" == "detach" ]]; then
            # For detach operations, check if volume was already detached
            if ! is_volume_attached_fast "$OP_ENV" "$OP_TARGET_TYPE" "$volume_name"; then
                debug_message "Volume $volume_name already detached from $OP_TARGET_TYPE - skipping output regeneration"
                info_message "ℹ️  Volume already detached - outputs are current, no regeneration needed"
                return 0
            fi
        fi
        
        # Only generate outputs if --refresh flag is passed for volume operations
        # This allows users to control when outputs are regenerated after volume operations
        if is_refresh; then
            debug_message "Refresh flag enabled - generating updated outputs after volume operation"
        execute_automatic_output_generation
        else
            debug_message "Refresh flag not enabled - skipping output generation after volume operation"
            info_message "ℹ️  Output refresh skipped. Use --refresh flag to update outputs after volume operations"
        fi
    else
        handle_error "Volume operation failed"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Operations module loaded successfully" 