#!/bin/bash

# EC2 Instance Diagnostics
# Validates instance IDs and key attributes from outputs using AWS helpers

set -euo pipefail

# Usage: diag_ec2_module "dev" "athena"
diag_ec2_module() {
    local env="$1"
    local instance_name="$2"

    print_section_header "EC2 Diagnostics - $env:$instance_name"

    local env_path="$(get_environment_path "$env")"
    local outputs_file="$env_path/outputs/$instance_name.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    # Instance ID
    local instance_id
    instance_id=$(jq -r --arg k "$instance_name" '.instance_ids.value[$k] // empty' "$outputs_file" 2>/dev/null || echo "")
    if [[ -z "$instance_id" || "$instance_id" == "null" ]]; then
        warn_message "   ❌ No instance ID for $instance_name"
        return 1
    fi
    info_message "   🔎 Instance ID: $instance_id"

    # Describe instance
    print_diag_table_header_ec2

    local inst
    if ! inst=$(aws_get_instance_object "$env" "$instance_id"); then
        warn_message "   ❌ Instance not found in AWS: $instance_id"
        return 1
    fi

    local state type pub priv az
    state=$(echo "$inst" | jq -r '.State.Name // empty')
    type=$(echo "$inst" | jq -r '.InstanceType // empty')
    pub=$(echo "$inst" | jq -r '.PublicIpAddress // empty')
    priv=$(echo "$inst" | jq -r '.PrivateIpAddress // empty')
    az=$(echo "$inst" | jq -r '.Placement.AvailabilityZone // empty')

    print_diag_table_row_ec2 "$instance_id" "$state" "$type" "$az" "$pub" "$priv"

    success_message "✅ EC2 diagnostics completed for $instance_name"
}

