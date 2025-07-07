#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Comprehensive Verification Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Modular, analytical verification of infrastructure state consistency
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Verification Framework - Core Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

# Global verification state (using simple variables instead of associative arrays)
VERIFICATION_TOTAL_CHECKS=0
VERIFICATION_PASSED_CHECKS=0
VERIFICATION_FAILED_CHECKS=0
VERIFICATION_WARNING_CHECKS=0

# Verification result constants
declare -r VERIFY_PASS=0
readonly VERIFY_FAIL=1
readonly VERIFY_WARN=2

# Initialize verification framework
# Usage: init_verification_framework
init_verification_framework() {
    debug_message "Initializing comprehensive verification framework"
    
    VERIFICATION_TOTAL_CHECKS=0
    VERIFICATION_PASSED_CHECKS=0
    VERIFICATION_FAILED_CHECKS=0
    VERIFICATION_WARNING_CHECKS=0
    
    debug_message "Verification framework initialized"
}

# Record verification result
# Usage: record_verification_result "module:field:check" result "details"
record_verification_result() {
    local check_id="$1"
    local result="$2"
    local details="${3:-}"
    
    ((VERIFICATION_TOTAL_CHECKS++))
    case "$result" in
        $VERIFY_PASS) 
            ((VERIFICATION_PASSED_CHECKS++))
            debug_message "✅ $check_id: $details"
            ;;
        $VERIFY_FAIL) 
            ((VERIFICATION_FAILED_CHECKS++))
            debug_message "❌ $check_id: $details"
            ;;
        $VERIFY_WARN) 
            ((VERIFICATION_WARNING_CHECKS++))
            debug_message "⚠️  $check_id: $details"
            ;;
    esac
    
    debug_message "Recorded verification: $check_id = $result ($details)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Verification Reporting - Moved to display.sh for centralization  
# generate_verification_report() is now in display.sh
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Main Verification Orchestration
# ─────────────────────────────────────────────────────────────────────────────

# Execute verification operation
# Usage: execute_verify_operation
execute_verify_operation() {
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    debug_message "Starting comprehensive verification for environment: $OP_ENV, target: $OP_TARGET_TYPE"
    log_phase "Comprehensive output verification"
    
    # Initialize verification framework
    init_verification_framework
    
    info_message "🔍 Starting comprehensive infrastructure verification..."
    info_message "   Environment: $OP_ENV"
    info_message "   Target: $OP_TARGET_TYPE"
    
    # Get modules to verify
    local modules_to_verify
    if ! modules_to_verify=($(get_modules_for_target "$OP_TARGET_TYPE")); then
        handle_error "Failed to get modules for target: $OP_TARGET_TYPE"
    fi
    
    info_message "   Modules to verify (${#modules_to_verify[@]}): ${modules_to_verify[*]}"
    
    # Execute comprehensive verification for each module
    for module in "${modules_to_verify[@]}"; do
        info_message ""
        info_message "🔍 Analyzing module: $module"
        
        # Step 1: Output file consistency verification
        verify_output_file_consistency "$OP_ENV" "$module"
        
        # Step 2: Module-specific comprehensive verification
        verify_module_comprehensive "$OP_ENV" "$module"
    done
    
    # Generate final comprehensive report (now in display.sh)
    info_message ""
    generate_verification_report
    
    # Execute all post-operation actions in one call (KISS approach)
    execute_post_operation_actions "Verification operation completed"
    
    debug_message "Verification operation completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Output File Consistency Verification
# ─────────────────────────────────────────────────────────────────────────────

# Verify output file consistency between centralized and module outputs
# Usage: verify_output_file_consistency "dev" "athena"
verify_output_file_consistency() {
    local env="$1"
    local module="$2"
    
    debug_message "Verifying output file consistency for module: $module"
    
    local env_path="$(get_environment_path "$env")"
    local centralized_file="$env_path/outputs/$module.json"
    local module_file="$env_path/$module/output.json"
    
    # Check if files exist
    if [[ ! -f "$centralized_file" ]]; then
        record_verification_result "$module:files:centralized_missing" $VERIFY_FAIL "Centralized output file missing: $centralized_file"
        warn_message "   ❌ Missing centralized output: $centralized_file"
        return 1
    fi
    
    if [[ ! -f "$module_file" ]]; then
        record_verification_result "$module:files:module_missing" $VERIFY_FAIL "Module output file missing: $module_file"
        warn_message "   ❌ Missing module output: $module_file"
        return 1
    fi
    
    # Compare file contents
    if diff -q "$centralized_file" "$module_file" >/dev/null 2>&1; then
        record_verification_result "$module:files:consistency" $VERIFY_PASS "Output files are consistent"
        success_message "   ✅ Output file consistency: $module"
        return 0
    else
        record_verification_result "$module:files:consistency" $VERIFY_FAIL "Output files differ between centralized and module locations"
        warn_message "   ❌ Output file mismatch: $module"
        warn_message "      Centralized: $centralized_file"
        warn_message "      Module: $module_file"
        
        if is_verbose; then
            info_message "      Differences:"
            diff "$centralized_file" "$module_file" | head -10 | while read line; do
                info_message "        $line"
            done
        fi
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Module-Specific Comprehensive Verification
# ─────────────────────────────────────────────────────────────────────────────

# Route to appropriate module verification
# Usage: verify_module_comprehensive "dev" "athena"
verify_module_comprehensive() {
    local env="$1"
    local module="$2"
    
    debug_message "Starting comprehensive verification for module: $module"
    
    # Route to appropriate verification based on module type
    case "$module" in
        "athena"|"aegis"|"metis"|"mnemosyne")
            verify_instance_comprehensive "$env" "$module"
            ;;
        "ebss")
            verify_ebs_comprehensive "$env" "$module"
            ;;
        "eips")
            verify_eip_comprehensive "$env" "$module"
            ;;
        "ecrs")
            verify_ecr_comprehensive "$env" "$module"
            ;;
        "vpcs")
            verify_vpc_comprehensive "$env" "$module"
            ;;
        "security_groups")
            verify_sg_comprehensive "$env" "$module"
            ;;
        *)
            record_verification_result "$module:verification:unsupported" $VERIFY_WARN "No comprehensive verification available for module type"
            warn_message "   ⚠️  No comprehensive verification available for module: $module"
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Comprehensive Verification Framework
# ─────────────────────────────────────────────────────────────────────────────

# Comprehensive instance verification with cross-module analysis
# Usage: verify_instance_comprehensive "dev" "athena"
verify_instance_comprehensive() {
    local env="$1"
    local instance_name="$2"
    
    info_message "   🖥️  Instance Comprehensive Analysis: $instance_name"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$instance_name:aws:cli_unavailable" $VERIFY_FAIL "AWS CLI not available for cloud state verification"
        warn_message "      ❌ AWS CLI not available - cannot verify cloud state"
        return 1
    fi
    
    # Load instance outputs
    local env_path="$(get_environment_path "$env")"
    local instance_outputs_file="$env_path/outputs/$instance_name.json"
    
    if [[ ! -f "$instance_outputs_file" ]]; then
        record_verification_result "$instance_name:files:outputs_missing" $VERIFY_FAIL "Instance outputs file missing"
        warn_message "      ❌ Instance outputs file missing: $instance_outputs_file"
        return 1
    fi
    
    # Load related module outputs for cross-verification
    local eips_outputs_file="$env_path/outputs/eips.json"
    local ebss_outputs_file="$env_path/outputs/ebss.json"
    
    # Get AWS region and account info
    local aws_region aws_account_id
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$instance_name:aws:region_unavailable" $VERIFY_FAIL "Cannot determine AWS region"
        warn_message "      ❌ Cannot get AWS region for verification"
        return 1
    fi
    
    if ! aws_account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
        record_verification_result "$instance_name:aws:account_unavailable" $VERIFY_FAIL "Cannot determine AWS account ID"
        warn_message "      ❌ Cannot get AWS account ID for verification"
        return 1
    fi
    
    # Get instance details from outputs and AWS
    local instance_key="$instance_name"
    local instance_id
    if ! instance_id=$(jq -r --arg instance_key "$instance_key" '
        .instance_ids.value[$instance_key] // empty
    ' "$instance_outputs_file" 2>/dev/null); then
        record_verification_result "$instance_name:parsing:instance_id" $VERIFY_FAIL "Cannot parse instance ID from outputs"
        warn_message "      ❌ Cannot parse instance ID from outputs"
        return 1
    fi
    
    if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
        record_verification_result "$instance_name:data:instance_id_missing" $VERIFY_FAIL "No instance ID in outputs"
        warn_message "      ❌ No instance ID found in outputs"
        return 1
    fi
    
    # Get comprehensive AWS instance data
    local aws_instance_data aws_instance
    if ! aws_instance_data=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$aws_region" \
        --output json 2>/dev/null); then
        record_verification_result "$instance_name:aws:instance_not_found" $VERIFY_FAIL "Instance not found in AWS"
        warn_message "      ❌ Instance not found in AWS: $instance_id"
        return 1
    fi
    
    aws_instance=$(echo "$aws_instance_data" | jq -r '.Reservations[0].Instances[0]')
    if [[ "$aws_instance" == "null" ]]; then
        record_verification_result "$instance_name:aws:invalid_response" $VERIFY_FAIL "Invalid AWS instance response"
        warn_message "      ❌ Invalid AWS instance response"
        return 1
    fi
    
    info_message "      📋 Performing detailed field verification..."
    
    # Comprehensive field verification
    verify_instance_basic_fields "$instance_name" "$instance_key" "$instance_outputs_file" "$aws_instance" "$aws_region" "$aws_account_id"
    verify_instance_ip_configuration "$instance_name" "$instance_key" "$instance_outputs_file" "$aws_instance" "$eips_outputs_file" "$env"
    verify_instance_volume_configuration "$instance_name" "$instance_key" "$instance_outputs_file" "$aws_instance" "$ebss_outputs_file"
    
    info_message "      ✅ Instance comprehensive analysis completed: $instance_name"
}

# Verify basic instance fields (IDs, ARNs)
# Usage: verify_instance_basic_fields instance_name instance_key outputs_file aws_instance aws_region aws_account_id
verify_instance_basic_fields() {
    local instance_name="$1"
    local instance_key="$2"
    local outputs_file="$3"
    local aws_instance="$4"
    local aws_region="$5"
    local aws_account_id="$6"
    
    debug_message "Verifying basic instance fields for: $instance_name"
    
    # Verify instance_ids
    local output_instance_id=$(jq -r --arg key "$instance_key" '.instance_ids.value[$key] // empty' "$outputs_file")
    local aws_instance_id=$(echo "$aws_instance" | jq -r '.InstanceId')
    
    if is_verbose; then
        info_message "         instance_ids: output='$output_instance_id' vs aws='$aws_instance_id'"
    fi
    
    if [[ "$output_instance_id" == "$aws_instance_id" ]]; then
        record_verification_result "$instance_name:basic:instance_id" $VERIFY_PASS "Instance ID matches AWS"
    else
        record_verification_result "$instance_name:basic:instance_id" $VERIFY_FAIL "Instance ID mismatch: output='$output_instance_id', AWS='$aws_instance_id'"
        warn_message "         ❌ instance_ids mismatch: output='$output_instance_id', AWS='$aws_instance_id'"
    fi
    
    # Verify instance_arns
    local output_instance_arn=$(jq -r --arg key "$instance_key" '.instance_arns.value[$key] // empty' "$outputs_file")
    local expected_arn="arn:aws:ec2:${aws_region}:${aws_account_id}:instance/$aws_instance_id"
    
    if is_verbose; then
        info_message "         instance_arns: output='$output_instance_arn'"
        info_message "                       vs expected='$expected_arn'"
    fi
    
    if [[ "$output_instance_arn" == "$expected_arn" ]]; then
        record_verification_result "$instance_name:basic:instance_arn" $VERIFY_PASS "Instance ARN correctly formatted"
    else
        record_verification_result "$instance_name:basic:instance_arn" $VERIFY_FAIL "Instance ARN mismatch: output='$output_instance_arn', expected='$expected_arn'"
        warn_message "         ❌ instance_arns mismatch:"
        warn_message "            Output: $output_instance_arn"
        warn_message "            Expected: $expected_arn"
    fi
}

# Verify instance IP configuration with cross-module analysis
# Usage: verify_instance_ip_configuration instance_name instance_key outputs_file aws_instance eips_outputs_file env
verify_instance_ip_configuration() {
    local instance_name="$1"
    local instance_key="$2"
    local outputs_file="$3"
    local aws_instance="$4"
    local eips_outputs_file="$5"
    local env="$6"
    
    debug_message "Verifying IP configuration for: $instance_name"
    info_message "         🌐 IP Configuration Analysis:"
    
    # Get all IP-related data
    local output_private_ip=$(jq -r --arg key "$instance_key" '.private_ips.value[$key] // empty' "$outputs_file")
    local output_public_ip=$(jq -r --arg key "$instance_key" '.public_ips.value[$key] // empty' "$outputs_file")
    local output_eip_address=$(jq -r --arg key "$instance_key" '.eip_addresses.value[$key] // empty' "$outputs_file")
    
    local aws_private_ip=$(echo "$aws_instance" | jq -r '.PrivateIpAddress // empty')
    local aws_public_ip=$(echo "$aws_instance" | jq -r '.PublicIpAddress // empty')
    
    # Verify private IP
    if is_verbose; then
        info_message "            private_ips: output='$output_private_ip' vs aws='$aws_private_ip'"
    fi
    
    if [[ -n "$aws_private_ip" ]]; then
        if [[ "$output_private_ip" == "$aws_private_ip" ]]; then
            record_verification_result "$instance_name:ip:private_ip" $VERIFY_PASS "Private IP matches AWS"
        else
            record_verification_result "$instance_name:ip:private_ip" $VERIFY_FAIL "Private IP mismatch: output='$output_private_ip', AWS='$aws_private_ip'"
            warn_message "            ❌ private_ips mismatch: output='$output_private_ip', AWS='$aws_private_ip'"
        fi
    else
        record_verification_result "$instance_name:ip:private_ip" $VERIFY_WARN "No private IP found in AWS"
        warn_message "            ⚠️  No private IP found in AWS"
    fi
    
    # Verify public IP
    if is_verbose; then
        info_message "            public_ips: output='$output_public_ip' vs aws='$aws_public_ip'"
    fi
    
    if [[ -n "$aws_public_ip" ]]; then
        if [[ "$output_public_ip" == "$aws_public_ip" ]]; then
            record_verification_result "$instance_name:ip:public_ip" $VERIFY_PASS "Public IP matches AWS"
        else
            record_verification_result "$instance_name:ip:public_ip" $VERIFY_FAIL "Public IP mismatch: output='$output_public_ip', AWS='$aws_public_ip'"
            warn_message "            ❌ public_ips mismatch: output='$output_public_ip', AWS='$aws_public_ip'"
        fi
    else
        record_verification_result "$instance_name:ip:public_ip" $VERIFY_WARN "No public IP found in AWS"
        warn_message "            ⚠️  No public IP found in AWS"
    fi
    
    # Critical EIP Analysis - Cross-module verification
    verify_eip_configuration_analysis "$instance_name" "$instance_key" "$output_eip_address" "$aws_public_ip" "$eips_outputs_file" "$env"
}

# Comprehensive EIP configuration analysis
# Usage: verify_eip_configuration_analysis instance_name instance_key output_eip_address aws_public_ip eips_outputs_file env
verify_eip_configuration_analysis() {
    local instance_name="$1"
    local instance_key="$2"
    local output_eip_address="$3"
    local aws_public_ip="$4"
    local eips_outputs_file="$5"
    local env="$6"
    
    info_message "            🔍 EIP Configuration Deep Analysis:"
    
    # Get expected EIP from EIPs module (with env suffix)
    local eip_key_with_env="${instance_name}-${env}"
    local expected_eip_address=""
    local expected_eip_allocation=""
    
    if [[ -f "$eips_outputs_file" ]]; then
        expected_eip_address=$(jq -r --arg key "$eip_key_with_env" '.eip_addresses.value[$key] // empty' "$eips_outputs_file" 2>/dev/null)
        expected_eip_allocation=$(jq -r --arg key "$eip_key_with_env" '.eip_allocations.value[$key] // empty' "$eips_outputs_file" 2>/dev/null)
    fi
    
    if is_verbose; then
        info_message "               instance_eip: '$output_eip_address' (from instance outputs)"
        info_message "               expected_eip: '$expected_eip_address' (from EIPs module for key '$eip_key_with_env')"
        info_message "               aws_public_ip: '$aws_public_ip' (from AWS instance)"
    fi
    
    # Check if AWS public IP is actually an EIP allocation
    local aws_eip_allocation=""
    if [[ -n "$aws_public_ip" ]]; then
        aws_eip_allocation=$(aws ec2 describe-addresses \
            --filters "Name=public-ip,Values=$aws_public_ip" \
            --region "$(get_aws_region "$env")" \
            --query "Addresses[0].AllocationId" \
            --output text 2>/dev/null || echo "")
        
        if [[ "$aws_eip_allocation" == "None" || -z "$aws_eip_allocation" ]]; then
            aws_eip_allocation=""
        fi
    fi
    
    if is_verbose; then
        if [[ -n "$aws_eip_allocation" ]]; then
            info_message "               aws_eip_allocation: '$aws_eip_allocation' (AWS confirms this is an EIP)"
        else
            info_message "               aws_eip_allocation: (none - this is a regular public IP, not an EIP)"
        fi
    fi
    
    # Comprehensive EIP analysis
    if [[ -n "$expected_eip_address" ]]; then
        # There should be an EIP assigned according to EIPs module
        if [[ "$output_eip_address" == "$expected_eip_address" ]]; then
            if [[ "$aws_public_ip" == "$expected_eip_address" && -n "$aws_eip_allocation" ]]; then
                record_verification_result "$instance_name:eip:configuration" $VERIFY_PASS "EIP correctly configured and assigned"
                info_message "               ✅ EIP correctly configured: $expected_eip_address"
            elif [[ "$aws_public_ip" == "$expected_eip_address" && -z "$aws_eip_allocation" ]]; then
                record_verification_result "$instance_name:eip:allocation_missing" $VERIFY_FAIL "Instance has correct IP but it's not allocated as EIP in AWS"
                warn_message "               ❌ CRITICAL: Instance has correct IP ($aws_public_ip) but AWS shows it's NOT an EIP allocation!"
            else
                record_verification_result "$instance_name:eip:not_assigned" $VERIFY_FAIL "EIP exists but not assigned to instance"
                warn_message "               ❌ CRITICAL: EIP exists ($expected_eip_address) but instance has different IP ($aws_public_ip)"
            fi
        else
            record_verification_result "$instance_name:eip:wrong_address" $VERIFY_FAIL "Instance outputs show wrong EIP address"
            warn_message "               ❌ CRITICAL: Instance outputs show wrong EIP address:"
            warn_message "                  Instance output: '$output_eip_address'"
            warn_message "                  Expected from EIPs: '$expected_eip_address'"
            warn_message "                  AWS instance has: '$aws_public_ip'"
        fi
    else
        # No EIP expected according to EIPs module
        if [[ -n "$output_eip_address" && "$output_eip_address" != "null" ]]; then
            record_verification_result "$instance_name:eip:unexpected_eip" $VERIFY_FAIL "Instance claims to have EIP but none defined in EIPs module"
            warn_message "               ❌ CRITICAL: Instance claims EIP '$output_eip_address' but no EIP defined in EIPs module for '$eip_key_with_env'"
        else
            if [[ -n "$aws_public_ip" && -z "$aws_eip_allocation" ]]; then
                record_verification_result "$instance_name:eip:regular_ip" $VERIFY_PASS "Instance has regular public IP (no EIP expected)"
                info_message "               ✅ Instance has regular public IP as expected: $aws_public_ip"
            elif [[ -n "$aws_public_ip" && -n "$aws_eip_allocation" ]]; then
                record_verification_result "$instance_name:eip:unexpected_allocation" $VERIFY_WARN "Instance has EIP allocation but none expected"
                warn_message "               ⚠️  Instance has EIP allocation ($aws_eip_allocation) but none expected from configuration"
            else
                record_verification_result "$instance_name:eip:no_public_ip" $VERIFY_WARN "Instance has no public IP"
                warn_message "               ⚠️  Instance has no public IP address"
            fi
        fi
    fi
}

# Verify instance volume configuration
# Usage: verify_instance_volume_configuration instance_name instance_key outputs_file aws_instance ebss_outputs_file
verify_instance_volume_configuration() {
    local instance_name="$1"
    local instance_key="$2"
    local outputs_file="$3"
    local aws_instance="$4"
    local ebss_outputs_file="$5"
    
    debug_message "Verifying volume configuration for: $instance_name"
    info_message "         💾 Volume Configuration Analysis:"
    
    # Get volume data from outputs and AWS
    local output_attached_volumes=$(jq -r '.attached_volumes.value // {}' "$outputs_file")
    local output_ebs_attachments=$(jq -r '.ebs_attachments.value // {}' "$outputs_file")
    local aws_attached_volumes=$(echo "$aws_instance" | jq -r '[.BlockDeviceMappings[]?.Ebs?.VolumeId] | sort')
    local aws_ebs_attachments=$(echo "$aws_instance" | jq -r '[.BlockDeviceMappings[] | {device: .DeviceName, volume_id: .Ebs.VolumeId}] | sort_by(.device)')
    
    # Verify attached volumes - every output volume must exist in AWS
    local output_volumes_array=$(echo "$output_attached_volumes" | jq -r --arg key "$instance_key" '.[$key] // [] | sort')
    
    if is_verbose; then
        info_message "            attached_volumes: output='$output_volumes_array'"
        info_message "                             vs aws='$aws_attached_volumes'"
    fi
    
    local volume_verification_failed=false
    if [[ "$output_volumes_array" != "[]" && "$output_volumes_array" != "null" ]]; then
        while IFS= read -r output_volume; do
            [[ -n "$output_volume" && "$output_volume" != "null" ]] || continue
            
            output_volume=$(echo "$output_volume" | tr -d '"')
            
            if echo "$aws_attached_volumes" | jq -r '.[]' | grep -q "^${output_volume}$"; then
                record_verification_result "$instance_name:volumes:$output_volume" $VERIFY_PASS "Volume exists in AWS"
                debug_message "            ✅ Volume verified in AWS: $output_volume"
            else
                record_verification_result "$instance_name:volumes:$output_volume" $VERIFY_FAIL "Volume missing from AWS"
                warn_message "            ❌ Volume NOT found in AWS: $output_volume"
                volume_verification_failed=true
            fi
        done < <(echo "$output_volumes_array" | jq -r '.[]?' 2>/dev/null)
        
        if [[ "$volume_verification_failed" == false ]]; then
            local aws_volume_count=$(echo "$aws_attached_volumes" | jq -r 'length')
            local output_volume_count=$(echo "$output_volumes_array" | jq -r 'length')
            if [[ $aws_volume_count -gt $output_volume_count ]]; then
                info_message "            ℹ️  AWS has $aws_volume_count volumes, output tracks $output_volume_count (additional volumes like root are normal)"
            fi
        fi
    else
        info_message "            ℹ️  No volumes in output to verify"
    fi
    
    # Verify EBS attachments with device mapping
    local output_ebs_array=""
    if output_ebs_array=$(echo "$output_ebs_attachments" | jq -r --arg key "$instance_key" '
        .[$key] // {} | 
        if type == "object" then 
            [.[] | {device: .device_name, volume_id: .volume_id}] | sort_by(.device)
        else 
            []
        end
    ' 2>/dev/null); then
        
        if is_verbose; then
            info_message "            ebs_attachments: output='$output_ebs_array'"
            info_message "                            vs aws='$aws_ebs_attachments'"
        fi
        
        local attachment_verification_failed=false
        if [[ "$output_ebs_array" != "[]" && "$output_ebs_array" != "null" ]]; then
            local attachment_count=$(echo "$output_ebs_array" | jq -r 'length' 2>/dev/null)
            if [[ "$attachment_count" -gt 0 ]]; then
                for i in $(seq 0 $((attachment_count - 1))); do
                    local output_attachment=$(echo "$output_ebs_array" | jq -r ".[$i]" 2>/dev/null)
                    
                    if [[ -n "$output_attachment" && "$output_attachment" != "null" ]]; then
                        local output_device=$(echo "$output_attachment" | jq -r '.device // empty' 2>/dev/null)
                        local output_volume_id=$(echo "$output_attachment" | jq -r '.volume_id // empty' 2>/dev/null)
                        
                        if [[ -n "$output_device" && -n "$output_volume_id" ]]; then
                            local aws_match=$(echo "$aws_ebs_attachments" | jq -r --arg device "$output_device" --arg volume "$output_volume_id" '
                                .[] | select(.device == $device and .volume_id == $volume)
                            ' 2>/dev/null)
                            
                            if [[ -n "$aws_match" && "$aws_match" != "null" ]]; then
                                record_verification_result "$instance_name:attachments:$output_volume_id" $VERIFY_PASS "EBS attachment verified"
                                debug_message "            ✅ EBS attachment verified: $output_device -> $output_volume_id"
                            else
                                record_verification_result "$instance_name:attachments:$output_volume_id" $VERIFY_FAIL "EBS attachment missing from AWS"
                                warn_message "            ❌ EBS attachment NOT found in AWS: $output_device -> $output_volume_id"
                                attachment_verification_failed=true
                            fi
                        fi
                    fi
                done
                
                if [[ "$attachment_verification_failed" == false ]]; then
                    local aws_attachment_count=$(echo "$aws_ebs_attachments" | jq -r 'length' 2>/dev/null)
                    if [[ $aws_attachment_count -gt $attachment_count ]]; then
                        info_message "            ℹ️  AWS has $aws_attachment_count attachments, output tracks $attachment_count (additional attachments like root are normal)"
                    fi
                fi
            fi
        else
            info_message "            ℹ️  No EBS attachments in output to verify"
        fi
    else
        record_verification_result "$instance_name:attachments:parse_error" $VERIFY_FAIL "Cannot parse EBS attachments structure"
        warn_message "            ❌ Cannot parse EBS attachments structure"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Infrastructure Module Verification Placeholders
# ─────────────────────────────────────────────────────────────────────────────

# EBS comprehensive verification
verify_ebs_comprehensive() {
    local env="$1"
    local module="$2"
    info_message "   💾 EBS Comprehensive Analysis: $module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$module:verification:aws_cli" $VERIFY_WARN "AWS CLI not available for volume verification"
        return 0
    fi
    
    # Get EBS outputs and AWS region
    local env_path="$(get_environment_path "$env")"
    local ebs_outputs_file="$env_path/outputs/$module.json"
    local aws_region
    
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$module:verification:region" $VERIFY_WARN "Cannot get AWS region"
        return 0
    fi
    
    if [[ ! -f "$ebs_outputs_file" ]]; then
        record_verification_result "$module:verification:outputs" $VERIFY_WARN "EBS outputs file missing"
        return 0
    fi
    
    # Parse volume IDs from outputs
    local volume_ids
    if ! volume_ids=$(jq -r '.volume_ids.value // {} | to_entries[] | .value' "$ebs_outputs_file" 2>/dev/null); then
        record_verification_result "$module:verification:parse" $VERIFY_WARN "Cannot parse volume IDs"
        return 0
    fi
    
    if [[ -z "$volume_ids" ]]; then
        record_verification_result "$module:verification:empty" $VERIFY_PASS "No volumes to verify"
        return 0
    fi
    
    # Verify each volume exists in AWS
    local volume_count=0
    local verified_count=0
    
    while read -r volume_id; do
        if [[ -z "$volume_id" || "$volume_id" == "null" ]]; then
            continue
        fi
        
        ((volume_count++))
        
        if aws ec2 describe-volumes --volume-ids "$volume_id" --region "$aws_region" --output json >/dev/null 2>&1; then
            ((verified_count++))
            record_verification_result "$module:volume:$volume_id" $VERIFY_PASS "Volume exists in AWS"
        else
            record_verification_result "$module:volume:$volume_id" $VERIFY_FAIL "Volume not found in AWS"
        fi
    done < <(echo "$volume_ids")
    
    record_verification_result "$module:verification:summary" $VERIFY_PASS "Verified $verified_count of $volume_count volumes"
}

# EIP comprehensive verification  
verify_eip_comprehensive() {
    local env="$1"
    local module="$2"
    info_message "   🌐 EIP Comprehensive Analysis: $module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$module:verification:aws_cli" $VERIFY_WARN "AWS CLI not available for EIP verification"
        return 0
    fi
    
    # Get EIP outputs and AWS region
    local env_path="$(get_environment_path "$env")"
    local eip_outputs_file="$env_path/outputs/$module.json"
    local aws_region
    
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$module:verification:region" $VERIFY_WARN "Cannot get AWS region"
        return 0
    fi
    
    if [[ ! -f "$eip_outputs_file" ]]; then
        record_verification_result "$module:verification:outputs" $VERIFY_WARN "EIP outputs file missing"
        return 0
    fi
    
    # Parse EIP addresses from outputs
    local eip_addresses
    if ! eip_addresses=$(jq -r '.eip_addresses.value // {} | to_entries[] | .value' "$eip_outputs_file" 2>/dev/null); then
        record_verification_result "$module:verification:parse" $VERIFY_WARN "Cannot parse EIP addresses"
        return 0
    fi
    
    if [[ -z "$eip_addresses" ]]; then
        record_verification_result "$module:verification:empty" $VERIFY_PASS "No EIPs to verify"
        return 0
    fi
    
    # Verify each EIP exists in AWS
    local eip_count=0
    local verified_count=0
    
    while read -r eip_address; do
        if [[ -z "$eip_address" || "$eip_address" == "null" ]]; then
            continue
        fi
        
        ((eip_count++))
        
        if aws ec2 describe-addresses --public-ips "$eip_address" --region "$aws_region" --output json >/dev/null 2>&1; then
            ((verified_count++))
            record_verification_result "$module:eip:$eip_address" $VERIFY_PASS "EIP exists in AWS"
        else
            record_verification_result "$module:eip:$eip_address" $VERIFY_FAIL "EIP not found in AWS"
        fi
    done < <(echo "$eip_addresses")
    
    record_verification_result "$module:verification:summary" $VERIFY_PASS "Verified $verified_count of $eip_count EIPs"
}

# ECR comprehensive verification
verify_ecr_comprehensive() {
    local env="$1" 
    local module="$2"
    info_message "   📦 ECR Comprehensive Analysis: $module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$module:verification:aws_cli" $VERIFY_WARN "AWS CLI not available for ECR verification"
        return 0
    fi
    
    # Get ECR outputs and AWS region
    local env_path="$(get_environment_path "$env")"
    local ecr_outputs_file="$env_path/outputs/$module.json"
    local aws_region
    
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$module:verification:region" $VERIFY_WARN "Cannot get AWS region"
        return 0
    fi
    
    if [[ ! -f "$ecr_outputs_file" ]]; then
        record_verification_result "$module:verification:outputs" $VERIFY_WARN "ECR outputs file missing"
        return 0
    fi
    
    # Parse repository names from outputs
    local repo_names
    if ! repo_names=$(jq -r '.repositories.value // {} | to_entries[] | .key' "$ecr_outputs_file" 2>/dev/null); then
        record_verification_result "$module:verification:parse" $VERIFY_WARN "Cannot parse repository names"
        return 0
    fi
    
    if [[ -z "$repo_names" ]]; then
        record_verification_result "$module:verification:empty" $VERIFY_PASS "No repositories to verify"
        return 0
    fi
    
    # Verify each repository exists in AWS
    local repo_count=0
    local verified_count=0
    
    while read -r repo_name; do
        if [[ -z "$repo_name" || "$repo_name" == "null" ]]; then
            continue
        fi
        
        ((repo_count++))
        
        if aws ecr describe-repositories --repository-names "$repo_name" --region "$aws_region" --output json >/dev/null 2>&1; then
            ((verified_count++))
            record_verification_result "$module:repo:$repo_name" $VERIFY_PASS "Repository exists in AWS"
        else
            record_verification_result "$module:repo:$repo_name" $VERIFY_WARN "Repository not found in AWS"
        fi
    done < <(echo "$repo_names")
    
    record_verification_result "$module:verification:summary" $VERIFY_PASS "Verified $verified_count of $repo_count repositories"
}

# VPC comprehensive verification
verify_vpc_comprehensive() {
    local env="$1"
    local module="$2" 
    info_message "   🌐 VPC Comprehensive Analysis: $module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$module:verification:aws_cli" $VERIFY_WARN "AWS CLI not available for VPC verification"
        return 0
    fi
    
    # Get VPC outputs and AWS region
    local env_path="$(get_environment_path "$env")"
    local vpc_outputs_file="$env_path/outputs/$module.json"
    local aws_region
    
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$module:verification:region" $VERIFY_WARN "Cannot get AWS region"
        return 0
    fi
    
    if [[ ! -f "$vpc_outputs_file" ]]; then
        record_verification_result "$module:verification:outputs" $VERIFY_WARN "VPC outputs file missing"
        return 0
    fi
    
    # Parse VPC IDs from outputs
    local vpc_ids
    if ! vpc_ids=$(jq -r '.vpc_ids.value // {} | to_entries[] | .value' "$vpc_outputs_file" 2>/dev/null); then
        record_verification_result "$module:verification:parse" $VERIFY_WARN "Cannot parse VPC IDs"
        return 0
    fi
    
    if [[ -z "$vpc_ids" ]]; then
        record_verification_result "$module:verification:empty" $VERIFY_PASS "No VPCs to verify"
        return 0
    fi
    
    # Verify each VPC exists in AWS
    local vpc_count=0
    local verified_count=0
    
    while read -r vpc_id; do
        if [[ -z "$vpc_id" || "$vpc_id" == "null" ]]; then
            continue
        fi
        
        ((vpc_count++))
        
        if aws ec2 describe-vpcs --vpc-ids "$vpc_id" --region "$aws_region" --output json >/dev/null 2>&1; then
            ((verified_count++))
            record_verification_result "$module:vpc:$vpc_id" $VERIFY_PASS "VPC exists in AWS"
        else
            record_verification_result "$module:vpc:$vpc_id" $VERIFY_FAIL "VPC not found in AWS"
        fi
    done < <(echo "$vpc_ids")
    
    record_verification_result "$module:verification:summary" $VERIFY_PASS "Verified $verified_count of $vpc_count VPCs"
}

# Security Group comprehensive verification
verify_sg_comprehensive() {
    local env="$1"
    local module="$2"
    info_message "   🔒 Security Group Comprehensive Analysis: $module"
    
    # Check if AWS CLI is available
    if ! validate_aws_cli >/dev/null 2>&1; then
        record_verification_result "$module:verification:aws_cli" $VERIFY_WARN "AWS CLI not available for SG verification"
        return 0
    fi
    
    # Get Security Group outputs and AWS region
    local env_path="$(get_environment_path "$env")"
    local sg_outputs_file="$env_path/outputs/$module.json"
    local aws_region
    
    if ! aws_region=$(get_aws_region "$env" 2>/dev/null); then
        record_verification_result "$module:verification:region" $VERIFY_WARN "Cannot get AWS region"
        return 0
    fi
    
    if [[ ! -f "$sg_outputs_file" ]]; then
        record_verification_result "$module:verification:outputs" $VERIFY_WARN "Security Group outputs file missing"
        return 0
    fi
    
    # Parse Security Group IDs from outputs
    local sg_ids
    if ! sg_ids=$(jq -r '.security_group_ids.value // {} | to_entries[] | .value' "$sg_outputs_file" 2>/dev/null); then
        record_verification_result "$module:verification:parse" $VERIFY_WARN "Cannot parse Security Group IDs"
        return 0
    fi
    
    if [[ -z "$sg_ids" ]]; then
        record_verification_result "$module:verification:empty" $VERIFY_PASS "No Security Groups to verify"
        return 0
    fi
    
    # Verify each Security Group exists in AWS
    local sg_count=0
    local verified_count=0
    
    while read -r sg_id; do
        if [[ -z "$sg_id" || "$sg_id" == "null" ]]; then
            continue
        fi
        
        ((sg_count++))
        
        if aws ec2 describe-security-groups --group-ids "$sg_id" --region "$aws_region" --output json >/dev/null 2>&1; then
            ((verified_count++))
            record_verification_result "$module:sg:$sg_id" $VERIFY_PASS "Security Group exists in AWS"
        else
            record_verification_result "$module:sg:$sg_id" $VERIFY_FAIL "Security Group not found in AWS"
        fi
    done < <(echo "$sg_ids")
    
    record_verification_result "$module:verification:summary" $VERIFY_PASS "Verified $verified_count of $sg_count Security Groups"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

debug_message "Comprehensive verification module loaded successfully"

debug_message "Verification module loaded successfully"
