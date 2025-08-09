#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Diagnostics Orchestrator
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Entry-point for per-module diagnostics (env:module)

set -euo pipefail

# Expect to be sourced by main infra orchestrator; guard if run directly
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Run diagnostics for a specific env:module
# Usage: execute_diag_operation
execute_diag_operation() {
    # Gather context
    get_operation_context
    local env="$OP_ENV"
    local target="$OP_TARGET_TYPE"  # may be "infrastructure", specific module, etc.

    # We require env:module explicit targeting
    if [[ "$target" == "all" || "$target" == "infrastructure" || "$target" == "instances" ]]; then
        handle_error "diag requires explicit env:module target (e.g., dev:ebss or dev:athena)"
    fi

    local module="$target"

    # Load modules to determine type
    load_modules "$env"
    local module_type
    module_type=$(get_module_type "$module" 2>/dev/null || echo "")

    if [[ -z "$module_type" ]]; then
        handle_error "Cannot determine module type for: $module"
    fi

    # Route to module-specific diag implementation
    case "$module_type" in
        "instance")
            source "$SCRIPT_DIR/diag.ec2.sh"
            diag_ec2_module "$env" "$module"
            ;;
        "infrastructure")
            case "$module" in
                "security_groups")
                    source "$SCRIPT_DIR/diag.security_groups.sh"
                    diag_security_groups_module "$env" "$module"
                    ;;
                "vpcs"|"vpc_routes")
                    source "$SCRIPT_DIR/diag.vpc.sh" 2>/dev/null || true
                    if declare -f diag_vpc_module >/dev/null 2>&1; then
                        diag_vpc_module "$env" "$module"
                    else
                        handle_error "Diagnostics not yet implemented for module: $module"
                    fi
                    ;;
                "eips")
                    source "$SCRIPT_DIR/diag.eips.sh" 2>/dev/null || true
                    if declare -f diag_eips_module >/dev/null 2>&1; then
                        diag_eips_module "$env" "$module"
                    else
                        handle_error "Diagnostics not yet implemented for module: $module"
                    fi
                    ;;
                "ebss")
                    source "$SCRIPT_DIR/diag.ebs.sh" 2>/dev/null || true
                    if declare -f diag_ebs_module >/dev/null 2>&1; then
                        diag_ebs_module "$env" "$module"
                    else
                        handle_error "Diagnostics not yet implemented for module: $module"
                    fi
                    ;;
                "ecrs")
                    source "$SCRIPT_DIR/diag.ecr.sh" 2>/dev/null || true
                    if declare -f diag_ecr_module >/dev/null 2>&1; then
                        diag_ecr_module "$env" "$module"
                    else
                        handle_error "Diagnostics not yet implemented for module: $module"
                    fi
                    ;;
                "peering-dev"|"peering-prod")
                    source "$SCRIPT_DIR/diag.peering.sh" 2>/dev/null || true
                    if declare -f diag_peering_module >/dev/null 2>&1; then
                        diag_peering_module "$env" "$module"
                    else
                        handle_error "Diagnostics not yet implemented for module: $module"
                    fi
                    ;;
                *)
                    handle_error "Diagnostics not yet implemented for module: $module"
                    ;;
            esac
            ;;
        *)
            handle_error "Unsupported module type: $module_type"
            ;;
    esac
}

