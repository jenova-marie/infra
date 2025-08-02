#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - AWS CLI Module (KISS Rewrite)
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Simple, clean AWS CLI operations
# Author: Infrastructure Management System v2.0
# Last Updated: January 21, 2025

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Output Parsing Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

# Get instance ID from centralized outputs
# Usage: get_instance_id_from_outputs "dev" "athena"
get_instance_id_from_outputs() {
    local env="$1"
    local instance_name="$2"
    
    local env_path="$(get_environment_path "$env")"
    local instance_outputs="$env_path/outputs/$instance_name.json"
    
    if [[ ! -f "$instance_outputs" ]]; then
        debug_message "Instance outputs not found: $instance_outputs"
        return 1
    fi
    
    # The correct path is instance_ids.value.{instance_name}, not instance_id.value
    local instance_id=$(jq -r --arg instance_name "$instance_name" '.instance_ids.value[$instance_name] // empty' "$instance_outputs" 2>/dev/null)
    
    if [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
        echo "$instance_id"
        return 0
    else
        debug_message "Could not extract instance_id for $instance_name from: $instance_outputs"
        return 1
    fi
}

# Get volume ID from centralized outputs  
# Usage: get_volume_id_from_outputs "dev" "athena-data"
get_volume_id_from_outputs() {
    local env="$1"
    local volume_name="$2"
    
    local env_path="$(get_environment_path "$env")"
    local ebs_outputs="$env_path/outputs/ebss.json"
    
    if [[ ! -f "$ebs_outputs" ]]; then
        debug_message "EBS outputs not found: $ebs_outputs"
        return 1
    fi
    
    local volume_id=$(jq -r --arg vol_name "$volume_name" '.volume_ids.value[$vol_name] // empty' "$ebs_outputs" 2>/dev/null)
    
    if [[ -n "$volume_id" && "$volume_id" != "null" ]]; then
        echo "$volume_id"
        return 0
    else
        debug_message "Could not extract volume_id for $volume_name from: $ebs_outputs"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS Region Management
# ─────────────────────────────────────────────────────────────────────────────

# Get AWS region from environment's root.hcl
# Usage: get_aws_region "dev"
get_aws_region() {
    local env="$1"
    local env_path="$(get_environment_path "$env")"
    local root_hcl="$env_path/root.hcl"
    
    if [[ ! -f "$root_hcl" ]]; then
        handle_error "Environment root.hcl not found at: $root_hcl"
    fi
    
    # Extract aws_region from root.hcl
    local aws_region=$(grep 'aws_region.*=' "$root_hcl" | sed -E 's/.*aws_region.*=.*"([^"]+)".*/\1/' | head -1)
    
    if [[ -n "$aws_region" && "$aws_region" != "aws_region" ]]; then
        echo "$aws_region"
        return 0
    fi
    
    handle_error "Could not extract aws_region from: $root_hcl"
}

# ─────────────────────────────────────────────────────────────────────────────
# Volume Management Operations
# ─────────────────────────────────────────────────────────────────────────────

# Detach volume using AWS CLI
# Usage: aws_detach_volume "dev" "athena" "athena-blog"
aws_detach_volume() {
    local env="$1"
    local instance_name="$2"
    local volume_name="$3"
    
    debug_message "AWS CLI volume detachment: $volume_name from $instance_name"
    
    # Get AWS region and IDs
    local aws_region=$(get_aws_region "$env")
    local volume_id=$(get_volume_id_from_outputs "$env" "$volume_name")
    local instance_id=$(get_instance_id_from_outputs "$env" "$instance_name")
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would detach volume: $volume_id from instance $instance_id"
        return 0
    fi
    
    info_message "🔄 Detaching volume $volume_name ($volume_id) from $instance_name..."
    
    # Simple AWS CLI command
    local force_flag=""
    if is_force; then
        force_flag="--force"
    fi
    
    if aws ec2 detach-volume --volume-id "$volume_id" --region "$aws_region" $force_flag >/dev/null 2>&1; then
        success_message "✅ Volume detachment command sent successfully"
        return 0
    else
        warn_message "AWS CLI volume detachment failed"
        return 1
    fi
}

# Check if volume is attached using AWS CLI
# Usage: aws_is_volume_attached "dev" "vol-123456" "i-123456"
# Returns: 0=attached, 1=not attached, 2=cannot verify
aws_is_volume_attached() {
    local env="$1"
    local volume_id="$2"
    local instance_id="$3"
    
    debug_message "AWS CLI: Checking if volume $volume_id is attached to instance $instance_id"
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env"); then
        debug_message "Failed to get AWS region for environment $env"
        return 2
    fi
    
    # Query AWS for volume attachment state
    debug_message "AWS CLI: Checking volume attachment in region $aws_region"
    
    # Use AWS CLI to get attachment state directly
    local attachment_state
    if attachment_state=$(aws ec2 describe-volumes \
        --volume-ids "$volume_id" \
        --region "$aws_region" \
        --query "Volumes[0].Attachments[?InstanceId=='$instance_id'].State" \
        --output text 2>/dev/null); then
        
        case "$attachment_state" in
            "attached")
                debug_message "AWS CLI: Volume $volume_id is attached to instance $instance_id"
                return 0
                ;;
            "attaching")
                debug_message "AWS CLI: Volume $volume_id is currently attaching to instance $instance_id"
                return 0  # Consider attaching as attached for our purposes
                ;;
            "")
                debug_message "AWS CLI: Volume $volume_id is not attached to instance $instance_id"
                return 1
                ;;
            *)
                debug_message "AWS CLI: Volume $volume_id has unexpected state: $attachment_state"
                return 1
                ;;
        esac
    else
        debug_message "AWS CLI: Failed to query volume attachment state"
        return 2
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Management Operations
# ─────────────────────────────────────────────────────────────────────────────

# Reboot instance using AWS CLI
# Usage: reboot_instance "i-1234567890abcdef0" "athena" "us-east-2"
reboot_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would reboot instance: $instance_id ($instance_name)"
        return 0
    fi
    
    info_message "🔄 Rebooting instance $instance_name ($instance_id)..."
    
    if aws ec2 reboot-instances --instance-ids "$instance_id" --region "$aws_region" >/dev/null 2>&1; then
        success_message "✅ Reboot command sent successfully for $instance_name"
        return 0
    else
        handle_error "AWS CLI reboot failed for $instance_name"
    fi
}

# Start instance using AWS CLI
# Usage: start_instance "i-1234567890abcdef0" "athena" "us-east-2"
start_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would start instance: $instance_id ($instance_name)"
        return 0
    fi
    
    info_message "🚀 Starting instance $instance_name ($instance_id)..."
    
    if aws ec2 start-instances --instance-ids "$instance_id" --region "$aws_region" >/dev/null 2>&1; then
        success_message "✅ Start command sent successfully for $instance_name"
        return 0
    else
        handle_error "AWS CLI start failed for $instance_name"
    fi
}

# Get current instance status from AWS
# Usage: get_instance_status "dev" "athena"
# Returns: running, stopped, pending, stopping, shutting-down, terminated, etc.
get_instance_status() {
    local env="$1"
    local instance_name="$2"
    
    # Get AWS region and instance ID
    local aws_region=$(get_aws_region "$env")
    local instance_id=$(get_instance_id_from_outputs "$env" "$instance_name")
    
    # Get current instance state from AWS
    local state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)
    
    if [[ -n "$state" && "$state" != "None" ]]; then
        echo "$state"
        return 0
    else
        return 1
    fi
}

# Terminate instance using AWS CLI
# Usage: terminate_instance "i-1234567890abcdef0" "athena" "us-east-2"
terminate_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would terminate instance: $instance_id ($instance_name)"
        return 0
    fi
    
    print_message "🔵 TERMINATING instance $instance_name ($instance_id)"
    
    if aws ec2 terminate-instances --instance-ids "$instance_id" --region "$aws_region" >/dev/null 2>&1; then
        print_message "🔵 Termination command sent successfully for $instance_name"
        return 0
    else
        warn_message "Failed to terminate instance: $instance_id ($instance_name)"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance State Waiting
# ─────────────────────────────────────────────────────────────────────────────

# Wait for instance to reach target state
# Usage: wait_for_instance_state "dev" "athena" "running" [timeout] [poll_interval]
wait_for_instance_state() {
    local env="$1"
    local instance_name="$2"
    local target_state="$3"
    local timeout="${4:-300}"        # Default 5 minutes
    local poll_interval="${5:-1}"    # Default 1 second
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would wait for instance $instance_name to reach $target_state state"
        return 0
    fi
    
    local start_time=$(date +%s)
    info_message "⏳ Waiting for $instance_name to reach $target_state state..."
    
    while true; do
        local current_state=$(get_instance_status "$env" "$instance_name")
        
        if [[ "$current_state" == "$target_state" ]]; then
            success_message "✅ $instance_name has reached $target_state state!"
            return 0
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            warn_message "⚠️  Timeout waiting for $instance_name to reach $target_state state"
            return 1
        fi
        
        info_message "✅ Status: $current_state (${elapsed}s elapsed)"
        sleep "$poll_interval"
    done
}

# Wait for instance shutdown (convenience function)
# Usage: wait_for_instance_shutdown "dev" "athena"
wait_for_instance_shutdown() {
    local env="$1"
    local instance_name="$2"
    wait_for_instance_state "$env" "$instance_name" "stopped" 120 1
}

# Wait for instance start completion (convenience function)
# Usage: wait_for_instance_start_completion "dev" "athena"
wait_for_instance_start_completion() {
    local env="$1"
    local instance_name="$2"
    wait_for_instance_state "$env" "$instance_name" "running" 180 1
}

# Wait for instance reboot completion (convenience function)
# Usage: wait_for_instance_reboot_completion "dev" "athena"
wait_for_instance_reboot_completion() {
    local env="$1"
    local instance_name="$2"
    wait_for_instance_state "$env" "$instance_name" "running" 300 1
}

# Wait for instance termination (convenience function)
# Usage: wait_for_instance_termination "dev" "athena"
wait_for_instance_termination() {
    local env="$1"
    local instance_name="$2"
    wait_for_instance_state "$env" "$instance_name" "terminated" 300 2
}

# ─────────────────────────────────────────────────────────────────────────────
# SSH Shutdown + AWS Start Reboot Operation
# ─────────────────────────────────────────────────────────────────────────────

# Execute reboot operation (SSH shutdown + AWS start)
# Usage: execute_reboot_operation
execute_reboot_operation() {
    get_operation_context
    
    # Parse target to extract instance name
    local instance_name
    if [[ "$OP_TARGET_TYPE" == *":"* ]]; then
        instance_name="${OP_TARGET_TYPE#*:}"
    else
        instance_name="$OP_TARGET_TYPE"
    fi
    
    # Get AWS region and instance ID
    local aws_region=$(get_aws_region "$OP_ENV")
    local instance_id=$(get_instance_id_from_outputs "$OP_ENV" "$instance_name")
    
    info_message "🔄 Starting SSH shutdown + AWS start reboot for $instance_name..."
    
    # Step 1: SSH shutdown
    info_message "🛑 Step 1/3: SSH shutdown..."
    local hostname="${instance_name}-${OP_ENV}.recoverysky.dev"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would execute SSH shutdown and AWS reboot sequence"
        return 0
    fi
    
    # Execute SSH shutdown with timeout
    if timeout 30 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "ec2-user@$hostname" "~/scripts/shutdown.sh" 2>/dev/null; then
        success_message "✅ SSH shutdown command sent"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            success_message "✅ SSH shutdown sent (timeout expected)"
        else
            warn_message "⚠️  SSH shutdown failed, using direct AWS reboot..."
            if reboot_instance "$instance_id" "$instance_name" "$aws_region"; then
                success_message "✅ Direct AWS reboot completed"
                execute_post_operation_actions "Direct AWS reboot completed"
                return 0
            else
                handle_error "Both SSH shutdown and direct AWS reboot failed"
            fi
        fi
    fi
    
    # Step 2: Wait for shutdown
    info_message "⏳ Step 2/3: Waiting for shutdown..."
    if wait_for_instance_shutdown "$OP_ENV" "$instance_name"; then
        success_message "✅ Instance shutdown completed"
    else
        warn_message "⚠️  Shutdown wait timed out, starting anyway..."
    fi
    
    # Step 3: Start instance
    info_message "🚀 Step 3/3: Starting instance..."
    if start_instance "$instance_id" "$instance_name" "$aws_region"; then
        success_message "✅ SSH shutdown + AWS start reboot completed"
        execute_post_operation_actions "SSH + AWS reboot completed"
    else
        handle_error "Instance start failed after SSH shutdown"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS Termination for SSH Failures
# ─────────────────────────────────────────────────────────────────────────────

# AWS CLI termination fallback for SSH failures
# Usage: aws_terminate_instance_on_ssh_failure "dev" "athena"
aws_terminate_instance_on_ssh_failure() {
    local env="$1"
    local instance_name="$2"
    
    # Get AWS region and instance ID
    local aws_region=$(get_aws_region "$env")
    local instance_id=$(get_instance_id_from_outputs "$env" "$instance_name")
    
    # Terminate and wait
    if terminate_instance "$instance_id" "$instance_name" "$aws_region"; then
        if wait_for_instance_termination "$env" "$instance_name"; then
            print_message "🔴 Instance $instance_name termination completed" "$RED" "ERROR"
            return 0
        else
            print_message "🔴 Instance $instance_name termination timed out" "$RED" "ERROR"
            return 1
        fi
    else
        print_message "🔴 Failed to terminate instance $instance_name" "$RED" "ERROR"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Secrets Management Operations
# ─────────────────────────────────────────────────────────────────────────────

# Clear secrets for modules marked with destroy: false
# Usage: clear_secrets_for_destroy_disabled_modules "dev" "secrets"
clear_secrets_for_destroy_disabled_modules() {
    local env="$1"
    local target_type="$2"
    
    # Get target modules with destroy: false
    local destroy_disabled_modules=()
    while IFS= read -r module; do
        if [[ -n "$module" ]] && is_module_destroy_disabled "$module"; then
            destroy_disabled_modules+=("$module")
        fi
    done < <(get_modules_for_target "$target_type")
    
    if [[ ${#destroy_disabled_modules[@]} -eq 0 ]]; then
        return 0
    fi
    
    info_message "🔒 Clearing secrets for ${#destroy_disabled_modules[@]} destroy-disabled modules..."
    
    # Clear secrets for each module
    local success_count=0
    for module in "${destroy_disabled_modules[@]}"; do
        if clear_module_secrets "$env" "$module"; then
            ((success_count++))
        fi
    done
    
    if [[ $success_count -eq ${#destroy_disabled_modules[@]} ]]; then
        success_message "✅ Successfully cleared secrets for $success_count modules"
        return 0
    else
        handle_error "Failed to clear some secrets - operation aborted"
    fi
}

# Clear all secrets for a specific module
# Usage: clear_module_secrets "dev" "secrets"
clear_module_secrets() {
    local env="$1"
    local module="$2"
    
    local aws_region=$(get_aws_region "$env")
    local env_path="$(get_environment_path "$env")"
    local secrets_file="$env_path/$module/secrets.yml"
    
    if [[ ! -f "$secrets_file" ]]; then
        return 0  # No secrets to clear
    fi
    
    # Get secret names from YAML file
    local secret_names=()
    while IFS= read -r secret_name; do
        [[ -n "$secret_name" ]] && secret_names+=("$secret_name")
    done < <(yq eval '.secrets | keys | .[]' "$secrets_file" 2>/dev/null)
    
    if [[ ${#secret_names[@]} -eq 0 ]]; then
        return 0
    fi
    
    # Clear each secret
    local success_count=0
    for secret_key in "${secret_names[@]}"; do
        local secret_name=$(yq eval ".secrets.\"$secret_key\".name" "$secrets_file" 2>/dev/null)
        
        if [[ -n "$secret_name" && "$secret_name" != "null" ]]; then
            if clear_aws_secret "$secret_name" "$aws_region"; then
                ((success_count++))
            fi
        fi
    done
    
    return 0
}

# Clear a single AWS secret
# Usage: clear_aws_secret "secret-name" "us-east-2"
clear_aws_secret() {
    local secret_name="$1"
    local aws_region="$2"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would clear AWS secret: $secret_name"
        return 0
    fi
    
    if aws secretsmanager update-secret \
        --secret-id "$secret_name" \
        --secret-string "infra.sh cleared" \
        --region "$aws_region" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Volume Verification Functions (for volumeManager.ts)
# ─────────────────────────────────────────────────────────────────────────────

# Check if volume is mounted (real implementation)
# Usage: aws_verify_volume_mounted "dev" "athena" "athena-data"
# Returns: 0=mounted, 1=not_mounted
aws_verify_volume_mounted() {
    local env="$1"
    local instance_name="$2"
    local volume_name="$3"
    
    debug_message "Checking if volume $volume_name is mounted on $instance_name"
    
    # Get volume and instance IDs
    local volume_id=$(get_volume_id_from_outputs "$env" "$volume_name" 2>/dev/null || echo "")
    local instance_id=$(get_instance_id_from_outputs "$env" "$instance_name" 2>/dev/null || echo "")
    
    if [[ -z "$volume_id" || -z "$instance_id" ]]; then
        debug_message "Cannot get volume or instance ID for verification"
        return 1  # Not mounted (cannot verify)
    fi
    
    # Use existing AWS CLI check
    if aws_is_volume_attached "$env" "$volume_id" "$instance_id"; then
        debug_message "Volume $volume_name is attached to $instance_name"
        return 0  # Mounted
    else
        debug_message "Volume $volume_name is NOT attached to $instance_name"
        return 1  # Not mounted
    fi
}

# Volume verification functions - now using real AWS CLI
# These functions provide high-level volume verification using AWS CLI backend

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

debug_message "AWS CLI module loaded successfully (KISS version)"