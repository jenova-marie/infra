#!/bin/bash

# VPC and VPC Routes Diagnostics
# Validates VPCs (from vpcs outputs) and Route Tables (from vpc_routes outputs)

set -euo pipefail

# Usage: diag_vpc_module "env" "vpcs|vpc_routes"
diag_vpc_module() {
    local env="$1"
    local module="$2"

    print_section_header "VPC Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    case "$module" in
        "vpcs")
            print_diag_table_header_vpc
            local vpc_ids
            vpc_ids=$(jq -r '.vpc_ids.value // {} | to_entries[] | .value' "$outputs_file" 2>/dev/null || true)
            if [[ -z "$vpc_ids" ]]; then
                warn_message "   ❌ No VPC IDs found in outputs"
                return 1
            fi
            local count=0
            while read -r vpc_id; do
                [[ -z "$vpc_id" || "$vpc_id" == "null" ]] && continue
                count=$((count + 1))
                local vpc_json
                if ! vpc_json=$(aws_describe_vpc "$env" "$vpc_id"); then
                    warn_message "   ❌ VPC not found: $vpc_id"
                    continue
                fi
                local state cidr default dhcp rt_count sn_count igw
                state=$(echo "$vpc_json" | jq -r '.State // empty')
                cidr=$(echo "$vpc_json" | jq -r '.CidrBlock // empty')
                default=$(echo "$vpc_json" | jq -r '.IsDefault // false')
                dhcp=$(echo "$vpc_json" | jq -r '.DhcpOptionsId // empty')
                rt_count=$(aws_count_route_tables_in_vpc "$env" "$vpc_id")
                sn_count=$(aws_count_subnets_in_vpc "$env" "$vpc_id")
                igw=$(aws_is_igw_attached_to_vpc "$env" "$vpc_id")
                print_diag_table_row_vpc "$vpc_id" "$state" "$cidr" "$default" "$dhcp" "$sn_count" "$rt_count" "$igw"
            done < <(echo "$vpc_ids")
            success_message "✅ VPC diagnostics completed ($count VPC(s))"
            ;;
        "vpc_routes")
            # Delegate to specialized vpc_routes diagnostics module
            source "$SCRIPT_DIR/diag.vpc_routes.sh" 2>/dev/null || true
            if declare -f diag_vpc_routes_module >/dev/null 2>&1; then
                diag_vpc_routes_module "$env" "$module"
            else
                handle_error "Diagnostics not yet implemented for module: $module"
            fi
            ;;
        *)
            handle_error "Unsupported VPC diagnostic module: $module"
            ;;
    esac
}

