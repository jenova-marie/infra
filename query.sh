#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Query Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Query values from outputs/*.json for a given env:target and path
# Author: Infrastructure Management System v2.0
# Last Updated: January 14, 2025

set -euo pipefail

# Usage info
show_usage() {
    echo "Usage: $0 <env>:<target>[,<target2>...] <path>"
    echo "  env      - Environment name (e.g. dev, prod)"
    echo "  target   - Module/instance name(s) (comma-separated for multiple)"
    echo "  path     - Dot notation path into outputs JSON (e.g. public_ip, foo.bar)"
    echo ""
    echo "Example: $0 dev:athena public_ip"
    echo "         $0 dev:athena,metis foo.bar.baz"
    exit 1
}

# Use variables from infra argument parsing if available
if [[ -n "${ENVIRONMENT:-}" && -n "${TARGET_TYPE:-}" && -n "${QUERY_PATH:-}" ]]; then
    ENV="$ENVIRONMENT"
    TARGETS_RAW="$TARGET_TYPE"
    IFS=',' read -r -a TARGETS <<< "$TARGETS_RAW"
else
    # Fallback for standalone usage (not typical)
    if [[ $# -ne 2 ]]; then
        show_usage
    fi
    ARG1="$1"
    QUERY_PATH="$2"
    if [[ "$ARG1" != *:* ]]; then
        echo "Error: First argument must be in the form <env>:<target>" >&2
        show_usage
    fi
    ENV="${ARG1%%:*}"
    TARGETS_RAW="${ARG1#*:}"
    IFS=',' read -r -a TARGETS <<< "$TARGETS_RAW"
fi

# Prepare result JSON
RESULTS="{}"

for TARGET in "${TARGETS[@]}"; do
    OUTPUT_FILE="$(get_module_output_path "$ENV" "$TARGET")"
    VALUE=null
    if file_exists_and_readable "$OUTPUT_FILE"; then
        # Use jq to extract the value at the path, or null if missing
        if VALUE_RAW=$(jq -er ".${QUERY_PATH} // null" "$OUTPUT_FILE" 2>/dev/null); then
            VALUE="$VALUE_RAW"
        fi
    fi
    # Compose the result JSON (handle string/non-string values)
    # If VALUE is a valid JSON value (null, number, boolean, object, array), use --argjson; otherwise, use --arg
    if [[ "$VALUE" == "null" || "$VALUE" == "true" || "$VALUE" == "false" || "$VALUE" =~ ^-?[0-9]+(\.[0-9]+)?$ || ( "$VALUE" =~ ^\[.*\]$ ) || ( "$VALUE" =~ ^\{.*\}$ ) ]]; then
        RESULTS=$(echo "$RESULTS" | jq --arg key "$TARGET" --argjson val "$VALUE" '. + {($key): $val}')
    else
        # Remove surrounding quotes if present (from jq -er)
        if [[ "$VALUE" =~ ^\".*\"$ ]]; then
            VALUE_STRIPPED="${VALUE:1:-1}"
        else
            VALUE_STRIPPED="$VALUE"
        fi
        RESULTS=$(echo "$RESULTS" | jq --arg key "$TARGET" --arg val "$VALUE_STRIPPED" '. + {($key): $val}')
    fi

done

# Output the final JSON result
echo "$RESULTS"
