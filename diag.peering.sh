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
        count=$((count + 1))
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

        # Show any route tables that reference this peering connection
        local rts_json
        rts_json=$(aws_list_route_tables_for_pcx "$env" "$pcx" 2>/dev/null || echo "[]")
        local rt_count
        rt_count=$(echo "$rts_json" | jq -r 'length')
        if [[ ${rt_count:-0} -gt 0 ]]; then
            # Summary of route tables
            print_diag_table_header_vpc_routes
            echo "$rts_json" | jq -c '.[]' | while read -r rtb; do
                local rtb_id routes assoc
                rtb_id=$(echo "$rtb" | jq -r '.RouteTableId // empty')
                routes=$(echo "$rtb" | jq -r '.Routes | length')
                assoc=$(echo "$rtb" | jq -r '.Associations | length')
                print_diag_table_row_vpc_routes "$rtb_id" "$routes" "$assoc"
                # Detailed routes in this table
                local route_entries
                route_entries=$(echo "$rtb" | jq -r '.Routes[]? | @base64' 2>/dev/null || true)
                if [[ -n "$route_entries" ]]; then
                    print_diag_table_header_vpc_route_entries
                    while read -r encoded; do
                        [[ -z "$encoded" ]] && continue
                        local route_json
                        route_json=$(echo "$encoded" | base64 --decode 2>/dev/null || echo "{}")
                        local destination target target_type state origin
                        destination=$(echo "$route_json" | jq -r '(.DestinationCidrBlock // .DestinationIpv6CidrBlock // .DestinationPrefixListId // "")' 2>/dev/null || echo "")
                        target=$(echo "$route_json" | jq -r '(.GatewayId // .NatGatewayId // .TransitGatewayId // .VpcPeeringConnectionId // .EgressOnlyInternetGatewayId // .NetworkInterfaceId // .InstanceId // "")' 2>/dev/null || echo "")
                        if [[ -n "$target" ]]; then
                            if   echo "$route_json" | jq -e '.GatewayId?    ' >/dev/null 2>&1; then target_type="IGW/VGW";
                            elif echo "$route_json" | jq -e '.NatGatewayId?' >/dev/null 2>&1; then target_type="NAT";
                            elif echo "$route_json" | jq -e '.TransitGatewayId?' >/dev/null 2>&1; then target_type="TGW";
                            elif echo "$route_json" | jq -e '.VpcPeeringConnectionId?' >/dev/null 2>&1; then target_type="PCX";
                            elif echo "$route_json" | jq -e '.EgressOnlyInternetGatewayId?' >/dev/null 2>&1; then target_type="EIGW";
                            elif echo "$route_json" | jq -e '.NetworkInterfaceId?' >/dev/null 2>&1; then target_type="ENI";
                            elif echo "$route_json" | jq -e '.InstanceId?' >/dev/null 2>&1; then target_type="Instance";
                            else target_type="Other"; fi
                        else
                            target_type="Blackhole"
                        fi
                        state=$(echo "$route_json" | jq -r '.State // ""' 2>/dev/null || echo "")
                        origin=$(echo "$route_json" | jq -r '.Origin // ""' 2>/dev/null || echo "")
                        print_diag_table_row_vpc_route_entry "${destination:-}" "${target:-}" "${target_type:-}" "${state:-}" "${origin:-}"
                    done < <(echo "$route_entries")
                    echo ""
                fi
                # Associations for this table
                local assoc_entries
                assoc_entries=$(echo "$rtb" | jq -r '.Associations[]? | @base64' 2>/dev/null || true)
                if [[ -n "$assoc_entries" ]]; then
                    print_diag_table_header_vpc_route_associations
                    while read -r aencoded; do
                        [[ -z "$aencoded" ]] && continue
                        local assoc_json
                        assoc_json=$(echo "$aencoded" | base64 --decode 2>/dev/null || echo "{}")
                        local assoc_id is_main subnet_id
                        assoc_id=$(echo "$assoc_json" | jq -r '.RouteTableAssociationId // ""' 2>/dev/null || echo "")
                        is_main=$(echo "$assoc_json" | jq -r '.Main // false' 2>/dev/null || echo "false")
                        subnet_id=$(echo "$assoc_json" | jq -r '.SubnetId // ""' 2>/dev/null || echo "")
                        print_diag_table_row_vpc_route_association "${assoc_id:-}" "${is_main}" "${subnet_id:-}" "$rtb_id"
                    done < <(echo "$assoc_entries")
                    echo ""
                fi
            done
        else
            debug_message "No route tables reference peering $pcx"
        fi
    done < <(echo "$pcx_ids")

    success_message "✅ VPC Peering diagnostics completed ($count connection(s))"
}

