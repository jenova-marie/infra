#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - AWS CLI Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: AWS CLI operations and direct API interactions
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# AWS Region Management
# ─────────────────────────────────────────────────────────────────────────────

# Get AWS region from environment's root.hcl (for environment-level operations)
# Usage: get_aws_region "dev"
get_aws_region() {
    local env="$1"
    
    debug_message "Getting AWS region for environment: $env"
    
    # Get environment path
    local env_path="$(get_environment_path "$env")"
    local root_hcl="$env_path/root.hcl"
    
    # Strict validation - root.hcl must exist
    if [[ ! -f "$root_hcl" ]]; then
        handle_error "Environment root.hcl not found at: $root_hcl"
    fi
    
    debug_message "Using root.hcl: $root_hcl"
    
    # Extract aws_region from root.hcl using grep and sed
    local aws_region=$(grep 'aws_region.*=' "$root_hcl" | sed -E 's/.*aws_region.*=.*"([^"]+)".*/\1/' | head -1)
    
    if [[ -n "$aws_region" && "$aws_region" != "aws_region" ]]; then
        debug_message "Found AWS region: $aws_region"
        echo "$aws_region"
        return 0
    fi
    
    # Fallback: try to extract from locals block more specifically
    aws_region=$(awk '/locals.*{/,/}/' "$root_hcl" | grep 'aws_region' | sed -E 's/.*=.*"([^"]+)".*/\1/' | head -1)
    
    if [[ -n "$aws_region" && "$aws_region" != "aws_region" ]]; then
        debug_message "Found AWS region (fallback): $aws_region"
        echo "$aws_region"
        return 0
    fi
    
    handle_error "Could not extract aws_region from: $root_hcl. Expected format: aws_region = \"us-west-2\""
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS CLI Availability Validation
# ─────────────────────────────────────────────────────────────────────────────

# Check if AWS CLI is available and configured
# Usage: validate_aws_cli
validate_aws_cli() {
    debug_message "Validating AWS CLI availability and configuration"
    
    # Get the full path to AWS CLI to avoid shell configuration issues
    local aws_path
    if ! aws_path=$(command -v aws); then
        debug_message "AWS CLI is not installed"
        return 1
    fi
    
    debug_message "Using AWS CLI at: $aws_path"
    
    # Check if AWS credentials are configured using full path
    # Set a default region to avoid endpoint issues
    local aws_output
    if ! aws_output=$(AWS_DEFAULT_REGION="${AWS_REGION:-us-east-2}" "$aws_path" sts get-caller-identity --region "${AWS_REGION:-us-east-2}" 2>&1); then
        debug_message "AWS CLI is not configured or credentials are invalid"
        debug_message "AWS CLI error output: $aws_output"
        return 1
    fi
    
    debug_message "AWS CLI validation successful"
    return 0
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
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        warn_message "AWS CLI not available for volume detachment"
        return 1
    fi
    
    # Get AWS region for this instance (using outputs API)
    local aws_region
    if ! aws_region=$(get_instance_aws_region_from_outputs "$env" "$instance_name"); then
        return 1
    fi
    
    debug_message "AWS region: $aws_region"
    
    # Get volume ID and instance ID from outputs API
    local volume_id
    local instance_id
    
    # Get volume ID using outputs API
    if ! volume_id=$(get_volume_id_from_outputs "$env" "$volume_name"); then
        warn_message "Could not get volume ID for $volume_name"
        return 1
    fi
    
    # Get instance ID using outputs API
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance_name"); then
        warn_message "Could not get instance ID for $instance_name"
        return 1
    fi
    
    debug_message "Volume ID: $volume_id"
    debug_message "Instance ID: $instance_id"
    
    # Build the AWS CLI command
    local aws_command="aws ec2 detach-volume --volume-id $volume_id --region $aws_region"
    
    # Add force flag if specified
    if is_force; then
        aws_command="$aws_command --force"
        debug_message "Force detachment enabled"
    fi
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would detach volume: $volume_id from instance $instance_id"
        dry_run_message "[DRY-RUN] AWS CLI command: $aws_command"
        return 0
    fi
    
    info_message "🔄 Detaching volume $volume_name ($volume_id) from $instance_name using AWS CLI..."
    debug_message "Executing AWS CLI command: $aws_command"
    
    # Execute AWS CLI detach command with proper error capture
    local aws_output=""
    
    # Capture both stdout and stderr
    if aws_output=$(aws ec2 detach-volume --volume-id "$volume_id" --region "$aws_region" $(is_force && echo "--force") 2>&1); then
        debug_message "AWS CLI command executed successfully"
        debug_message "AWS CLI output: $aws_output"
        success_message "✅ Volume detachment command sent successfully"
        info_message "Volume will detach and may take a moment to complete"
        return 0
    else
        local exit_code=$?
        debug_message "AWS CLI command failed with exit code: $exit_code"
        debug_message "AWS CLI command: $aws_command"
        debug_message "AWS CLI error output: $aws_output"
        warn_message "AWS CLI volume detachment failed: $aws_output"
        return 1
    fi
}


# ─────────────────────────────────────────────────────────────────────────────
# Fast Volume Verification via AWS CLI
# ─────────────────────────────────────────────────────────────────────────────

# Fast check if volume is attached using AWS CLI (no outputs required)
# Usage: aws_is_volume_attached "dev" "vol-123456" "i-123456"
aws_is_volume_attached() {
    local env="$1"
    local volume_id="$2"
    local instance_id="$3"
    
    debug_message "AWS CLI: Fast checking if volume $volume_id is attached to instance $instance_id"
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        debug_message "AWS CLI not available for fast volume check"
        return 2  # Cannot verify
    fi
    
    # Get AWS region for this environment
    local aws_region
    if ! aws_region=$(get_aws_region "$env"); then
        debug_message "Cannot get AWS region for fast volume check"
        return 2  # Cannot verify
    fi
    
    # Use AWS CLI to check volume attachment status directly
    local aws_output=""
    if aws_output=$(aws ec2 describe-volumes \
        --volume-ids "$volume_id" \
        --region "$aws_region" \
        --query "Volumes[0].Attachments[?InstanceId=='$instance_id']" \
        --output json 2>/dev/null); then
        
        # Check if the query returned any attachments
        local attachment_count=$(echo "$aws_output" | jq '. | length' 2>/dev/null)
        
        if [[ "$attachment_count" -gt 0 ]]; then
            debug_message "AWS CLI: Volume $volume_id is attached to instance $instance_id"
            return 0  # Attached
        else
            debug_message "AWS CLI: Volume $volume_id is NOT attached to instance $instance_id"
            return 1  # Not attached
        fi
    else
        debug_message "AWS CLI: Failed to query volume $volume_id attachment status"
        return 2  # Cannot verify
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Reboot Operations
# ─────────────────────────────────────────────────────────────────────────────

# Execute instance reboot operation
# Usage: execute_reboot_operation
execute_reboot_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Executing reboot operation for instance: $OP_TARGET_TYPE"
    log_phase "SSH shutdown + AWS start reboot"
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        warn_message "AWS CLI not available for reboot operation"
        return 1
    fi
    
    # Parse target to extract instance name
    local instance_name
    if [[ "$OP_TARGET_TYPE" == *":"* ]]; then
        # Handle env:instance format, extract just instance name
        instance_name="${OP_TARGET_TYPE#*:}"
    else
        instance_name="$OP_TARGET_TYPE"
    fi
    
    debug_message "Target instance name: $instance_name"
    
    # Get AWS region for this instance (using outputs API)
    local aws_region
    if ! aws_region=$(get_instance_aws_region_from_outputs "$OP_ENV" "$instance_name"); then
        return 1
    fi
    
    debug_message "AWS region: $aws_region"
    
    # Get instance ID using outputs API
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$OP_ENV" "$instance_name"); then
        return 1
    fi
    
    info_message "🔄 Starting SSH shutdown + AWS start reboot for $instance_name..."
    
    # Step 1: SSH shutdown using remote script
    info_message "🛑 Step 1/3: SSH shutdown using remote script..."
    local hostname="${instance_name}-${OP_ENV}.recoverysky.dev"
    local ssh_user="ec2-user"
    local remote_command="~/scripts/shutdown.sh"
    
    info_message "📡 Connecting to $instance_name ($hostname) for graceful shutdown..."
    debug_message "SSH command: ssh $ssh_user@$hostname '$remote_command'"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would execute SSH shutdown: $ssh_user@$hostname '$remote_command'"
        dry_run_message "[DRY-RUN] Would wait for instance to stop: $instance_id"
        dry_run_message "[DRY-RUN] Would start instance: $instance_id"
        success_message "✅ SSH + AWS reboot (dry-run) completed successfully"
        return 0
    fi
    
    # Execute SSH shutdown
    if timeout 30 ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "$ssh_user@$hostname" "$remote_command" 2>/dev/null; then
        success_message "✅ SSH shutdown command sent successfully"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            success_message "✅ SSH shutdown command sent (connection timeout expected)"
        else
            warn_message "⚠️  SSH shutdown failed, attempting direct AWS reboot instead..."
            if reboot_instance "$instance_id" "$instance_name" "$aws_region"; then
                success_message "✅ Direct AWS reboot completed successfully"
                
                # Execute all post-operation actions in one call (KISS approach)
                execute_post_operation_actions "Direct AWS reboot completed"
                return 0
            else
                handle_error "Both SSH shutdown and direct AWS reboot failed"
            fi
        fi
    fi
    
    # Step 2: Wait for instance to stop
    info_message "⏳ Step 2/3: Waiting for instance to shutdown completely..."
    if wait_for_instance_shutdown "$OP_ENV" "$instance_name"; then
        success_message "✅ Instance shutdown completed"
    else
        warn_message "⚠️  Shutdown wait timed out, attempting to start anyway..."
    fi
    
    # Step 3: Start instance
    info_message "🚀 Step 3/3: Starting instance..."
    if start_instance "$instance_id" "$instance_name" "$aws_region"; then
        success_message "✅ SSH shutdown + AWS start reboot completed successfully"
        
        # Execute all post-operation actions in one call (KISS approach)
        execute_post_operation_actions "SSH + AWS reboot completed successfully"
    else
        handle_error "Instance start failed after SSH shutdown"
    fi
}


# Reboot a single instance using AWS CLI
# Usage: reboot_instance "i-1234567890abcdef0" "athena"
reboot_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    debug_message "Rebooting instance: $instance_id ($instance_name) in region: $aws_region"
    
    # Build the AWS CLI command
    local aws_command="aws ec2 reboot-instances --instance-ids $instance_id --region $aws_region"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would reboot instance: $instance_id ($instance_name)"
        dry_run_message "[DRY-RUN] AWS CLI command: $aws_command"
        return 0
    fi
    
    info_message "🔄 Rebooting instance $instance_name ($instance_id) in region: $aws_region..."
    debug_message "Executing AWS CLI command: $aws_command"
    
    # Execute AWS CLI reboot command with proper error capture
    local aws_output=""
    local aws_error=""
    
    # Capture both stdout and stderr
    if aws_output=$(aws ec2 reboot-instances --instance-ids "$instance_id" --region "$aws_region" 2>&1); then
        debug_message "AWS CLI command executed successfully"
        debug_message "AWS CLI output: $aws_output"
        success_message "✅ Reboot command sent successfully for $instance_name"
        info_message "Instance will reboot and may take a few minutes to become available"
        return 0
    else
        local exit_code=$?
        debug_message "AWS CLI command failed with exit code: $exit_code"
        debug_message "AWS CLI command: $aws_command"
        debug_message "AWS CLI error output: $aws_output"
        handle_error "AWS CLI reboot failed: $aws_output"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Generic Instance State Waiting (DRY implementation)
# ─────────────────────────────────────────────────────────────────────────────

# Generic function to wait for any instance state with configurable options
# Usage: wait_for_instance_state "dev" "athena" "running" [timeout] [initial_wait] [poll_interval] [operation_description]
wait_for_instance_state() {
    local env="$1"
    local instance_name="$2"
    local target_state="$3"
    local timeout="${4:-300}"        # Default 5 minutes
    local initial_wait="${5:-0}"     # Default no initial wait
    local poll_interval="${6:-1}"    # Default 1 second polling
    local operation_desc="${7:-state change}"  # Default description
    
    debug_message "Waiting for instance $instance_name to reach state: $target_state"
    debug_message "Parameters: timeout=${timeout}s, initial_wait=${initial_wait}s, poll_interval=${poll_interval}s"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would wait for instance $instance_name to reach $target_state state"
        dry_run_message "[DRY-RUN] Would monitor AWS EC2 with ${timeout}s timeout and ${poll_interval}s polling"
        if [[ $initial_wait -gt 0 ]]; then
            dry_run_message "[DRY-RUN] Would wait ${initial_wait}s initially before polling"
        fi
        return 0
    fi
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        warn_message "AWS CLI not available for $operation_desc monitoring"
        return 1
    fi
    
    # Initial wait period (useful for reboot scenarios where state might be stale)
    if [[ $initial_wait -gt 0 ]]; then
        info_message "⏳ Waiting ${initial_wait}s before monitoring $operation_desc for $instance_name..."
        sleep "$initial_wait"
    fi
    
    local start_time=$(date +%s)
    local expected_time_msg=""
    
    # Set expected time message based on target state
    case "$target_state" in
        "running")
            expected_time_msg="(expected ~30-60 seconds)"
            ;;
        "stopped")
            expected_time_msg="(expected ~20-30 seconds)"
            ;;
        "terminated")
            expected_time_msg="(timeout: $((timeout/60)) minutes)"
            ;;
        *)
            expected_time_msg="(timeout: $((timeout/60)) minutes)"
            ;;
    esac
    
    info_message "⏳ Monitoring $operation_desc for $instance_name $expected_time_msg..."
    
    while true; do
        # Get current instance state using existing function
        local current_state=""
        if current_state=$(get_instance_status "$env" "$instance_name"); then
            debug_message "$instance_name current state: $current_state (target: $target_state)"
            
            # Check if we've reached target state
            if [[ "$current_state" == "$target_state" ]]; then
                success_message "✅ $instance_name has reached $target_state state!"
                    return 0
            fi
            
            # Handle error states based on target
            case "$target_state" in
                "running")
                    case "$current_state" in
                        "stopping"|"shutting-down"|"terminated")
                            warn_message "⚠️  Instance $instance_name is $current_state - cannot reach running state"
                            return 1
                    ;;
                        "stopped")
                            warn_message "⚠️  Instance $instance_name went to stopped state instead of running"
                            return 1
                            ;;
                    esac
                    ;;
                "stopped")
                    case "$current_state" in
                        "shutting-down"|"terminated")
                            warn_message "⚠️  Instance $instance_name is being terminated, not stopped"
                            return 1
                    ;;
            esac
                    ;;
                "terminated")
                    # For termination, any other final state is acceptable to continue monitoring
                    case "$current_state" in
                        "running"|"stopped"|"pending"|"stopping"|"shutting-down")
                            # These are all expected transition states for termination
                            debug_message "$instance_name transitioning: $current_state -> termination"
                            ;;
                    esac
                    ;;
            esac
            
            # Log current state for progress tracking
            debug_message "$instance_name is in state: $current_state"
        else
            debug_message "Could not check state for $instance_name"
            current_state="unknown"
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            warn_message "⚠️  Timeout waiting for $instance_name to reach $target_state state"
            return 1
        fi
        
        # Show progress with appropriate color/emoji based on target state
        case "$target_state" in
            "terminated")
                print_message "🔴 $operation_desc status: $current_state (${elapsed}s elapsed)" "$RED" "ERROR"
                ;;
            *)
                info_message "✅ $operation_desc status: $current_state (${elapsed}s elapsed)"
                ;;
        esac
        
        sleep "$poll_interval"
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Shutdown Waiting (for SSH-initiated shutdowns)
# ─────────────────────────────────────────────────────────────────────────────

# Wait for single instance to reach stopped state after SSH shutdown
# Usage: wait_for_instance_shutdown "dev" "athena"
wait_for_instance_shutdown() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Waiting for instance shutdown: $instance_name"
    
    # Use generic function with 2-minute timeout for shutdown
    wait_for_instance_state "$env" "$instance_name" "stopped" 120 0 1 "shutdown"
}

# Wait for multiple instances to reach stopped state after SSH shutdown
# Usage: wait_for_multiple_instances_shutdown "dev" instance1 instance2 instance3
wait_for_multiple_instances_shutdown() {
    local env="$1"
    shift
    local instances=("$@")
    
    debug_message "Waiting for multiple instances shutdown: ${instances[*]}"
    
    # Handle dry-run mode
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would wait for ${#instances[@]} instances to reach stopped state: ${instances[*]}"
        dry_run_message "[DRY-RUN] Would use generic wait function for each instance"
        return 0
    fi
    
    info_message "⏳ Waiting for ${#instances[@]} instance(s) to shutdown..."
    
    # Use generic function for each instance and track results
    local failed_count=0
    local success_count=0
    
    for instance in "${instances[@]}"; do
        info_message "🔄 Checking shutdown status for $instance..."
        
        if wait_for_instance_state "$env" "$instance" "stopped" 120 0 1 "shutdown"; then
            success_count=$((success_count + 1))
            debug_message "Instance $instance shutdown completed"
        else
            failed_count=$((failed_count + 1))
            warn_message "Instance $instance shutdown failed or timed out"
            fi
        done
        
    # Display summary
    info_message "📈 Multiple instances shutdown summary:"
    info_message "  Total instances: ${#instances[@]}"
    info_message "  Successful: $success_count"
    info_message "  Failed: $failed_count"
    
    if [[ $failed_count -eq 0 ]]; then
        success_message "✅ All ${#instances[@]} instance(s) are now stopped"
            return 0
    else
        warn_message "⚠️  Some instances failed to shutdown ($success_count/${#instances[@]} succeeded)"
            return 1
        fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Start Operations (for reboot after SSH shutdown)
# ─────────────────────────────────────────────────────────────────────────────

# Start a single instance using AWS CLI
# Usage: start_instance "i-1234567890abcdef0" "athena" "us-east-2"
start_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    debug_message "Starting instance: $instance_id ($instance_name) in region: $aws_region"
    
    # Build the AWS CLI command
    local aws_command="aws ec2 start-instances --instance-ids $instance_id --region $aws_region"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would start instance: $instance_id ($instance_name)"
        dry_run_message "[DRY-RUN] AWS CLI command: $aws_command"
        return 0
    fi
    
    info_message "🚀 Starting instance $instance_name ($instance_id) in region: $aws_region..."
    debug_message "Executing AWS CLI command: $aws_command"
    
    # Execute AWS CLI start command with proper error capture
    local aws_output=""
    
    # Capture both stdout and stderr
    if aws_output=$(aws ec2 start-instances --instance-ids "$instance_id" --region "$aws_region" 2>&1); then
        debug_message "AWS CLI command executed successfully"
        debug_message "AWS CLI output: $aws_output"
        success_message "✅ Start command sent successfully for $instance_name"
        info_message "Instance will start and may take a few minutes to become available"
        return 0
    else
        local exit_code=$?
        debug_message "AWS CLI command failed with exit code: $exit_code"
        debug_message "AWS CLI command: $aws_command"
        debug_message "AWS CLI error output: $aws_output"
        handle_error "AWS CLI start failed: $aws_output"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Future AWS Operations (Placeholder)
# ─────────────────────────────────────────────────────────────────────────────

# TODO: Add more AWS operations as needed:
# - Instance start/stop
# - EBS snapshot management  
# - Security group modifications
# - CloudWatch logs retrieval
# - Parameter store operations

# ─────────────────────────────────────────────────────────────────────────────
# AWS Secrets Manager Operations - Secrets Protection System
# ─────────────────────────────────────────────────────────────────────────────

# Clear secrets for modules marked with destroy: false
# Usage: clear_secrets_for_destroy_disabled_modules "dev" "secrets"
clear_secrets_for_destroy_disabled_modules() {
    local env="$1"
    local target_type="$2"
    
    debug_message "Checking for destroy-disabled modules to clear secrets: env=$env, target=$target_type"
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        warn_message "AWS CLI not available for secrets clearing"
        return 1
    fi
    
    # Get target modules
    local target_modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && target_modules+=("$module")
    done < <(get_modules_for_target "$target_type")
    
    # Find modules with destroy: false
    local destroy_disabled_modules=()
    for module in "${target_modules[@]}"; do
        if is_module_destroy_disabled "$module"; then
            destroy_disabled_modules+=("$module")
            debug_message "Found destroy-disabled module: $module"
        fi
    done
    
    if [[ ${#destroy_disabled_modules[@]} -eq 0 ]]; then
        debug_message "No destroy-disabled modules found in target"
        return 0
    fi
    
    info_message "🔒 Found ${#destroy_disabled_modules[@]} destroy-disabled module(s): ${destroy_disabled_modules[*]}"
    info_message "🧹 Clearing secret values instead of destroying infrastructure..."
    
    # Clear secrets for each destroy-disabled module
    local success_count=0
    local failure_count=0
    
    for module in "${destroy_disabled_modules[@]}"; do
        if clear_module_secrets "$env" "$module"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    # Report results and handle failures
    if [[ $failure_count -eq 0 ]]; then
        success_message "✅ Successfully cleared secrets for $success_count module(s)"
        return 0
    else
        error_message "❌ Failed to clear secrets for $failure_count module(s)"
        error_message "Secret clearing is required for destroy-disabled modules"
        handle_error "Secrets clearing failed - operation aborted"
    fi
}

# Clear all secrets for a specific module
# Usage: clear_module_secrets "dev" "secrets"
clear_module_secrets() {
    local env="$1"
    local module="$2"
    
    debug_message "Clearing secrets for module: $module in environment: $env"
    
    # Get AWS region for this environment
    local aws_region
    if ! aws_region=$(get_aws_region "$env"); then
        error_message "Could not determine AWS region for environment: $env"
        return 1
    fi
    
    debug_message "Using AWS region: $aws_region"
    
    # Get secrets directory path
    local env_path="$(get_environment_path "$env")"
    local secrets_dir="$env_path/$module/secrets"
    
    debug_message "Scanning secrets directory: $secrets_dir"
    
    if [[ ! -d "$secrets_dir" ]]; then
        warn_message "Secrets directory not found: $secrets_dir"
        debug_message "Module $module may not have any secrets to clear"
        return 0
    fi
    
    # Find all .yml files in secrets directory
    local secret_files=()
    while IFS= read -r -d '' file; do
        secret_files+=("$file")
    done < <(find "$secrets_dir" -name "*.yml" -type f -print0 2>/dev/null)
    
    if [[ ${#secret_files[@]} -eq 0 ]]; then
        warn_message "No secret files (*.yml) found in: $secrets_dir"
        debug_message "Module $module has no secrets to clear"
        return 0
    fi
    
    info_message "🔍 Found ${#secret_files[@]} secret file(s) in $module module"
    
    # Process each secret file
    local cleared_count=0
    local failed_count=0
    
    for secret_file in "${secret_files[@]}"; do
        local filename=$(basename "$secret_file")
        info_message "📄 Processing secret file: $filename"
        
        if clear_secrets_from_file "$secret_file" "$aws_region"; then
            ((cleared_count++))
            success_message "✅ Cleared secrets from: $filename"
        else
            ((failed_count++))
            error_message "❌ Failed to clear secrets from: $filename"
        fi
    done
    
    # Report results for this module
    if [[ $failed_count -eq 0 ]]; then
        success_message "✅ Module $module: cleared $cleared_count secret file(s)"
        return 0
    else
        error_message "❌ Module $module: $failed_count secret file(s) failed to clear"
        return 1
    fi
}

# Clear secrets defined in a YAML file
# Usage: clear_secrets_from_file "/path/to/secrets.yml" "us-east-2"
clear_secrets_from_file() {
    local secret_file="$1"
    local aws_region="$2"
    
    debug_message "Clearing secrets from file: $secret_file"
    
    if [[ ! -f "$secret_file" ]]; then
        error_message "Secret file not found: $secret_file"
        return 1
    fi
    
    # Extract secret names from YAML file
    local secret_names=()
    while IFS= read -r secret_name; do
        if [[ -n "$secret_name" ]]; then
            secret_names+=("$secret_name")
            debug_message "Found secret in file: $secret_name"
        fi
    done < <(yq eval '.secrets | keys | .[]' "$secret_file" 2>/dev/null)
    
    if [[ ${#secret_names[@]} -eq 0 ]]; then
        warn_message "No secrets found in file: $secret_file"
        return 0
    fi
    
    debug_message "Found ${#secret_names[@]} secret(s) to clear: ${secret_names[*]}"
    
    # Clear each secret
    local success_count=0
    local failure_count=0
    
    for secret_key in "${secret_names[@]}"; do
        # Get the secret name/ARN from the YAML
        local secret_name=$(yq eval ".secrets.\"$secret_key\".name" "$secret_file" 2>/dev/null)
        
        if [[ -z "$secret_name" || "$secret_name" == "null" ]]; then
            error_message "Secret name not found for key: $secret_key"
            ((failure_count++))
            continue
        fi
        
        debug_message "Clearing secret: $secret_name (key: $secret_key)"
        
        if clear_aws_secret "$secret_name" "$aws_region"; then
            ((success_count++))
            info_message "  ✅ Cleared: $secret_name"
        else
            ((failure_count++))
            error_message "  ❌ Failed: $secret_name"
        fi
    done
    
    # Return success only if all secrets were cleared
    if [[ $failure_count -eq 0 ]]; then
        debug_message "Successfully cleared $success_count secret(s) from file"
        return 0
    else
        error_message "Failed to clear $failure_count secret(s) from file"
        return 1
    fi
}

# Clear a single AWS secret by setting its value to "infra.sh cleared"
# Usage: clear_aws_secret "secret-name" "us-east-2"
clear_aws_secret() {
    local secret_name="$1"
    local aws_region="$2"
    
    debug_message "Clearing AWS secret: $secret_name in region: $aws_region"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would clear AWS secret: $secret_name"
        dry_run_message "[DRY-RUN] AWS CLI command: aws secretsmanager update-secret --secret-id '$secret_name' --secret-string 'infra.sh cleared' --region $aws_region"
        return 0
    fi
    
    # Get the full path to AWS CLI to avoid shell configuration issues
    local aws_path
    if ! aws_path=$(command -v aws); then
        error_message "AWS CLI not found for secret clearing"
        return 1
    fi
    
    # Execute AWS CLI command to clear the secret
    local aws_output=""
    if aws_output=$(AWS_DEFAULT_REGION="$aws_region" "$aws_path" secretsmanager update-secret \
        --secret-id "$secret_name" \
        --secret-string "infra.sh cleared" \
        --region "$aws_region" 2>&1); then
        
        debug_message "AWS CLI command executed successfully"
        debug_message "AWS CLI output: $aws_output"
        return 0
    else
        local exit_code=$?
        debug_message "AWS CLI command failed with exit code: $exit_code"
        debug_message "AWS CLI error output: $aws_output"
        error_message "AWS CLI secret clearing failed for $secret_name: $aws_output"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "AWS CLI module loaded successfully"

# Wait for instance reboot completion (stops, then starts, then reaches running state)
# Usage: wait_for_instance_reboot_completion "dev" "athena"
wait_for_instance_reboot_completion() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Waiting for instance reboot completion: $instance_name"
    
    # Use generic function with 5-minute timeout and 20-second initial wait for reboot
    # Initial wait allows instance to transition from stale "running" to actual reboot cycle
    wait_for_instance_state "$env" "$instance_name" "running" 300 20 1 "reboot cycle"
}

# Get current instance status from AWS
# Usage: get_instance_status "dev" "athena"
# Returns: running, stopped, pending, stopping, shutting-down, terminated, etc.
get_instance_status() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Getting instance status for: $instance_name"
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        debug_message "AWS CLI not available for status check"
        return 1
    fi
    
    # Get AWS region for this instance (using outputs API)
    local aws_region
    if ! aws_region=$(get_instance_aws_region_from_outputs "$env" "$instance_name"); then
        debug_message "Cannot get AWS region for status check"
        return 1
    fi
    
    # Get instance ID using outputs API
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance_name"); then
        debug_message "Cannot get instance ID for status check"
        return 1
    fi
    
    # Get current instance state from AWS
    local state=""
    if state=$(aws ec2 describe-instances --instance-ids "$instance_id" --region "$aws_region" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null); then
        debug_message "Instance $instance_name status: $state"
        echo "$state"
        return 0
    else
        debug_message "Failed to get instance status for $instance_name"
        return 1
    fi
}

# Wait for instance start completion (reaches running state)
# Usage: wait_for_instance_start_completion "dev" "athena"
wait_for_instance_start_completion() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Waiting for instance start completion: $instance_name"
    
    # Use generic function with 3-minute timeout for start operations
    wait_for_instance_state "$env" "$instance_name" "running" 180 0 1 "start"
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Termination Operations (for SSH failures)
# ─────────────────────────────────────────────────────────────────────────────

# Terminate a single instance using AWS CLI (for SSH failures)
# Usage: terminate_instance "i-1234567890abcdef0" "athena" "us-east-2"
terminate_instance() {
    local instance_id="$1"
    local instance_name="$2"
    local aws_region="$3"
    
    debug_message "Terminating instance: $instance_id ($instance_name) in region: $aws_region"
    
    # Build the AWS CLI command
    local aws_command="aws ec2 terminate-instances --instance-ids $instance_id --region $aws_region"
    
    if is_dry_run; then
        dry_run_message "[DRY-RUN] Would terminate instance: $instance_id ($instance_name)"
        dry_run_message "[DRY-RUN] AWS CLI command: $aws_command"
        return 0
    fi
    
    # Report termination in blue to user (less aggressive than red)
    print_message "🔵 TERMINATING instance $instance_name ($instance_id)"
    
    # Execute the AWS CLI command
    if eval "$aws_command" >/dev/null 2>&1; then
        print_message "🔵 Termination command sent successfully for $instance_name"
        print_message "ℹ️  Instance will terminate and may take a few minutes to complete"
        return 0
    else
        warn_message "Failed to terminate instance: $instance_id ($instance_name)"
        return 1
    fi
}

# Wait for instance termination completion (reaches terminated state)
# Usage: wait_for_instance_termination "dev" "athena"
wait_for_instance_termination() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "Waiting for instance termination: $instance_name"
    
    # Use generic function with 5-minute timeout and 2-second polling for termination
    wait_for_instance_state "$env" "$instance_name" "terminated" 300 0 2 "termination"
}

# AWS CLI fallback termination for SSH failures (main entry point)
# Usage: aws_terminate_instance_on_ssh_failure "dev" "athena"
aws_terminate_instance_on_ssh_failure() {
    local env="$1"
    local instance_name="$2"
    
    debug_message "AWS CLI termination fallback for SSH failure: $instance_name"
    
    # Validate AWS CLI is available
    if ! validate_aws_cli; then
        warn_message "AWS CLI not available for termination fallback"
        return 1
    fi
    
    # Get AWS region for this instance (using outputs API)
    local aws_region
    if ! aws_region=$(get_instance_aws_region_from_outputs "$env" "$instance_name"); then
        return 1
    fi
    
    # Get instance ID using outputs API
    local instance_id
    if ! instance_id=$(get_instance_id_from_outputs "$env" "$instance_name"); then
        print_message "🔴 Could not get instance ID for $instance_name" "$RED" "ERROR"
        return 1
    fi
    
    debug_message "Instance ID: $instance_id"
    debug_message "AWS region: $aws_region"
    
    # Terminate the instance
    if terminate_instance "$instance_id" "$instance_name" "$aws_region"; then
        # Wait for termination to complete
        if wait_for_instance_termination "$env" "$instance_name"; then
            print_message "🔴 Instance $instance_name termination completed successfully" "$RED" "ERROR"
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