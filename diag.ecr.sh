#!/bin/bash

# ECR Diagnostics
# Validates ECR repositories from ecrs outputs

set -euo pipefail

# Usage: diag_ecr_module "env" "ecrs"
diag_ecr_module() {
    local env="$1"
    local module="$2"

    print_section_header "ECR Diagnostics - $env:$module"

    if ! validate_aws_cli >/dev/null 2>&1; then
        warn_message "   ❌ AWS CLI not available - cannot run diagnostics"
        return 1
    fi

    local outputs_file="$(get_environment_path "$env")/outputs/$module.json"
    if [[ ! -f "$outputs_file" ]]; then
        warn_message "   ❌ Outputs file missing: $outputs_file"
        return 1
    fi

    print_diag_table_header_ecr
    local repo_names
    repo_names=$(jq -r '.repositories.value // {} | to_entries[] | .key' "$outputs_file" 2>/dev/null || true)
    if [[ -z "$repo_names" ]]; then
        warn_message "   ❌ No repositories found in outputs"
        return 1
    fi

    local count=0
    local total_images=0
    while read -r repo; do
        [[ -z "$repo" || "$repo" == "null" ]] && continue
        ((count++))
        local repo_json
        if ! repo_json=$(aws_ecr_describe_repository "$env" "$repo"); then
            warn_message "   ❌ Repository not found: $repo"
            continue
        fi
        local arn uri created mutability scan
        arn=$(echo "$repo_json" | jq -r '.repositoryArn // empty')
        uri=$(echo "$repo_json" | jq -r '.repositoryUri // empty')
        mutability=$(echo "$repo_json" | jq -r '.imageTagMutability // empty')
        scan=$(echo "$repo_json" | jq -r '.imageScanningConfiguration.scanOnPush // false')
        local image_count
        image_count=$(aws_ecr_list_images_count "$env" "$repo")
        ((total_images += image_count))
        print_diag_table_row_ecr "$repo" "$image_count" "$mutability" "$scan"
    done < <(echo "$repo_names")

    success_message "✅ ECR diagnostics completed ($count repo(s), $total_images image(s))"
}

