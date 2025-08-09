#!/bin/bash

# VPC Routes Diagnostics (extracted from diag.vpc.sh)
# Validates Route Tables from vpc_routes outputs using AWS helpers

set -euo pipefail

# Usage: diag_vpc_routes_module "env" "vpc_routes"
diag_vpc_routes_module() {
    local env="$1"
    local module="$2"

    print_section_header "VPC Routes Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

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
        count=$((count + 1))
        local rtb_json
        if ! rtb_json=$(aws_describe_route_table "$env" "$rtb_id"); then
            warn_message "   ❌ Route Table not found: $rtb_id"
            continue
        fi
        local routes assoc
        routes=$(echo "$rtb_json" | jq -r '.Routes | length')
        assoc=$(echo "$rtb_json" | jq -r '.Associations | length')
        print_diag_table_row_vpc_routes "$rtb_id" "$routes" "$assoc"

        # Show per-route details below the summary row
        local route_entries
        route_entries=$(echo "$rtb_json" | jq -r '.Routes[]? | @base64' 2>/dev/null || true)
        if [[ -n "$route_entries" ]]; then
            print_diag_table_header_vpc_route_entries
            while read -r encoded; do
                [[ -z "$encoded" ]] && continue
                local route_json
                route_json=$(echo "$encoded" | base64 --decode 2>/dev/null || echo "{}")
                # Extract key fields with guards
                local destination target target_type state origin
                destination=$(echo "$route_json" | jq -r '(.DestinationCidrBlock // .DestinationIpv6CidrBlock // .DestinationPrefixListId // "")' 2>/dev/null || echo "")
                target=$(echo "$route_json" | jq -r '(.GatewayId // .NatGatewayId // .TransitGatewayId // .VpcPeeringConnectionId // .EgressOnlyInternetGatewayId // .NetworkInterfaceId // .InstanceId // "")' 2>/dev/null || echo "")
                # Determine target type label
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

        # Show associations for this route table
        local assoc_entries
        assoc_entries=$(echo "$rtb_json" | jq -r '.Associations[]? | @base64' 2>/dev/null || true)
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
    done < <(echo "$rtb_ids")

    success_message "✅ VPC Routes diagnostics completed ($count route table(s))"
}
