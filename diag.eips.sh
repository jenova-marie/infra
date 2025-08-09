#!/bin/bash

# EIPs Diagnostics
# Validates Elastic IP addresses from eips outputs

set -euo pipefail

# Usage: diag_eips_module "env" "eips"
diag_eips_module() {
    local env="$1"
    local module="$2"

    print_section_header "EIPs Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    print_diag_table_header_eips
    local eips
    eips=$(jq -r '.eip_addresses.value // {} | to_entries[] | .value' "$outputs_file" 2>/dev/null || true)
    if [[ -z "$eips" ]]; then
        warn_message "   ❌ No EIP addresses found in outputs"
        return 1
    fi

    local count=0
    while read -r ip; do
        [[ -z "$ip" || "$ip" == "null" ]] && continue
        count=$((count + 1))
        local eip_json
        if ! eip_json=$(aws_eip_describe_address "$env" "$ip"); then
            warn_message "   ❌ EIP not found: $ip"
            continue
        fi
        local alloc assoc inst ni dom
        alloc=$(echo "$eip_json" | jq -r '.AllocationId // empty')
        assoc=$(echo "$eip_json" | jq -r '.AssociationId // empty')
        inst=$(echo "$eip_json" | jq -r '.InstanceId // empty')
        ni=$(echo "$eip_json" | jq -r '.NetworkInterfaceId // empty')
        dom=$(echo "$eip_json" | jq -r '.Domain // empty')
        print_diag_table_row_eips "$ip" "$alloc" "$assoc" "$inst" "$ni" "$dom"
    done < <(echo "$eips")

    success_message "✅ EIPs diagnostics completed ($count address(es))"
}

