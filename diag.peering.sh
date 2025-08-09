#!/bin/bash

# VPC Peering Diagnostics
# Validates VPC peering connection IDs from peering module outputs

set -euo pipefail

# Usage: diag_peering_module "env" "peering-dev|peering-prod"
diag_peering_module() {
    local env="$1"
    local module="$2"

    print_section_header "VPC Peering Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    # Attempt to discover peering connection IDs in outputs
    print_diag_table_header_peering
    local pcx_ids
    pcx_ids=$(jq -r '..|strings?|select(startswith("pcx-"))' "$outputs_file" 2>/dev/null | sort -u || true)
    if [[ -z "$pcx_ids" ]]; then
        warn_message "   ❌ No VPC peering connection IDs found in outputs"
        return 1
    fi

    local count=0
    while read -r pcx; do
        [[ -z "$pcx" ]] && continue
        ((count++))
        local pcx_json
        if ! pcx_json=$(aws_describe_vpc_peering_connection "$env" "$pcx"); then
            warn_message "   ❌ Peering connection not found: $pcx"
            continue
        fi
        local status req acct1 acct2
        status=$(echo "$pcx_json" | jq -r '.Status.Code // empty')
        acct1=$(echo "$pcx_json" | jq -r '.RequesterVpcInfo.VpcId // empty')
        acct2=$(echo "$pcx_json" | jq -r '.AccepterVpcInfo.VpcId // empty')
        print_diag_table_row_peering "$pcx" "$status" "$acct1" "$acct2"
    done < <(echo "$pcx_ids")

    success_message "✅ VPC Peering diagnostics completed ($count connection(s))"
}

