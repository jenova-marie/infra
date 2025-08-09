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
                ((count++))
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
            print_diag_table_header_vpc_routes
            local rtb_ids
            rtb_ids=$(jq -r '..|strings?|select(startswith("rtb-"))' "$outputs_file" 2>/dev/null | sort -u || true)
            if [[ -z "$rtb_ids" ]]; then
                warn_message "   ❌ No route table IDs found in outputs"
                return 1
            fi
            local count=0
            while read -r rtb_id; do
                [[ -z "$rtb_id" ]] && continue
                ((count++))
                local rtb_json
                if ! rtb_json=$(aws_describe_route_table "$env" "$rtb_id"); then
                    warn_message "   ❌ Route Table not found: $rtb_id"
                    continue
                fi
                local routes assoc
                routes=$(echo "$rtb_json" | jq -r '.Routes | length')
                assoc=$(echo "$rtb_json" | jq -r '.Associations | length')
                print_diag_table_row_vpc_routes "$rtb_id" "$routes" "$assoc"
            done < <(echo "$rtb_ids")
            success_message "✅ VPC Routes diagnostics completed ($count route table(s))"
            ;;
        *)
            handle_error "Unsupported VPC diagnostic module: $module"
            ;;
    esac
}

