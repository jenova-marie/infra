#!/bin/bash

# Security Groups Diagnostics
# Validates security group IDs from outputs using AWS helpers

set -euo pipefail

# Usage: diag_security_groups_module "env" "security_groups"
diag_security_groups_module() {
    local env="$1"
    local module="$2"

    print_section_header "Security Groups Diagnostics - $env:$module"

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    # Iterate SG IDs
    local sg_ids
    sg_ids=$(jq -r '.security_group_ids.value // {} | to_entries[] | .value' "$outputs_file" 2>/dev/null || true)
    if [[ -z "$sg_ids" ]]; then
        warn_message "   ❌ No security groups in outputs"
        return 1
    fi

    print_diag_table_header_sg
    local count=0
    while read -r sg_id; do
        [[ -z "$sg_id" || "$sg_id" == "null" ]] && continue
        count=$((count + 1))
        local sg_json
        if ! sg_json=$(aws_describe_security_group "$env" "$sg_id"); then
            warn_message "   ❌ SG not found: $sg_id"
            continue
        fi
        local name vpc ingress egress
        name=$(echo "$sg_json" | jq -r '.GroupName // empty')
        vpc=$(echo "$sg_json" | jq -r '.VpcId // empty')
        ingress=$(echo "$sg_json" | jq -r '.IpPermissions | length')
        egress=$(echo "$sg_json" | jq -r '.IpPermissionsEgress | length')
        local inst_count
        inst_count=$(aws_count_instances_with_sg "$env" "$sg_id")
        print_diag_table_row_sg "$sg_id" "$name" "$vpc" "$ingress" "$egress" "$inst_count"
    done < <(echo "$sg_ids")

    success_message "✅ Security Groups diagnostics completed ($count group(s))"
}

