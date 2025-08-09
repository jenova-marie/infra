#!/bin/bash

# EBS Diagnostics
# Validates EBS volume IDs from ebss outputs

set -euo pipefail

# Usage: diag_ebs_module "env" "ebss"
diag_ebs_module() {
    local env="$1"
    local module="$2"

    print_section_header "EBS Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    print_diag_table_header_ebs
    local volume_ids
    volume_ids=$(jq -r '.volume_ids.value // {} | to_entries[] | .value' "$outputs_file" 2>/dev/null || true)
    if [[ -z "$volume_ids" ]]; then
        warn_message "   ❌ No volume IDs found in outputs"
        return 1
    fi

    local count=0
    while read -r vol_id; do
        [[ -z "$vol_id" || "$vol_id" == "null" ]] && continue
        count=$((count + 1))
        local vol_json
        if ! vol_json=$(aws_describe_volume "$env" "$vol_id"); then
            warn_message "   ❌ Volume not found: $vol_id"
            continue
        fi
        local state size type az encrypted
        state=$(echo "$vol_json" | jq -r '.State // empty')
        size=$(echo "$vol_json" | jq -r '.Size // 0')
        type=$(echo "$vol_json" | jq -r '.VolumeType // empty')
        az=$(echo "$vol_json" | jq -r '.AvailabilityZone // empty')
        encrypted=$(echo "$vol_json" | jq -r '.Encrypted // false')
        print_diag_table_row_ebs "$vol_id" "$state" "$size" "$type" "$az" "$encrypted"
    done < <(echo "$volume_ids")

    success_message "✅ EBS diagnostics completed ($count volume(s))"
}

