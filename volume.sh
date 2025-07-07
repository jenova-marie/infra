#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Volume Management
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: EBS volume attachment and detachment for EC2 instances
# Author: Infrastructure Management System v2.0
# Last Updated: May 26, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Volume Resolution and Validation
# ─────────────────────────────────────────────────────────────────────────────

# Resolve volume identifier (name or ID) to volume name
# Usage: resolve_volume_name "dev" "athena-blog" or "vol-123456"
resolve_volume_name() {
    local env="$1"
    local volume_identifier="$2"
    
    debug_message "Resolving volume identifier: $volume_identifier"
    
    # ONLY use centralized outputs - no fallbacks
    local env_path="$(get_environment_path "$env")"
    local ebs_outputs_file="$env_path/outputs/ebss.json"
    
    # Strict validation - centralized outputs must exist
    if [[ ! -f "$ebs_outputs_file" ]]; then
        handle_error "EBS outputs not found at: $ebs_outputs_file. Run: ./infra output $env:ebss"
    fi
    
    debug_message "Using centralized EBS outputs: $ebs_outputs_file"
    
    # Check if identifier exists as volume name (preferred method)
    local volume_exists=$(jq -r --arg vol_name "$volume_identifier" '
        .volume_ids.value | has($vol_name)
    ' "$ebs_outputs_file" 2>/dev/null)
    
    if [[ "$volume_exists" == "true" ]]; then
        debug_message "Volume identifier is a valid volume name: $volume_identifier"
        echo "$volume_identifier"
        return 0
    fi
    
    # Try to resolve as volume ID
    local volume_name=$(jq -r --arg vol_id "$volume_identifier" '
        .volume_ids.value | to_entries[] | select(.value == $vol_id) | .key
    ' "$ebs_outputs_file" 2>/dev/null)
    
    if [[ -n "$volume_name" && "$volume_name" != "null" ]]; then
        debug_message "Resolved volume ID $volume_identifier to volume name: $volume_name"
        echo "$volume_name"
        return 0
    fi
    
    # Show available volumes for debugging
    debug_message "Available volumes:"
    jq -r '.volume_ids.value | to_entries[] | "  \(.key): \(.value)"' "$ebs_outputs_file" 2>/dev/null || debug_message "  (Unable to parse outputs)"
    
    handle_error "Volume '$volume_identifier' not found (tried as both name and ID). Check: $ebs_outputs_file"
}

# Get volume ID from volume name
# Usage: get_volume_id "dev" "athena-blog"
get_volume_id() {
    local env="$1"
    local volume_name="$2"
    
    debug_message "Getting volume ID for volume name: $volume_name"
    
    # ONLY use centralized outputs - no fallbacks
    local env_path="$(get_environment_path "$env")"
    local ebs_outputs_file="$env_path/outputs/ebss.json"
    
    # Strict validation - centralized outputs must exist
    if [[ ! -f "$ebs_outputs_file" ]]; then
        handle_error "EBS outputs not found at: $ebs_outputs_file. Run: ./infra output $env:ebss"
    fi
    
    local volume_id=$(jq -r ".volume_ids.value.\"$volume_name\" // empty" "$ebs_outputs_file" 2>/dev/null)
    
    if [[ -n "$volume_id" && "$volume_id" != "null" ]]; then
        debug_message "Volume ID for $volume_name: $volume_id"
        echo "$volume_id"
        return 0
    fi
    
    handle_error "Could not find volume ID for volume name: $volume_name in: $ebs_outputs_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Device Name Management
# ─────────────────────────────────────────────────────────────────────────────

# Get next available device name for volume attachment
# Usage: get_next_device_name "/path/to/volumes.yml"
get_next_device_name() {
    local volumes_file="$1"
    
    debug_message "Finding next available device name"
    
    # Available device names for EBS volumes
    local device_names=("/dev/sdf" "/dev/sdg" "/dev/sdh" "/dev/sdi" "/dev/sdj" "/dev/sdk" "/dev/sdl" "/dev/sdm" "/dev/sdn" "/dev/sdo" "/dev/sdp")
    
    # Get currently used device names
    local used_devices=()
    if [[ -f "$volumes_file" ]]; then
        while IFS= read -r device; do
            [[ -n "$device" && "$device" != "null" ]] && used_devices+=("$device")
        done < <(yq eval '.[] | .device_name' "$volumes_file" 2>/dev/null || true)
    fi
    
    debug_message "Currently used devices: $(safe_array_string "used_devices")"
    
    # Find first available device
    for device in "${device_names[@]}"; do
        local is_used=false
        if safe_array_has_elements "used_devices"; then
            while IFS= read -r used; do
                if [[ -n "$used" && "$device" == "$used" ]]; then
                    is_used=true
                    break
                fi
            done < <(safe_array_iterate "used_devices")
        fi
        
        if [[ "$is_used" == false ]]; then
            debug_message "Next available device: $device"
            echo "$device"
            return 0
        fi
    done
    
    handle_error "No available device names. All devices (/dev/sdf through /dev/sdp) are in use"
}

# ─────────────────────────────────────────────────────────────────────────────
# Volume State Checking
# ─────────────────────────────────────────────────────────────────────────────

# Check if volume is currently attached to instance
# Usage: is_volume_attached "dev" "athena" "athena-blog"
is_volume_attached() {
    local env="$1"
    local instance="$2"
    local volume_name="$3"
    
    debug_message "Checking if volume $volume_name is attached to instance $instance"
    
    # Get volume ID from centralized outputs
    local volume_id
    if ! volume_id=$(get_volume_id "$env" "$volume_name"); then
        debug_message "Could not get volume ID for $volume_name"
        return 1
    fi
    
    # ONLY use centralized instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs="$env_path/outputs/$instance.json"
    
    if [[ ! -f "$instance_outputs" ]]; then
        debug_message "Instance outputs not found at: $instance_outputs. Run: ./infra output $env:$instance"
        return 1
    fi
    
    # Check if volume ID is in ebs_attachments
    if jq -e --arg vol_id "$volume_id" '
        .ebs_attachments.value | 
        to_entries[] | 
        .value | 
        to_entries[] | 
        select(.value.volume_id == $vol_id)
    ' "$instance_outputs" >/dev/null 2>&1; then
        debug_message "Volume $volume_name ($volume_id) is attached to $instance"
        return 0
    fi
    
    debug_message "Volume $volume_name ($volume_id) is not attached to $instance"
    return 1
}

# Get device name for attached volume
# Usage: get_attached_device "dev" "athena" "athena-blog"
get_attached_device() {
    local env="$1"
    local instance="$2"
    local volume_name="$3"
    
    debug_message "Getting attached device for volume $volume_name on instance $instance"
    
    # Get volume ID from centralized outputs
    local volume_id
    if ! volume_id=$(get_volume_id "$env" "$volume_name"); then
        return 1
    fi
    
    # ONLY use centralized instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs="$env_path/outputs/$instance.json"
    
    if [[ ! -f "$instance_outputs" ]]; then
        debug_message "Instance outputs not found at: $instance_outputs"
        return 1
    fi
    
    local device=$(jq -r --arg vol_id "$volume_id" '
        .ebs_attachments.value | 
        to_entries[] | 
        .value | 
        to_entries[] | 
        select(.value.volume_id == $vol_id) | 
        .value.device_name
    ' "$instance_outputs" 2>/dev/null)
    
    if [[ -n "$device" && "$device" != "null" ]]; then
        debug_message "Volume $volume_name is attached to device: $device"
        echo "$device"
        return 0
    fi
    
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Volume Configuration Management
# ─────────────────────────────────────────────────────────────────────────────

# File operations abstraction for better testability
# These can be easily mocked in tests without complex setup

# Copy file with optional dry-run support
# Usage: file_copy "source" "destination"
file_copy() {
    local source="$1"
    local destination="$2"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        debug_message "[DRY-RUN] Would copy: $source -> $destination"
        return 0
    fi
    
    cp "$source" "$destination"
}

# Remove file with optional dry-run support  
# Usage: file_remove "file_path"
file_remove() {
    local file_path="$1"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        debug_message "[DRY-RUN] Would remove: $file_path"
        return 0
    fi
    
    rm -f "$file_path"
}

# Get timestamp for backup files
# Usage: get_backup_timestamp
get_backup_timestamp() {
    date +%Y%m%d_%H%M%S
}

# Manage backup files - create if backup mode enabled, cleanup old ones
# Usage: manage_backup_files "/path/to/volumes.yml"
manage_backup_files() {
    local volumes_file="$1"
    local backup_file=""
    
    # Only create backup if backup mode is enabled and file exists
    if is_backup && [[ -f "$volumes_file" ]]; then
        backup_file="$volumes_file.backup.$(get_backup_timestamp)"
        file_copy "$volumes_file" "$backup_file"
        debug_message "Created backup: $backup_file"
        
        # Clean up old backup files - keep only 3 most recent
        cleanup_old_backups "$volumes_file"
    elif is_backup; then
        debug_message "Backup mode enabled but volumes.yml does not exist - no backup created"
    else
        debug_message "Backup mode disabled - no backup created"
    fi
    
    echo "$backup_file"  # Return backup file path (empty if none created)
}

# Clean up old backup files, keeping only the 3 most recent
# Usage: cleanup_old_backups "/path/to/volumes.yml"
cleanup_old_backups() {
    local volumes_file="$1"
    local backup_pattern="$volumes_file.backup.*"
    
    debug_message "Cleaning up old backup files for: $volumes_file"
    
    # Find all backup files and sort by modification time (newest first)
    local backup_files=()
    while IFS= read -r -d '' file; do
        backup_files+=("$file")
    done < <(find "$(dirname "$volumes_file")" -name "$(basename "$volumes_file").backup.*" -print0 2>/dev/null | sort -z)
    
    # If we have more than 3 backup files, remove the oldest ones
    local backup_count=${#backup_files[@]}
    if [[ $backup_count -gt 3 ]]; then
        debug_message "Found $backup_count backup files, keeping 3 most recent"
        
        # Sort by modification time (newest first) and remove oldest
        local sorted_backups=()
        while IFS= read -r -d '' file; do
            sorted_backups+=("$file")
        done < <(printf '%s\0' "${backup_files[@]}" | xargs -0 ls -t)
        
        # Remove files beyond the first 3
        for (( i=3; i<${#sorted_backups[@]}; i++ )); do
            local old_backup="${sorted_backups[$i]}"
            debug_message "Removing old backup: $old_backup"
            file_remove "$old_backup"
        done
        
        debug_message "Backup cleanup completed - kept 3 most recent files"
    else
        debug_message "Found $backup_count backup files - no cleanup needed"
    fi
}

# Update volumes.yml for volume attachment
# Usage: update_volumes_yml_attach "/path/to/volumes.yml" "athena-blog" "/dev/sdf"
update_volumes_yml_attach() {
    local volumes_file="$1"
    local volume_name="$2"
    local device_name="$3"
    
    debug_message "Updating volumes.yml for attachment: $volume_name -> $device_name"
    
    # Check for dry-run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        dry_run_message "[DRY-RUN] Would update volumes.yml: $volumes_file"
        dry_run_message "[DRY-RUN] Would add volume '$volume_name' with device '$device_name'"
        if [[ ! -s "$volumes_file" ]]; then
            dry_run_message "[DRY-RUN] Would create new volumes.yml file"
        else
            dry_run_message "[DRY-RUN] Would update existing volumes.yml file"
        fi
        return 0
    fi
    
    if [[ ! -s "$volumes_file" ]]; then
        # Create new file
        debug_message "Creating new volumes.yml file"
        cat > "$volumes_file" << EOF
$volume_name:
  device_name: $device_name
EOF
    else
        # Update existing file
        debug_message "Adding volume to existing volumes.yml"
        yq eval ".\"$volume_name\".device_name = \"$device_name\"" -i "$volumes_file"
    fi
    
    debug_message "Updated volumes.yml successfully"
}

# Update volumes.yml for volume detachment
# Usage: update_volumes_yml_detach "/path/to/volumes.yml" "athena-blog"
update_volumes_yml_detach() {
    local volumes_file="$1"
    local volume_name="$2"
    
    debug_message "Updating volumes.yml for detachment: $volume_name"
    
    # Check for dry-run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        dry_run_message "[DRY-RUN] Would update volumes.yml: $volumes_file"
        dry_run_message "[DRY-RUN] Would remove volume '$volume_name'"
        if [[ ! -f "$volumes_file" ]]; then
            dry_run_message "[DRY-RUN] volumes.yml does not exist - nothing to detach"
        else
            dry_run_message "[DRY-RUN] Would remove volume from existing volumes.yml"
        fi
        return 0
    fi
    
    if [[ ! -f "$volumes_file" ]]; then
        debug_message "volumes.yml does not exist - nothing to detach"
        return 0
    fi
    
    # Remove volume from file
    yq eval "del(.\"$volume_name\")" -i "$volumes_file"
    
    # If file is now empty, create empty YAML object instead of deleting
    if [[ "$(yq eval '. | length' "$volumes_file" 2>/dev/null)" == "0" ]]; then
        debug_message "Creating empty volumes.yml file with {}"
        echo "{}" > "$volumes_file"
    fi
    
    debug_message "Updated volumes.yml successfully"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Volume Operations
# ─────────────────────────────────────────────────────────────────────────────

# Process volume attachment
# Usage: process_volume_attach "dev" "athena" "athena-blog"
process_volume_attach() {
    local env="$1"
    local instance="$2"
    local volume_name="$3"
    
    debug_message "Processing volume attachment: $volume_name to $instance"
    
    # FAST PATH: Check if already attached using optimized method
    if is_volume_attached_fast "$env" "$instance" "$volume_name"; then
        success_message "🚀 Volume $volume_name is already attached to $instance - returning quickly!"
        return 3  # Special return code for "already attached, no action needed"
    fi
    
    # Get volume ID for further processing
    local volume_id
    if ! volume_id=$(get_volume_id "$env" "$volume_name"); then
        return 1
    fi
    
    debug_message "Volume ID for $volume_name: $volume_id"
    
    # Get volumes.yml path
    local env_path="$(get_environment_path "$env")"
    local volumes_file="$env_path/$instance/volumes.yml"
    
    # Get next available device
    local device_name
    if ! device_name=$(get_next_device_name "$volumes_file"); then
        return 1
    fi
    
    info_message "Attaching volume $volume_name ($volume_id) to $instance on device $device_name"
    
    # Update volumes.yml
    update_volumes_yml_attach "$volumes_file" "$volume_name" "$device_name"
    
    return 0  # Success, proceed with apply
}

# Process volume detachment
# Usage: process_volume_detach "dev" "athena" "athena-blog"
process_volume_detach() {
    local env="$1"
    local instance="$2"
    local volume_name="$3"
    
    debug_message "Processing volume detachment: $volume_name from $instance"
    
    # FAST PATH: Check if already detached using optimized method
    if ! is_volume_attached_fast "$env" "$instance" "$volume_name"; then
        # Check if we still need to clean up volumes.yml
        local env_path="$(get_environment_path "$env")"
        local volumes_file="$env_path/$instance/volumes.yml"
        
        if [[ -f "$volumes_file" ]] && yq eval "has(\"$volume_name\")" "$volumes_file" 2>/dev/null | grep -q "true"; then
            warn_message "Volume $volume_name is not attached but still configured in volumes.yml - cleaning up"
            update_volumes_yml_detach "$volumes_file" "$volume_name"
            return 0  # Apply to clean up configuration
        fi
        
        success_message "🚀 Volume $volume_name is already detached from $instance - returning quickly!"
        return 3  # Special return code for "already detached, no action needed"
    fi
    
    # Get volume ID for verification
    local volume_id
    if ! volume_id=$(get_volume_id "$env" "$volume_name"); then
        warn_message "Could not find volume ID for $volume_name in EBS outputs"
        return 1
    fi
    
    debug_message "Volume ID for $volume_name: $volume_id"
    
    # Find which device the volume is attached to
    local device
    if device=$(get_attached_device "$env" "$instance" "$volume_name"); then
        info_message "Detaching volume $volume_name ($volume_id) from $instance (device $device)"
    else
        info_message "Detaching volume $volume_name ($volume_id) from $instance"
    fi
    
    # Get volumes.yml path
    local env_path="$(get_environment_path "$env")"
    local volumes_file="$env_path/$instance/volumes.yml"
    
    # Check if volume is configured in volumes.yml
    if [[ ! -f "$volumes_file" ]] || ! yq eval "has(\"$volume_name\")" "$volumes_file" 2>/dev/null | grep -q "true"; then
        warn_message "Volume $volume_name is attached in AWS but not configured in volumes.yml"
        warn_message "This indicates manual attachment - creating volumes.yml entry first"
        
        # We need to add it to volumes.yml so terraform can manage the detachment
        local current_device="${device:-/dev/sdf}"
        update_volumes_yml_attach "$volumes_file" "$volume_name" "$current_device"
        
        warn_message "Added volume to volumes.yml - you may need to run the detach command again"
        return 1
    fi
    
    # Remove volume from volumes.yml (this is what triggers terraform detachment)
    update_volumes_yml_detach "$volumes_file" "$volume_name"
    
    return 0  # Success, proceed with apply
}

# Apply volume changes using terragrunt
# Usage: apply_volume_changes "dev" "athena" "attach"
apply_volume_changes() {
    local env="$1"
    local instance="$2"
    local action="$3"
    local volume_name="$4"
    
    debug_message "Applying volume changes for $instance using terragrunt"
    
    local env_path="$(get_environment_path "$env")"
    local instance_path="$env_path/$instance"
    local volumes_file="$instance_path/volumes.yml"
    
    # Check for dry-run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        dry_run_message "[DRY-RUN] Would apply volume changes for $instance"
        dry_run_message "[DRY-RUN] Would change to directory: $instance_path"
        dry_run_message "[DRY-RUN] Would execute: terragrunt apply --auto-approve --non-interactive"
        if [[ "$action" == "detach" ]]; then
            dry_run_message "[DRY-RUN] Would perform AWS CLI volume detachment for safety"
        fi
        dry_run_message "[DRY-RUN] Would verify outputs and refresh if needed"
        return 0
    fi
    
    # Create backup using the new backup management system
    local backup_file=""
    backup_file=$(manage_backup_files "$volumes_file")
    
    # Change to instance directory
    local original_dir=$(pwd)
    cd "$instance_path" || {
        handle_error "Failed to change directory to: $instance_path"
    }
    
    # Apply changes using terragrunt
    if terragrunt apply -auto-approve; then
        debug_message "Volume changes applied successfully for $instance"
        
        # Simple output refresh for attach operations
        if [[ "$action" == "attach" && -n "$volume_name" ]]; then
            debug_message "Refreshing outputs after volume attachment"
            refresh_instance_outputs "$env" "$instance"
        fi
        
        # For detach operations, also use AWS CLI to force detachment
        if [[ "$action" == "detach" ]]; then
            info_message "Performing AWS CLI volume detachment for safety"
            
            if aws_detach_volume "$env" "$instance" "$volume_name"; then
                success_message "AWS CLI volume detachment completed"
            else
                warn_message "AWS CLI volume detachment failed, but terragrunt apply succeeded"
            fi
        fi
    else
        # Restore backup on failure
        if [[ -n "$backup_file" && -f "$backup_file" ]]; then
            cp "$backup_file" "$volumes_file"
            warn_message "Restored volumes.yml from backup due to apply failure"
        fi
        cd "$original_dir"
        handle_error "Volume $action failed for $instance"
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    # Clean up backup on success only if backup mode is enabled
    if [[ -n "$backup_file" && -f "$backup_file" ]]; then
        if is_backup; then
            rm -f "$backup_file"
            debug_message "Removed backup file after successful apply (backup mode enabled)"
        else
            debug_message "Preserving backup file: $backup_file (backup mode disabled)"
        fi
    fi
    
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Volume Operation Entry Point
# ─────────────────────────────────────────────────────────────────────────────

# Execute volume operation (called from main infra script)
# Usage: execute_volume_operation_impl "dev" "athena" "athena-blog" "attach"
execute_volume_operation_impl() {
    local env="$1"
    local instance="$2"
    local volume_identifier="$3"
    local action="$4"
    
    debug_message "Starting volume operation: $action $volume_identifier for $instance in $env"
    
    # Resolve volume identifier to volume name
    local volume_name
    if ! volume_name=$(resolve_volume_name "$env" "$volume_identifier"); then
        return 1
    fi
    
    info_message "Volume operation: $action volume '$volume_name' for instance '$instance'"
    
    # Process the volume operation
    local process_result=0
    case "$action" in
        "attach")
            process_volume_attach "$env" "$instance" "$volume_name"
            process_result=$?
            ;;
        "detach")
            process_volume_detach "$env" "$instance" "$volume_name"
            process_result=$?
            ;;
        *)
            handle_error "Unknown volume action: $action"
            ;;
    esac
    
    # Handle the result
    case $process_result in
        0)
            # Normal processing - apply changes with volume name context
            if ! apply_volume_changes "$env" "$instance" "$action" "$volume_name"; then
                return 1
            fi
            
            # Output generation is now handled centrally in operations.sh
            debug_message "Volume changes applied successfully - outputs will be generated by main operations flow"
            ;;
        1)
            # Error occurred
            return 1
            ;;
        2)
            # Already in desired state - skip apply but outputs will still be generated for consistency
            info_message "Volume already in desired state - outputs will be regenerated for consistency"
            ;;
        3)
            # Already attached, no action needed
            info_message "Volume already attached - no action needed"
            return 0
            ;;
    esac
    
    success_message "Volume $action operation completed successfully"
    return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

debug_message "Volume module loaded successfully"

# ─────────────────────────────────────────────────────────────────────────────
# Volume State Checking - Enhanced with AWS CLI verification
# ─────────────────────────────────────────────────────────────────────────────

# Fast check if volume is currently attached using both outputs and AWS CLI verification
# Usage: is_volume_attached_fast "dev" "athena" "athena-blog"
is_volume_attached_fast() {
    local env="$1"
    local instance="$2"
    local volume_name="$3"
    
    debug_message "Fast checking if volume $volume_name is attached to instance $instance"
    
    # Step 1: Quick check using centralized outputs (if available)
    local env_path="$(get_environment_path "$env")"
    local instance_outputs="$env_path/outputs/$instance.json"
    local ebs_outputs="$env_path/outputs/ebss.json"
    
    # If we have both outputs files, do the fast output-based check first
    if [[ -f "$instance_outputs" && -f "$ebs_outputs" ]]; then
        debug_message "Using centralized outputs for fast volume check"
        
        # Get volume ID from outputs
        local volume_id=$(jq -r --arg vol_name "$volume_name" '
            .volume_ids.value[$vol_name] // empty
        ' "$ebs_outputs" 2>/dev/null)
        
        if [[ -n "$volume_id" && "$volume_id" != "null" ]]; then
            # Check if volume ID is in ebs_attachments
            if jq -e --arg vol_id "$volume_id" '
                .ebs_attachments.value | 
                to_entries[] | 
                .value | 
                to_entries[] | 
                select(.value.volume_id == $vol_id)
            ' "$instance_outputs" >/dev/null 2>&1; then
                
                # Step 2: Verify with AWS CLI for ultimate accuracy using aws.sh function
                local instance_id=$(jq -r '.instance_id.value // empty' "$instance_outputs" 2>/dev/null)
                
                if [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
                    debug_message "Verifying attachment with AWS CLI via aws.sh"
                    
                    # Use the proper function from aws.sh instead of duplicate implementation
                    case $(aws_is_volume_attached "$env" "$volume_id" "$instance_id") in
                        0)
                            info_message "✅ Volume $volume_name ($volume_id) is attached to $instance - verified via AWS CLI"
                            return 0  # Confirmed attached
                            ;;
                        1)
                            warn_message "⚠️  Outputs show attached but AWS CLI shows detached for $volume_name - outputs may be stale"
                            return 1  # AWS CLI says not attached (more reliable)
                            ;;
                        2)
                            debug_message "AWS CLI verification unavailable, trusting outputs"
                            info_message "Volume $volume_name ($volume_id) appears attached per outputs"
                            return 0  # Trust outputs when AWS CLI unavailable
                            ;;
                    esac
                else
                    debug_message "No instance ID available for AWS CLI verification"
                    info_message "Volume $volume_name ($volume_id) appears attached per outputs"
                    return 0  # Trust outputs
                fi
            fi
        fi
    fi
    
    # Step 3: If outputs not available, try AWS CLI direct lookup using aws.sh
    debug_message "Outputs not available, attempting AWS CLI direct lookup via aws.sh"
    
    # Try to get volume ID and instance ID for direct AWS CLI check
    local volume_id=""
    local instance_id=""
    
    # Get volume ID if EBS outputs exist (use aws.sh function for consistency)
    if [[ -f "$ebs_outputs" ]]; then
        volume_id=$(get_volume_id_from_outputs "$env" "$volume_name" 2>/dev/null || echo "")
    fi
    
    # Get instance ID if instance outputs exist
    if [[ -f "$instance_outputs" ]]; then
        instance_id=$(jq -r '.instance_id.value // empty' "$instance_outputs" 2>/dev/null)
    fi
    
    # If we have both IDs, check with AWS CLI using aws.sh function
    if [[ -n "$volume_id" && "$volume_id" != "null" && -n "$instance_id" && "$instance_id" != "null" ]]; then
        debug_message "Using AWS CLI for direct volume attachment check via aws.sh"
        
        case $(aws_is_volume_attached "$env" "$volume_id" "$instance_id") in
            0)
                info_message "✅ Volume $volume_name ($volume_id) is attached to $instance - verified via AWS CLI"
                return 0  # Confirmed attached
                ;;
            1)
                debug_message "Volume $volume_name ($volume_id) is not attached to $instance per AWS CLI"
                return 1  # Not attached
                ;;
            2)
                debug_message "AWS CLI check failed, cannot determine attachment status"
                return 1  # Cannot verify, assume not attached
                ;;
        esac
    fi
    
    debug_message "Cannot determine volume attachment status - outputs or AWS CLI unavailable"
    return 1  # Cannot verify, assume not attached
}

# ─────────────────────────────────────────────────────────────────────────────
# Output Refresh
# ─────────────────────────────────────────────────────────────────────────────

# Simple output refresh for instance
# Usage: refresh_instance_outputs "dev" "athena"
refresh_instance_outputs() {
    local env="$1"
    local instance="$2"
    
    debug_message "Refreshing outputs for $instance using direct terragrunt approach"
    
    # Get the module path
    local env_path="$(get_environment_path "$env")"
    local instance_path="$env_path/$instance"
    
    # Change to instance directory and run terragrunt output directly
    local original_dir=$(pwd)
    if cd "$instance_path"; then
        debug_message "Changed to directory: $instance_path"
        
        # Run terragrunt output --json directly
        if terragrunt output --json > output.json 2>/dev/null; then
            debug_message "Outputs refreshed successfully for $instance"
            
            # Use existing centralized copy function from output.sh
            copy_module_outputs_to_centralized "$instance" "$env"
            
            cd "$original_dir"
            return 0
        else
            debug_message "Failed to generate outputs for $instance"
            cd "$original_dir"
            return 1
        fi
    else
        debug_message "Failed to change to directory: $instance_path"
        return 1
    fi
} 