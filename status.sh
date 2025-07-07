#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Status Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Real-time infrastructure status monitoring with beautiful output
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Status Framework - Core Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

# Status result constants
readonly STATUS_ONLINE=0
readonly STATUS_OFFLINE=1
readonly STATUS_WARNING=2
readonly STATUS_UNKNOWN=3

# Global status tracking
STATUS_TOTAL_RESOURCES=0
STATUS_ONLINE_RESOURCES=0
STATUS_OFFLINE_RESOURCES=0
STATUS_WARNING_RESOURCES=0
STATUS_UNKNOWN_RESOURCES=0

# Initialize status framework
# Usage: init_status_framework
init_status_framework() {
    debug_message "Initializing infrastructure status framework"
    
    STATUS_TOTAL_RESOURCES=0
    STATUS_ONLINE_RESOURCES=0
    STATUS_OFFLINE_RESOURCES=0
    STATUS_WARNING_RESOURCES=0
    STATUS_UNKNOWN_RESOURCES=0
    
    debug_message "Status framework initialized"
}

# Record status result
# Usage: record_status_result "resource_name" status "details"
record_status_result() {
    local resource_name="$1"
    local status="$2"
    local details="${3:-}"
    
    ((STATUS_TOTAL_RESOURCES++))
    case "$status" in
        $STATUS_ONLINE) 
            ((STATUS_ONLINE_RESOURCES++))
            debug_message "🟢 $resource_name: ONLINE ($details)"
            ;;
        $STATUS_OFFLINE) 
            ((STATUS_OFFLINE_RESOURCES++))
            debug_message "🔴 $resource_name: OFFLINE ($details)"
            ;;
        $STATUS_WARNING) 
            ((STATUS_WARNING_RESOURCES++))
            debug_message "🟡 $resource_name: WARNING ($details)"
            ;;
        $STATUS_UNKNOWN) 
            ((STATUS_UNKNOWN_RESOURCES++))
            debug_message "⚪ $resource_name: UNKNOWN ($details)"
            ;;
    esac
    
    debug_message "Recorded status: $resource_name = $status ($details)"
}

# Generate status indicator
# Usage: get_status_indicator status
get_status_indicator() {
    local status="$1"
    case "$status" in
        $STATUS_ONLINE) echo "🟢" ;;
        $STATUS_OFFLINE) echo "🔴" ;;
        $STATUS_WARNING) echo "🟡" ;;
        $STATUS_UNKNOWN) echo "⚪" ;;
        *) echo "❓" ;;
    esac
}

# Generate status text
# Usage: get_status_text status
get_status_text() {
    local status="$1"
    case "$status" in
        $STATUS_ONLINE) echo "ONLINE" ;;
        $STATUS_OFFLINE) echo "OFFLINE" ;;
        $STATUS_WARNING) echo "WARNING" ;;
        $STATUS_UNKNOWN) echo "UNKNOWN" ;;
        *) echo "ERROR" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Pretty Status Display Functions 🌸💖🦄
# ─────────────────────────────────────────────────────────────────────────────

# Display functions moved to display.sh for centralization
# print_pretty_header(), print_section_header(), print_pretty_status_line(), 
# print_colored_info(), print_detailed_section_header() are now in display.sh

# Enhanced status indicators with cute decorations
# Usage: get_pretty_status_indicator status
get_pretty_status_indicator() {
    local status="$1"
    case "$status" in
        $STATUS_ONLINE) echo "🌟 🟢 ✨" ;;
        $STATUS_OFFLINE) echo "💔 🔴 😢" ;;
        $STATUS_WARNING) echo "🌸 🟡 💫" ;;
        $STATUS_UNKNOWN) echo "🦄 ⚪ 🌈" ;;
        *) echo "❓ 💭 🤔" ;;
    esac
}

# Enhanced status text with decorations
# Usage: get_pretty_status_text status
get_pretty_status_text() {
    local status="$1"
    case "$status" in
        $STATUS_ONLINE) echo "💚 ONLINE 💚" ;;
        $STATUS_OFFLINE) echo "💔 OFFLINE 💔" ;;
        $STATUS_WARNING) echo "💛 WARNING 💛" ;;
        $STATUS_UNKNOWN) echo "🤍 UNKNOWN 🤍" ;;
        *) echo "❓ ERROR ❓" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Status Orchestration
# ─────────────────────────────────────────────────────────────────────────────

# Execute status operation
# Usage: execute_status_operation
execute_status_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Starting status check for environment: $OP_ENV, target: $OP_TARGET_TYPE"
    log_phase "Infrastructure status check"
    
    # Initialize status framework
    init_status_framework
    
    # Determine output format based on target
    case "$OP_TARGET_TYPE" in
        "infrastructure"|"instances"|"all")
            execute_summary_status "$OP_ENV" "$OP_TARGET_TYPE"
            ;;
        *)
            execute_detailed_status "$OP_ENV" "$OP_TARGET_TYPE"
            # Generate final status summary for detailed status only
            generate_status_summary
            ;;
    esac
    
    # Execute all post-operation actions in one call (KISS approach)
    execute_post_operation_actions "Status operation completed"
    
    debug_message "Status operation completed"
}

# Execute summary status (green/red indicators)
# Usage: execute_summary_status "dev" "infrastructure"
execute_summary_status() {
    local env="$1"
    local target_type="$2"
    
    print_pretty_header "Infrastructure Status Dashboard - Environment: $env"
    echo ""
    
    # Get modules to check
    local modules_to_check
    if ! modules_to_check=($(get_modules_for_target "$target_type")); then
        handle_error "Failed to get modules for target: $target_type"
    fi
    
    # Group modules by type for better organization
    local instances=()
    local infrastructure=()
    
    for module in "${modules_to_check[@]:-}"; do
        case "$module" in
            "athena"|"aegis"|"metis"|"mnemosyne")
                instances+=("$module")
                ;;
            *)
                infrastructure+=("$module")
                ;;
        esac
    done
    
    # Show instances if any
    if [[ ${#instances[@]} -gt 0 ]]; then
        print_collection_header "Compute Instances" "${#instances[@]}"
        
        # Print column headers
        if [[ "$NO_COLOR" != true ]]; then
            printf "${WHITE}%-8s ${CYAN}%-20s ${GREEN}%-15s ${YELLOW}%s${NC}\n" \
                "Status" "Instance" "State" "Details"
            echo -e "${PURPLE}   ────────────────────────────────────────────────────────────────────${NC}"
        else
            printf "%-8s %-20s %-15s %s\n" "Status" "Instance" "State" "Details"
            echo "   ────────────────────────────────────────────────────────────────────"
        fi
        
        for module in "${instances[@]:-}"; do
            check_module_summary_status_pretty "$env" "$module"
    done
        echo ""
    fi
    
    # Show infrastructure if any
    if [[ ${#infrastructure[@]} -gt 0 ]]; then
        print_collection_header "Infrastructure Components" "${#infrastructure[@]}"
        
        # Print column headers
        if [[ "$NO_COLOR" != true ]]; then
            printf "${WHITE}%-8s ${CYAN}%-20s ${GREEN}%-15s ${YELLOW}%s${NC}\n" \
                "Status" "Component" "State" "Details"
            echo -e "${PURPLE}   ────────────────────────────────────────────────────────────────────${NC}"
        else
            printf "%-8s %-20s %-15s %s\n" "Status" "Component" "State" "Details"
            echo "   ────────────────────────────────────────────────────────────────────"
        fi
        
        for module in "${infrastructure[@]:-}"; do
            check_module_summary_status_pretty "$env" "$module"
        done
        echo ""
    fi
    
    # Generate beautiful summary
    generate_pretty_status_summary
}

# Execute detailed status (full module details)
# Usage: execute_detailed_status "dev" "athena"
execute_detailed_status() {
    local env="$1"
    local module="$2"
    
    # Route to appropriate detailed status check
    case "$module" in
        "athena"|"aegis"|"metis"|"mnemosyne")
            check_instance_detailed_status "$env" "$module"
            ;;
        "ebss")
            check_ebs_detailed_status "$env" "$module"
            ;;
        "eips")
            check_eip_detailed_status "$env" "$module"
            ;;
        "ecrs")
            check_ecr_detailed_status "$env" "$module"
            ;;
        "vpcs")
            check_vpc_detailed_status "$env" "$module"
            ;;
        "security_groups")
            check_sg_detailed_status "$env" "$module"
            ;;
        *)
            warn_message "❓ No detailed status check available for module: $module"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary Status Checks (Green/Red Indicators)
# ─────────────────────────────────────────────────────────────────────────────

# Check module summary status
# Usage: check_module_summary_status "dev" "athena"
check_module_summary_status() {
    local env="$1"
    local module="$2"
    
    debug_message "Checking summary status for module: $module"
    
    # Check if AWS CLI is available for cloud checks
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_status_result "$module" $STATUS_UNKNOWN "AWS CLI not available"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        local status_text=$(get_status_text $STATUS_UNKNOWN)
        info_message "   $indicator $module - $status_text (AWS CLI unavailable)"
        return
    fi
    
    # Route to appropriate summary check
    case "$module" in
        "athena"|"aegis"|"metis"|"mnemosyne")
            check_instance_summary_status "$env" "$module"
            ;;
        *)
            check_infrastructure_summary_status "$env" "$module"
            ;;
    esac
}

# Check instance summary status with basic details
# Usage: check_instance_summary_status "dev" "athena"
check_instance_summary_status() {
    local env="$1"
    local instance_name="$2"
    
    # Get instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs_file="$env_path/outputs/$instance_name.json"
    
    if [[ ! -f "$instance_outputs_file" ]]; then
        record_status_result "$instance_name" $STATUS_UNKNOWN "No outputs file"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        info_message "   $indicator $instance_name - UNKNOWN (no outputs)"
        return
    fi
    
    # Get instance ID
    local instance_key="$instance_name"
    local instance_id
    if ! instance_id=$(jq -r --arg instance_key "$instance_key" '
        .instance_ids.value[$instance_key] // empty
    ' "$instance_outputs_file" 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_UNKNOWN "Cannot parse instance ID"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        info_message "   $indicator $instance_name - UNKNOWN (parsing error)"
        return
    fi
    
    if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
        record_status_result "$instance_name" $STATUS_UNKNOWN "No instance ID"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        info_message "   $indicator $instance_name - UNKNOWN (no instance ID)"
        return
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_UNKNOWN "Cannot get AWS region"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        info_message "   $indicator $instance_name - UNKNOWN (no region)"
        return
    fi
    
    # Check instance status in AWS
    local aws_instance_data
    if ! aws_instance_data=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --output json 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_OFFLINE "Instance not found in AWS"
        local indicator=$(get_status_indicator $STATUS_OFFLINE)
        info_message "   $indicator $instance_name - OFFLINE (not found)"
        return
    fi
    
    local aws_instance=$(echo "$aws_instance_data" | jq -r '.Reservations[0].Instances[0]')
    if [[ "$aws_instance" == "null" ]]; then
        record_status_result "$instance_name" $STATUS_OFFLINE "Invalid AWS response"
        local indicator=$(get_status_indicator $STATUS_OFFLINE)
        info_message "   $indicator $instance_name - OFFLINE (invalid response)"
        return
    fi
    
    # Get instance details
    local aws_state=$(echo "$aws_instance" | jq -r '.State.Name // empty')
    local aws_public_ip=$(echo "$aws_instance" | jq -r '.PublicIpAddress // empty')
    local aws_private_ip=$(echo "$aws_instance" | jq -r '.PrivateIpAddress // empty')
    local aws_instance_type=$(echo "$aws_instance" | jq -r '.InstanceType // empty')
    
    # Determine status based on instance state
    local status
    local details
    case "$aws_state" in
        "running")
            status=$STATUS_ONLINE
            details="$aws_instance_type, Public: ${aws_public_ip:-none}, Private: $aws_private_ip"
            ;;
        "stopped"|"stopping"|"terminated"|"terminating")
            status=$STATUS_OFFLINE
            details="State: $aws_state"
            ;;
        "pending"|"rebooting")
            status=$STATUS_WARNING
            details="State: $aws_state"
            ;;
        *)
            status=$STATUS_UNKNOWN
            details="State: $aws_state"
            ;;
    esac
    
    record_status_result "$instance_name" $status "$details"
    local indicator=$(get_status_indicator $status)
    local status_text=$(get_status_text $status)
    
    if [[ $status == $STATUS_ONLINE ]]; then
        info_message "   $indicator $instance_name - $status_text ($aws_instance_type) Public: ${aws_public_ip:-none}"
    else
        info_message "   $indicator $instance_name - $status_text ($details)"
    fi
}

# Check infrastructure module summary status (simple green/red)
# Usage: check_infrastructure_summary_status "dev" "vpcs"
check_infrastructure_summary_status() {
    local env="$1"
    local module="$2"
    
    # Get module outputs
    local env_path="$(get_environment_path "$env")"
    local module_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$module_outputs_file" ]]; then
        record_status_result "$module" $STATUS_UNKNOWN "No outputs file"
        local indicator=$(get_status_indicator $STATUS_UNKNOWN)
        info_message "   $indicator $module - UNKNOWN (no outputs)"
        return
    fi
    
    # Check if outputs file has any content
    local output_content=$(jq -r '. | keys | length' "$module_outputs_file" 2>/dev/null || echo "0")
    
    if [[ "$output_content" == "0" ]]; then
        record_status_result "$module" $STATUS_OFFLINE "No resources defined"
        local indicator=$(get_status_indicator $STATUS_OFFLINE)
        info_message "   $indicator $module - OFFLINE (no resources)"
        return
    fi
    
    # For infrastructure modules, if outputs exist, assume online
    # More detailed checks would require module-specific logic
    record_status_result "$module" $STATUS_ONLINE "Resources configured"
    local indicator=$(get_status_indicator $STATUS_ONLINE)
    info_message "   $indicator $module - ONLINE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Detailed Status Checks (Full Module Analysis)
# ─────────────────────────────────────────────────────────────────────────────

# Enhanced detailed instance status check with beautiful colors
# Usage: check_instance_detailed_status "dev" "athena"
check_instance_detailed_status() {
    local env="$1"
    local instance_name="$2"
    
    print_pretty_header "Detailed Status Analysis - $env:$instance_name"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed status"
        return 1
    fi
    
    # Get instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs_file="$env_path/outputs/$instance_name.json"
    
    if [[ ! -f "$instance_outputs_file" ]]; then
        warn_message "   ❌ Instance outputs file missing: $instance_outputs_file"
        return 1
    fi
    
    # Get instance details from outputs
    local instance_key="$instance_name"
    local instance_id
    if ! instance_id=$(jq -r --arg instance_key "$instance_key" '
        .instance_ids.value[$instance_key] // empty
    ' "$instance_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse instance ID from outputs"
        return 1
    fi
    
    if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
        warn_message "   ❌ No instance ID found in outputs"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for status check"
        return 1
    fi
    
    # Get comprehensive AWS instance data
    local aws_instance_data
    if ! aws_instance_data=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --output json 2>/dev/null); then
        warn_message "   ❌ Instance not found in AWS: $instance_id"
        return 1
    fi
    
    local aws_instance=$(echo "$aws_instance_data" | jq -r '.Reservations[0].Instances[0]')
    if [[ "$aws_instance" == "null" ]]; then
        warn_message "   ❌ Invalid AWS instance response"
        return 1
    fi
    
    # Extract detailed instance information
    local aws_state=$(echo "$aws_instance" | jq -r '.State.Name // empty')
    local aws_state_reason=$(echo "$aws_instance" | jq -r '.StateReason.Message // empty')
    local aws_instance_type=$(echo "$aws_instance" | jq -r '.InstanceType // empty')
    local aws_launch_time=$(echo "$aws_instance" | jq -r '.LaunchTime // empty')
    local aws_public_ip=$(echo "$aws_instance" | jq -r '.PublicIpAddress // empty')
    local aws_private_ip=$(echo "$aws_instance" | jq -r '.PrivateIpAddress // empty')
    local aws_vpc_id=$(echo "$aws_instance" | jq -r '.VpcId // empty')
    local aws_subnet_id=$(echo "$aws_instance" | jq -r '.SubnetId // empty')
    local aws_az=$(echo "$aws_instance" | jq -r '.Placement.AvailabilityZone // empty')
    
    # Display detailed status information with beautiful colors
    print_detailed_section_header "💖" "Basic Information" "$WHITE"
    print_colored_info "      Instance ID" "$instance_id" "$PURPLE"
    print_colored_info "      Instance Type" "$aws_instance_type" "$PURPLE"
    print_colored_info "      Availability Zone" "$aws_az" "$PURPLE"
    
    # State with appropriate indicator
    local state_indicator
    case "$aws_state" in
        "running") state_indicator="🟢" ;;
        "stopped") state_indicator="🔴" ;;
        "stopping"|"pending"|"rebooting") state_indicator="🟡" ;;
        "terminated"|"terminating") state_indicator="🔴" ;;
        *) state_indicator="⚪" ;;
    esac
    
    print_colored_info "      State" "$state_indicator $aws_state" "$PURPLE"
    if [[ -n "$aws_state_reason" ]]; then
        print_colored_info "      State Reason" "$aws_state_reason" "$PURPLE"
    fi
    
    if [[ -n "$aws_launch_time" ]]; then
        local launch_date=$(date -d "$aws_launch_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$aws_launch_time")
        print_colored_info "      Launch Time" "$launch_date" "$PURPLE"
    fi
    
    print_detailed_section_header "🌐" "Network Information" "$CYAN"
    print_colored_info "      VPC ID" "$aws_vpc_id" "$PURPLE"
    print_colored_info "      Subnet ID" "$aws_subnet_id" "$PURPLE"
    print_colored_info "      Private IP" "$aws_private_ip" "$PURPLE"
    if [[ -n "$aws_public_ip" ]]; then
        print_colored_info "      Public IP" "$aws_public_ip" "$PURPLE"
    else
        print_colored_info "      Public IP" "none" "$PURPLE"
    fi
    
    # Check EIP allocation
    local eip_allocation=""
    if [[ -n "$aws_public_ip" ]]; then
        eip_allocation=$(aws ec2 describe-addresses \
            --filters "Name=public-ip,Values=$aws_public_ip" \
            --region "$aws_region" \
            --query "Addresses[0].AllocationId" \
            --output text 2>/dev/null || echo "")
        
        if [[ "$eip_allocation" != "None" && -n "$eip_allocation" ]]; then
            print_colored_info "      EIP Allocation" "$eip_allocation" "$PURPLE"
        else
            print_colored_info "      EIP Allocation" "none (regular public IP)" "$PURPLE"
        fi
    fi
    
    # Volume information
    local volume_count=$(echo "$aws_instance" | jq -r '.BlockDeviceMappings | length')
    print_detailed_section_header "💾" "Storage Information" "$GREEN"
    print_colored_info "      Attached Volumes" "$volume_count" "$GREEN"
    
    if [[ $volume_count -gt 0 ]]; then
        echo "$aws_instance" | jq -r '.BlockDeviceMappings[] | "Device: \(.DeviceName) -> Volume: \(.Ebs.VolumeId)"' | while read line; do
            if [[ "$NO_COLOR" != true ]]; then
                echo -e "${WHITE}      ${GREEN}$line${NC}"
            else
                echo "      $line"
            fi
        done
    fi
    
    # Security groups
    local sg_count=$(echo "$aws_instance" | jq -r '.SecurityGroups | length')
    print_detailed_section_header "🔒" "Security Information" "$YELLOW"
    print_colored_info "      Security Groups" "$sg_count" "$CYAN"
    
    if [[ $sg_count -gt 0 ]]; then
        echo "$aws_instance" | jq -r '.SecurityGroups[] | "      \(.GroupName) (\(.GroupId))"' | while read line; do
            if [[ "$NO_COLOR" != true ]]; then
                echo -e "${WHITE}${CYAN}$line${NC}"
            else
                echo "$line"
            fi
        done
    fi
    
    echo ""
    record_status_result "$instance_name" $STATUS_ONLINE "Detailed status retrieved"
    success_message "✅ Detailed status check completed for $instance_name"
}

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure Module Detailed Status Implementations
# ─────────────────────────────────────────────────────────────────────────────

# Detailed EBS status check
# Usage: check_ebs_detailed_status "dev" "ebss"
check_ebs_detailed_status() {
    local env="$1"
    local module="$2"
    
    print_pretty_header "EBS Volumes Detailed Analysis - $env:$module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed EBS status"
        return 1
    fi
    
    # Get EBS outputs
    local env_path="$(get_environment_path "$env")"
    local ebs_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$ebs_outputs_file" ]]; then
        warn_message "   ❌ EBS outputs file missing: $ebs_outputs_file"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for EBS status check"
        return 1
    fi
    
    # Parse volume IDs from outputs
    local volume_ids
    if ! volume_ids=$(jq -r '.volume_ids.value // {} | to_entries[] | .value' "$ebs_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse volume IDs from EBS outputs"
        return 1
    fi
    
    if [[ -z "$volume_ids" ]]; then
        warn_message "   ❌ No volume IDs found in EBS outputs"
        return 1
    fi
    
    local volume_count=0
    local online_volumes=0
    local total_size=0
    
    print_detailed_section_header "💾" "EBS Volume Details" "$GREEN"
    
    while read -r volume_id; do
        if [[ -z "$volume_id" || "$volume_id" == "null" ]]; then
            continue
        fi
        
        ((volume_count++))
        
        # Get volume details from AWS
        local aws_volume_data
        if ! aws_volume_data=$(aws ec2 describe-volumes \
            --volume-ids "$volume_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            warn_message "      ❌ Volume not found: $volume_id"
            continue
        fi
        
        local aws_volume=$(echo "$aws_volume_data" | jq -r '.Volumes[0]')
        if [[ "$aws_volume" == "null" ]]; then
            warn_message "      ❌ Invalid volume response: $volume_id"
            continue
        fi
        
        # Extract volume information
        local volume_state=$(echo "$aws_volume" | jq -r '.State // empty')
        local volume_size=$(echo "$aws_volume" | jq -r '.Size // 0')
        local volume_type=$(echo "$aws_volume" | jq -r '.VolumeType // empty')
        local volume_az=$(echo "$aws_volume" | jq -r '.AvailabilityZone // empty')
        local volume_encrypted=$(echo "$aws_volume" | jq -r '.Encrypted // false')
        local volume_iops=$(echo "$aws_volume" | jq -r '.Iops // 0')
        local create_time=$(echo "$aws_volume" | jq -r '.CreateTime // empty')
        
        # Check attachment status
        local attachment_info=$(echo "$aws_volume" | jq -r '.Attachments[0]')
        local attached_instance=""
        local device_name=""
        local attachment_state=""
        
        if [[ "$attachment_info" != "null" ]]; then
            attached_instance=$(echo "$attachment_info" | jq -r '.InstanceId // empty')
            device_name=$(echo "$attachment_info" | jq -r '.Device // empty')
            attachment_state=$(echo "$attachment_info" | jq -r '.State // empty')
        fi
        
        # Determine status indicator
        local volume_indicator
        case "$volume_state" in
            "available"|"in-use") 
                volume_indicator="🟢"
                ((online_volumes++))
                ;;
            "creating"|"deleting") 
                volume_indicator="🟡"
                ;;
            "deleted"|"error") 
                volume_indicator="🔴"
                ;;
            *) 
                volume_indicator="⚪"
                ;;
        esac
        
        ((total_size += volume_size))
        
        # Format creation time
        local create_date=""
        if [[ -n "$create_time" ]]; then
            create_date=$(date -d "$create_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$create_time")
        fi
        
        # Display volume information with beautiful colors
        echo ""
        print_colored_info "      $volume_indicator Volume" "$volume_id" "$GREEN"
        print_colored_info "         State" "$volume_state" "$GREEN"
        print_colored_info "         Size" "${volume_size}GB ($volume_type)" "$GREEN"
        print_colored_info "         Availability Zone" "$volume_az" "$GREEN"
        print_colored_info "         Encrypted" "$volume_encrypted" "$GREEN"
        if [[ $volume_iops -gt 0 ]]; then
            print_colored_info "         IOPS" "$volume_iops" "$GREEN"
        fi
        if [[ -n "$create_date" ]]; then
            print_colored_info "         Created" "$create_date" "$GREEN"
        fi
        
        if [[ -n "$attached_instance" ]]; then
            print_colored_info "         Attached to" "$attached_instance ($device_name)" "$CYAN"
            print_colored_info "         Attachment State" "$attachment_state" "$CYAN"
        else
            print_colored_info "         Attachment" "Not attached" "$YELLOW"
        fi
    done < <(echo "$volume_ids")
    
    # Summary with pretty colors
    echo ""
    print_detailed_section_header "📊" "EBS Summary" "$WHITE"
    print_colored_info "      Total Volumes" "$volume_count" "$GREEN"
    print_colored_info "      Online Volumes" "$online_volumes" "$GREEN"
    print_colored_info "      Total Storage" "${total_size}GB" "$GREEN"
    
    echo ""
    record_status_result "$module" $STATUS_ONLINE "EBS detailed status completed"
    success_message "✅ Detailed EBS status check completed for $module"
}

# Detailed EIP status check
# Usage: check_eip_detailed_status "dev" "eips"
check_eip_detailed_status() {
    local env="$1"
    local module="$2"
    
    info_message "🌐 Elastic IPs: $module"
    info_message "─────────────────────────────────────────────────────────────────────────────"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed EIP status"
        return 1
    fi
    
    # Get EIP outputs
    local env_path="$(get_environment_path "$env")"
    local eip_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$eip_outputs_file" ]]; then
        warn_message "   ❌ EIP outputs file missing: $eip_outputs_file"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for EIP status check"
        return 1
    fi
    
    # Parse EIP addresses from outputs
    local eip_addresses
    if ! eip_addresses=$(jq -r '.eip_addresses.value // {} | to_entries[] | .value' "$eip_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse EIP addresses from outputs"
        return 1
    fi
    
    if [[ -z "$eip_addresses" ]]; then
        warn_message "   ❌ No EIP addresses found in outputs"
        return 1
    fi
    
    local eip_count=0
    local allocated_eips=0
    local associated_eips=0
    
    info_message "   📋 Elastic IP Details:"
    
    while read -r eip_address; do
        if [[ -z "$eip_address" || "$eip_address" == "null" ]]; then
            continue
        fi
        
        ((eip_count++))
        
        # Get EIP details from AWS
        local aws_eip_data
        if ! aws_eip_data=$(aws ec2 describe-addresses \
            --public-ips "$eip_address" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            warn_message "      ❌ EIP not found: $eip_address"
            continue
        fi
        
        local aws_eip=$(echo "$aws_eip_data" | jq -r '.Addresses[0]')
        if [[ "$aws_eip" == "null" ]]; then
            warn_message "      ❌ Invalid EIP response: $eip_address"
            continue
        fi
        
        # Extract EIP information
        local allocation_id=$(echo "$aws_eip" | jq -r '.AllocationId // empty')
        local association_id=$(echo "$aws_eip" | jq -r '.AssociationId // empty')
        local instance_id=$(echo "$aws_eip" | jq -r '.InstanceId // empty')
        local private_ip=$(echo "$aws_eip" | jq -r '.PrivateIpAddress // empty')
        local domain=$(echo "$aws_eip" | jq -r '.Domain // empty')
        local network_interface=$(echo "$aws_eip" | jq -r '.NetworkInterfaceId // empty')
        
        ((allocated_eips++))
        if [[ -n "$instance_id" ]]; then
            ((associated_eips++))
        fi
        
        # Determine status indicator
        local eip_indicator
        if [[ -n "$instance_id" ]]; then
            eip_indicator="🟢"  # Associated
        elif [[ -n "$allocation_id" ]]; then
            eip_indicator="🟡"  # Allocated but not associated
        else
            eip_indicator="🔴"  # Problem
        fi
        
        # Display EIP information
        info_message "      $eip_indicator EIP: $eip_address"
        info_message "         Allocation ID: $allocation_id"
        info_message "         Domain: $domain"
        
        if [[ -n "$instance_id" ]]; then
            info_message "         Associated with: $instance_id"
            info_message "         Association ID: $association_id"
            info_message "         Private IP: $private_ip"
            if [[ -n "$network_interface" ]]; then
                info_message "         Network Interface: $network_interface"
            fi
        else
            info_message "         Status: Allocated but not associated"
        fi
        info_message ""
    done < <(echo "$eip_addresses")
    
    # Summary
    info_message "   📊 EIP Summary:"
    info_message "      Total EIPs: $eip_count"
    info_message "      Allocated: $allocated_eips"
    info_message "      Associated: $associated_eips"
    info_message "      Available: $((allocated_eips - associated_eips))"
    
    record_status_result "$module" $STATUS_ONLINE "EIP detailed status completed"
    success_message "✅ Detailed EIP status check completed for $module"
}

# Detailed ECR status check
# Usage: check_ecr_detailed_status "dev" "ecrs"
check_ecr_detailed_status() {
    local env="$1"
    local module="$2"
    
    info_message "📦 Container Registries: $module"
    info_message "─────────────────────────────────────────────────────────────────────────────"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed ECR status"
        return 1
    fi
    
    # Get ECR outputs
    local env_path="$(get_environment_path "$env")"
    local ecr_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$ecr_outputs_file" ]]; then
        warn_message "   ❌ ECR outputs file missing: $ecr_outputs_file"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for ECR status check"
        return 1
    fi
    
    # Parse repository names from outputs
    local repo_names
    if ! repo_names=$(jq -r '.repositories.value // {} | to_entries[] | .key' "$ecr_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse repository names from ECR outputs"
        return 1
    fi
    
    if [[ -z "$repo_names" ]]; then
        warn_message "   ❌ No repository names found in ECR outputs"
        return 1
    fi
    
    local repo_count=0
    local active_repos=0
    local total_images=0
    
    info_message "   📋 ECR Repository Details:"
    
    while read -r repo_name; do
        if [[ -z "$repo_name" || "$repo_name" == "null" ]]; then
            continue
        fi
        
        ((repo_count++))
        
        # Get repository details from AWS
        local aws_repo_data
        if ! aws_repo_data=$(aws ecr describe-repositories \
            --repository-names "$repo_name" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            warn_message "      ❌ Repository not found: $repo_name"
            continue
        fi
        
        local aws_repo=$(echo "$aws_repo_data" | jq -r '.repositories[0]')
        if [[ "$aws_repo" == "null" ]]; then
            warn_message "      ❌ Invalid repository response: $repo_name"
            continue
        fi
        
        # Extract repository information
        local repo_arn=$(echo "$aws_repo" | jq -r '.repositoryArn // empty')
        local repo_uri=$(echo "$aws_repo" | jq -r '.repositoryUri // empty')
        local created_at=$(echo "$aws_repo" | jq -r '.createdAt // empty')
        local image_tag_mutability=$(echo "$aws_repo" | jq -r '.imageTagMutability // empty')
        local scan_on_push=$(echo "$aws_repo" | jq -r '.imageScanningConfiguration.scanOnPush // false')
        
        ((active_repos++))
        
        # Get image count
        local image_count=0
        local aws_images_data
        if aws_images_data=$(aws ecr list-images \
            --repository-name "$repo_name" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            image_count=$(echo "$aws_images_data" | jq -r '.imageIds | length')
            ((total_images += image_count))
        fi
        
        # Format creation time
        local create_date=""
        if [[ -n "$created_at" ]]; then
            create_date=$(date -d "$created_at" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$created_at")
        fi
        
        # Display repository information
        info_message "      🟢 Repository: $repo_name"
        info_message "         ARN: $repo_arn"
        info_message "         URI: $repo_uri"
        info_message "         Images: $image_count"
        info_message "         Tag Mutability: $image_tag_mutability"
        info_message "         Scan on Push: $scan_on_push"
        if [[ -n "$create_date" ]]; then
            info_message "         Created: $create_date"
        fi
        info_message ""
    done < <(echo "$repo_names")
    
    # Summary
    info_message "   📊 ECR Summary:"
    info_message "      Total Repositories: $repo_count"
    info_message "      Active Repositories: $active_repos"
    info_message "      Total Images: $total_images"
    
    record_status_result "$module" $STATUS_ONLINE "ECR detailed status completed"
    success_message "✅ Detailed ECR status check completed for $module"
}

# Detailed VPC status check
# Usage: check_vpc_detailed_status "dev" "vpcs"
check_vpc_detailed_status() {
    local env="$1"
    local module="$2"
    
    info_message "🌐 Virtual Private Cloud: $module"
    info_message "─────────────────────────────────────────────────────────────────────────────"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed VPC status"
        return 1
    fi
    
    # Get VPC outputs
    local env_path="$(get_environment_path "$env")"
    local vpc_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$vpc_outputs_file" ]]; then
        warn_message "   ❌ VPC outputs file missing: $vpc_outputs_file"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for VPC status check"
        return 1
    fi
    
    # Parse VPC IDs from outputs
    local vpc_ids
    if ! vpc_ids=$(jq -r '.vpc_ids.value // {} | to_entries[] | .value' "$vpc_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse VPC IDs from outputs"
        return 1
    fi
    
    if [[ -z "$vpc_ids" ]]; then
        warn_message "   ❌ No VPC IDs found in outputs"
        return 1
    fi
    
    local vpc_count=0
    local available_vpcs=0
    
    info_message "   📋 VPC Details:"
    
    while read -r vpc_id; do
        if [[ -z "$vpc_id" || "$vpc_id" == "null" ]]; then
            continue
        fi
        
        ((vpc_count++))
        
        # Get VPC details from AWS
        local aws_vpc_data
        if ! aws_vpc_data=$(aws ec2 describe-vpcs \
            --vpc-ids "$vpc_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            warn_message "      ❌ VPC not found: $vpc_id"
            continue
        fi
        
        local aws_vpc=$(echo "$aws_vpc_data" | jq -r '.Vpcs[0]')
        if [[ "$aws_vpc" == "null" ]]; then
            warn_message "      ❌ Invalid VPC response: $vpc_id"
            continue
        fi
        
        # Extract VPC information
        local vpc_state=$(echo "$aws_vpc" | jq -r '.State // empty')
        local vpc_cidr=$(echo "$aws_vpc" | jq -r '.CidrBlock // empty')
        local dhcp_options_id=$(echo "$aws_vpc" | jq -r '.DhcpOptionsId // empty')
        local is_default=$(echo "$aws_vpc" | jq -r '.IsDefault // false')
        local instance_tenancy=$(echo "$aws_vpc" | jq -r '.InstanceTenancy // empty')
        
        # Get VPC name tag
        local vpc_name=""
        vpc_name=$(echo "$aws_vpc" | jq -r '.Tags[]? | select(.Key == "Name") | .Value' 2>/dev/null || echo "")
        
        # Determine status indicator
        local vpc_indicator
        case "$vpc_state" in
            "available") 
                vpc_indicator="🟢"
                ((available_vpcs++))
                ;;
            "pending") 
                vpc_indicator="🟡"
                ;;
            *) 
                vpc_indicator="🔴"
                ;;
        esac
        
        # Get subnet count
        local subnet_count=0
        local aws_subnets_data
        if aws_subnets_data=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            subnet_count=$(echo "$aws_subnets_data" | jq -r '.Subnets | length')
        fi
        
        # Get route table count
        local route_table_count=0
        local aws_route_tables_data
        if aws_route_tables_data=$(aws ec2 describe-route-tables \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            route_table_count=$(echo "$aws_route_tables_data" | jq -r '.RouteTables | length')
        fi
        
        # Get internet gateway association
        local igw_attached="No"
        local aws_igw_data
        if aws_igw_data=$(aws ec2 describe-internet-gateways \
            --filters "Name=attachment.vpc-id,Values=$vpc_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            local igw_count=$(echo "$aws_igw_data" | jq -r '.InternetGateways | length')
            if [[ $igw_count -gt 0 ]]; then
                igw_attached="Yes"
            fi
        fi
        
        # Display VPC information
        info_message "      $vpc_indicator VPC: $vpc_id"
        if [[ -n "$vpc_name" ]]; then
            info_message "         Name: $vpc_name"
        fi
        info_message "         State: $vpc_state"
        info_message "         CIDR Block: $vpc_cidr"
        info_message "         Instance Tenancy: $instance_tenancy"
        info_message "         Default VPC: $is_default"
        info_message "         DHCP Options: $dhcp_options_id"
        info_message "         Subnets: $subnet_count"
        info_message "         Route Tables: $route_table_count"
        info_message "         Internet Gateway: $igw_attached"
        info_message ""
    done < <(echo "$vpc_ids")
    
    # Summary
    info_message "   📊 VPC Summary:"
    info_message "      Total VPCs: $vpc_count"
    info_message "      Available VPCs: $available_vpcs"
    
    record_status_result "$module" $STATUS_ONLINE "VPC detailed status completed"
    success_message "✅ Detailed VPC status check completed for $module"
}

# Detailed Security Group status check
# Usage: check_sg_detailed_status "dev" "security_groups"
check_sg_detailed_status() {
    local env="$1"
    local module="$2"
    
    info_message "🔒 Security Groups: $module"
    info_message "─────────────────────────────────────────────────────────────────────────────"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot check detailed Security Group status"
        return 1
    fi
    
    # Get Security Group outputs
    local env_path="$(get_environment_path "$env")"
    local sg_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$sg_outputs_file" ]]; then
        warn_message "   ❌ Security Group outputs file missing: $sg_outputs_file"
        return 1
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        warn_message "   ❌ Cannot get AWS region for Security Group status check"
        return 1
    fi
    
    # Parse Security Group IDs from outputs
    local sg_ids
    if ! sg_ids=$(jq -r '.security_group_ids.value // {} | to_entries[] | .value' "$sg_outputs_file" 2>/dev/null); then
        warn_message "   ❌ Cannot parse Security Group IDs from outputs"
        return 1
    fi
    
    if [[ -z "$sg_ids" ]]; then
        warn_message "   ❌ No Security Group IDs found in outputs"
        return 1
    fi
    
    local sg_count=0
    local active_sgs=0
    
    info_message "   📋 Security Group Details:"
    
    while read -r sg_id; do
        if [[ -z "$sg_id" || "$sg_id" == "null" ]]; then
            continue
        fi
        
        ((sg_count++))
        
        # Get Security Group details from AWS
        local aws_sg_data
        if ! aws_sg_data=$(aws ec2 describe-security-groups \
            --group-ids "$sg_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            warn_message "      ❌ Security Group not found: $sg_id"
            continue
        fi
        
        local aws_sg=$(echo "$aws_sg_data" | jq -r '.SecurityGroups[0]')
        if [[ "$aws_sg" == "null" ]]; then
            warn_message "      ❌ Invalid Security Group response: $sg_id"
            continue
        fi
        
        # Extract Security Group information
        local sg_name=$(echo "$aws_sg" | jq -r '.GroupName // empty')
        local sg_description=$(echo "$aws_sg" | jq -r '.Description // empty')
        local vpc_id=$(echo "$aws_sg" | jq -r '.VpcId // empty')
        local owner_id=$(echo "$aws_sg" | jq -r '.OwnerId // empty')
        
        ((active_sgs++))
        
        # Get rule counts
        local ingress_rules=$(echo "$aws_sg" | jq -r '.IpPermissions | length')
        local egress_rules=$(echo "$aws_sg" | jq -r '.IpPermissionsEgress | length')
        
        # Check for instances using this security group
        local instance_count=0
        local aws_instances_data
        if aws_instances_data=$(aws ec2 describe-instances \
            --filters "Name=instance.group-id,Values=$sg_id" \
            --region "$aws_region" \
            --output json 2>/dev/null); then
            instance_count=$(echo "$aws_instances_data" | jq -r '[.Reservations[].Instances[]] | length')
        fi
        
        # Display Security Group information
        info_message "      🟢 Security Group: $sg_id"
        info_message "         Name: $sg_name"
        info_message "         Description: $sg_description"
        info_message "         VPC: $vpc_id"
        info_message "         Owner: $owner_id"
        info_message "         Ingress Rules: $ingress_rules"
        info_message "         Egress Rules: $egress_rules"
        info_message "         Attached Instances: $instance_count"
        
        # Show some key rules if present
        if [[ $ingress_rules -gt 0 ]]; then
            info_message "         Key Ingress Rules:"
            echo "$aws_sg" | jq -r '.IpPermissions[] | "           Port: \(.FromPort // "All") Protocol: \(.IpProtocol) Source: \(.IpRanges[0].CidrIp // .UserIdGroupPairs[0].GroupId // "Various")"' | head -3 | while read line; do
                info_message "$line"
            done
        fi
        info_message ""
    done < <(echo "$sg_ids")
    
    # Summary
    info_message "   📊 Security Group Summary:"
    info_message "      Total Security Groups: $sg_count"
    info_message "      Active Security Groups: $active_sgs"
    
    record_status_result "$module" $STATUS_ONLINE "Security Group detailed status completed"
    success_message "✅ Detailed Security Group status check completed for $module"
}

# ─────────────────────────────────────────────────────────────────────────────
# Status Summary Generation - Moved to display.sh
# generate_status_summary() and generate_pretty_status_summary() are now in display.sh
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

debug_message "Infrastructure status module loaded successfully" 

# Enhanced module status check with pretty output
# Usage: check_module_summary_status_pretty "dev" "athena"
check_module_summary_status_pretty() {
    local env="$1"
    local module="$2"
    
    debug_message "Checking pretty status for module: $module"
    
    # Check if AWS CLI is available for cloud checks
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_status_result "$module" $STATUS_UNKNOWN "AWS CLI not available"
        print_pretty_status_line "$module" $STATUS_UNKNOWN "AWS CLI unavailable"
        return
    fi
    
    # Route to appropriate summary check
    case "$module" in
        "athena"|"aegis"|"metis"|"mnemosyne")
            check_instance_summary_status_pretty "$env" "$module"
            ;;
        *)
            check_infrastructure_summary_status_pretty "$env" "$module"
            ;;
    esac
}

# Enhanced instance summary status check
# Usage: check_instance_summary_status_pretty "dev" "athena"
check_instance_summary_status_pretty() {
    local env="$1"
    local instance_name="$2"
    
    # Get instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs_file="$env_path/outputs/$instance_name.json"
    
    if [[ ! -f "$instance_outputs_file" ]]; then
        record_status_result "$instance_name" $STATUS_UNKNOWN "No outputs file"
        print_pretty_status_line "$instance_name" $STATUS_UNKNOWN "no outputs"
        return
    fi
    
    # Get instance ID
    local instance_key="$instance_name"
    local instance_id
    if ! instance_id=$(jq -r --arg instance_key "$instance_key" '
        .instance_ids.value[$instance_key] // empty
    ' "$instance_outputs_file" 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_UNKNOWN "Cannot parse instance ID"
        print_pretty_status_line "$instance_name" $STATUS_UNKNOWN "parsing error"
        return
    fi
    
    if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
        record_status_result "$instance_name" $STATUS_UNKNOWN "No instance ID"
        print_pretty_status_line "$instance_name" $STATUS_UNKNOWN "no instance ID"
        return
    fi
    
    # Get AWS region
    local aws_region
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_UNKNOWN "Cannot get AWS region"
        print_pretty_status_line "$instance_name" $STATUS_UNKNOWN "no region"
        return
    fi
    
    # Check instance status in AWS
    local aws_instance_data
    if ! aws_instance_data=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --output json 2>/dev/null); then
        record_status_result "$instance_name" $STATUS_OFFLINE "Instance not found in AWS"
        print_pretty_status_line "$instance_name" $STATUS_OFFLINE "not found"
        return
    fi
    
    local aws_instance=$(echo "$aws_instance_data" | jq -r '.Reservations[0].Instances[0]')
    if [[ "$aws_instance" == "null" ]]; then
        record_status_result "$instance_name" $STATUS_OFFLINE "Invalid AWS response"
        print_pretty_status_line "$instance_name" $STATUS_OFFLINE "invalid response"
        return
    fi
    
    # Get instance details
    local aws_state=$(echo "$aws_instance" | jq -r '.State.Name // empty')
    local aws_public_ip=$(echo "$aws_instance" | jq -r '.PublicIpAddress // empty')
    local aws_private_ip=$(echo "$aws_instance" | jq -r '.PrivateIpAddress // empty')
    local aws_instance_type=$(echo "$aws_instance" | jq -r '.InstanceType // empty')
    
    # Determine status based on instance state
    local status
    local details
    case "$aws_state" in
        "running")
            status=$STATUS_ONLINE
            details="$aws_instance_type 🌐 ${aws_public_ip:-none}"
            ;;
        "stopped"|"stopping"|"terminated"|"terminating")
            status=$STATUS_OFFLINE
            details="State: $aws_state"
            ;;
        "pending"|"rebooting")
            status=$STATUS_WARNING
            details="State: $aws_state"
            ;;
        *)
            status=$STATUS_UNKNOWN
            details="State: $aws_state"
            ;;
    esac
    
    record_status_result "$instance_name" $status "$details"
    print_pretty_status_line "$instance_name" $status "$details"
}

# Enhanced infrastructure module summary status check
# Usage: check_infrastructure_summary_status_pretty "dev" "vpcs"
check_infrastructure_summary_status_pretty() {
    local env="$1"
    local module="$2"
    
    # Get module outputs
    local env_path="$(get_environment_path "$env")"
    local module_outputs_file="$env_path/outputs/$module.json"
    
    if [[ ! -f "$module_outputs_file" ]]; then
        record_status_result "$module" $STATUS_UNKNOWN "No outputs file"
        print_pretty_status_line "$module" $STATUS_UNKNOWN "no outputs"
        return
    fi
    
    # Check if outputs file has any content
    local output_content=$(jq -r '. | keys | length' "$module_outputs_file" 2>/dev/null || echo "0")
    
    if [[ "$output_content" == "0" ]]; then
        record_status_result "$module" $STATUS_OFFLINE "No resources defined"
        print_pretty_status_line "$module" $STATUS_OFFLINE "no resources"
        return
    fi
    
    # For infrastructure modules, if outputs exist, assume online
    # More detailed checks would require module-specific logic
    record_status_result "$module" $STATUS_ONLINE "Resources configured"
    
    # Get some basic info for details
    local details="📦 configured"
    case "$module" in
        "vpcs") details="🌐 networks ready" ;;
        "ebss") details="💾 storage ready" ;;
        "eips") details="🌍 IPs allocated" ;;
        "ecrs") details="📦 registries ready" ;;
        "security_groups") details="🔒 security configured" ;;
    esac
    
    print_pretty_status_line "$module" $STATUS_ONLINE "$details"
} 