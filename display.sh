#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Display Module
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Operation summaries and user interface display
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2024

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Operation Summary and Display
# ─────────────────────────────────────────────────────────────────────────────

# Display operation summary
# Usage: show_operation_summary
show_operation_summary() {
    if [[ "${QUIET_MODE:-0}" -eq 1 ]]; then return; fi
    # Use KISS approach - get all operation context in one call
    get_operation_context
    
    info_message "Infrastructure Management System v2.0"
    info_message "═══════════════════════════════════════════════════════════════════════════"
    
    # Show parsed arguments summary
    show_arguments_summary
    
    # Show target resolution (using KISS variable)
    show_target_resolution "$OP_TARGET_TYPE"
    
    # Show dry-run warning if applicable (using standardized check)
    if is_dry_run; then
        warn_message "DRY-RUN MODE: No actual changes will be made"
    fi
    
    info_message "═══════════════════════════════════════════════════════════════════════════"
}

# Show parsed arguments summary
# Usage: show_arguments_summary
show_arguments_summary() {
    debug_message "Displaying arguments summary"
    
    # Use KISS approach - get all operation context in one call  
    get_operation_context
    
    local target=$(get_target)
    
    info_message "📋 Operation Summary:"
    info_message "  Action: $OP_ACTION"
    info_message "  Target: $target"
    info_message "  Environment: $OP_ENV"
    info_message "  Target Type: $OP_TARGET_TYPE"
    
    # Show flags if any are set
    local flags_shown=false
    
    if is_dry_run; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --dry-run (preview mode)"
    fi
    
    if is_verbose; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --verbose $(get_verbose_level)"
    fi
    
    if is_force; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --force"
    fi
    
    if is_backup; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --backup"
    fi
    
    if is_bounce; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --bounce"
    fi
    
    if is_reboot; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --reboot"
    fi
    
    if is_flush; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --flush"
    fi
    
    if is_no_volumes; then
        if [[ "$flags_shown" == false ]]; then
            info_message "  Flags:"
            flags_shown=true
        fi
        info_message "    --no-volumes"
    fi
    
    # Show volume-specific info if applicable (using KISS variable)
    if [[ "$OP_ACTION" == "volume" ]]; then
        info_message "  Volume: $(get_volume_name)"
        info_message "  Volume Action: $(get_volume_action)"
    fi
    
    info_message "ℹ️  ═══════════════════════════════════════════════════════════════════════════"
}

# Show operation header
# Usage: show_operation_header

# ─────────────────────────────────────────────────────────────────────────────
# Target Resolution Display - Simple DRY KISS Implementation
# ─────────────────────────────────────────────────────────────────────────────

# Show target resolution - uses simplified module arrays
# Usage: show_target_resolution "infrastructure" 
show_target_resolution() {
    local target_type="$1"
    
    if ! is_modules_loaded; then
        warn_message "Modules not loaded"
        return 1
    fi
    
    info_message "🎯 Target Resolution for '$target_type':"
    
    case "$target_type" in
        "infrastructure")
            info_message "  Target modules ($(safe_array_length "ALL_INFRASTRUCTURE_MODULES")): $(safe_array_string "ALL_INFRASTRUCTURE_MODULES")"
            ;;
        "instances")
            info_message "  Target modules ($(safe_array_length "ALL_INSTANCE_MODULES")): $(safe_array_string "ALL_INSTANCE_MODULES")"
            ;;
        "all")
            info_message "  Target modules ($(safe_array_length "ALL_MODULES")): $(safe_array_string "ALL_MODULES")"
            ;;
        *)
            # Single module - just display it
            info_message "  Target module: $OP_TARGET_TYPE"
            ;;
    esac
    
    # Show disabled modules if any exist
    if safe_array_has_elements "DISABLED_MODULES"; then
        info_message "  Disabled modules ($(safe_array_length "DISABLED_MODULES")): $(safe_array_string "DISABLED_MODULES")"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Operation Finalization Display
# ─────────────────────────────────────────────────────────────────────────────

# Finalize operation and cleanup
# Usage: finalize_operation
finalize_operation() {
    local action=$(get_action)
    
    debug_message "Finalizing operation: $action"
    
    # Finalize logging
    finalize_logging "success" "Operation completed successfully"
    
    # Show completion message
    success_message "Infrastructure management operation completed"
    
    # Reset terminal state to clear any stray escape sequences
    if [[ "$NO_COLOR" != true ]]; then
        printf '\033[0m'  # Reset all formatting
        printf '\033[?25h'  # Show cursor (in case it was hidden)
    fi
    
    debug_message "Operation finalization completed"
}

# ─────────────────────────────────────────────────────────────────────────────
# Error Handling Display
# ─────────────────────────────────────────────────────────────────────────────

# Global error handler
# Usage: handle_operation_error "error message"
handle_operation_error() {
    local error_message="$1"
    
    debug_message "Handling operation error: $error_message"
    
    # Finalize logging with error status
    if is_logging_active; then
        finalize_logging "error" "$error_message"
    fi
    
    # Show error message
    handle_error "$error_message"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Module Summary Display - Moved from modules.sh
# ─────────────────────────────────────────────────────────────────────────────

# Show module summary
# Usage: show_modules_summary
show_modules_summary() {
    if ! is_modules_loaded; then
        echo "Modules not loaded"
        return 1
    fi
    
    echo "Module Summary for $CURRENT_MODULES_ENV:"
    echo "  Infrastructure ($(safe_array_length "ALL_INFRASTRUCTURE_MODULES")): $(safe_array_string "ALL_INFRASTRUCTURE_MODULES")"
    echo "  Instances ($(safe_array_length "ALL_INSTANCE_MODULES")): $(safe_array_string "ALL_INSTANCE_MODULES")"
    echo "  Protected ($(safe_array_length "PROTECTED_MODULES")): $(safe_array_string "PROTECTED_MODULES")"
    echo "  Disabled ($(safe_array_length "DISABLED_MODULES")): $(safe_array_string "DISABLED_MODULES")"
    echo "  Total enabled: $(safe_array_length "ALL_MODULES")"
}

# ─────────────────────────────────────────────────────────────────────────────
# Status Display Functions - Moved from status.sh
# ─────────────────────────────────────────────────────────────────────────────

# Print a collection group header
# Usage: print_collection_header "collection name" "count"
print_collection_header() {
    local collection="$1"
    local count="${2:-}"
    
    local header_text="🌺 $collection"
    if [[ -n "$count" ]]; then
        header_text="$header_text ($count items) 🌺"
    else
        header_text="$header_text 🌺"
    fi
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${PURPLE}   $header_text${NC}"
        echo -e "${PURPLE}   ╰─────────────────────────────────────────────────────────────────────╯${NC}"
    else
        echo "   $header_text"
        echo "   ╰─────────────────────────────────────────────────────────────────────╯"
    fi
}

# Print a beautiful summary box
# Usage: print_summary_box
print_summary_box() {
    local total_width=80
    local box_top="🌈╭─────────────────────────────────────────────────────────────────────────╮🌈"
    local box_bottom="🌈╰─────────────────────────────────────────────────────────────────────────╯🌈"
    local box_side="🌈│"
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${CYAN}$box_top${NC}"
        echo -e "${CYAN}$box_side${WHITE}                            💖 Status Summary 💖                           ${CYAN}│${NC}"
        echo -e "${CYAN}$box_side                                                                     │${NC}"
        
        # Summary lines with pretty formatting
        printf "${CYAN}$box_side${WHITE} Total Resources: ${YELLOW}%-3d                                                ${CYAN}│${NC}\n" "$STATUS_TOTAL_RESOURCES"
        printf "${CYAN}$box_side${WHITE} 🌟 Online:        ${GREEN}%-3d ${WHITE}items                                         ${CYAN}│${NC}\n" "$STATUS_ONLINE_RESOURCES"
        printf "${CYAN}$box_side${WHITE} 💔 Offline:       ${RED}%-3d ${WHITE}items                                         ${CYAN}│${NC}\n" "$STATUS_OFFLINE_RESOURCES"
        printf "${CYAN}$box_side${WHITE} 🌸 Warning:       ${YELLOW}%-3d ${WHITE}items                                         ${CYAN}│${NC}\n" "$STATUS_WARNING_RESOURCES"
        printf "${CYAN}$box_side${WHITE} 🦄 Unknown:       ${RED}%-3d ${WHITE}items                                         ${CYAN}│${NC}\n" "$STATUS_UNKNOWN_RESOURCES"
        
        echo -e "${CYAN}$box_side                                                                     │${NC}"
        echo -e "${CYAN}$box_bottom${NC}"
    else
        echo "$box_top"
        echo "│                            💖 Status Summary 💖                           │"
        echo "│                                                                     │"
        
        printf "│ Total Resources: %-3d                                                │\n" "$STATUS_TOTAL_RESOURCES"
        printf "│ 🌟 Online:        %-3d items                                         │\n" "$STATUS_ONLINE_RESOURCES"
        printf "│ 💔 Offline:       %-3d items                                         │\n" "$STATUS_OFFLINE_RESOURCES"
        printf "│ 🌸 Warning:       %-3d items                                         │\n" "$STATUS_WARNING_RESOURCES"
        printf "│ 🦄 Unknown:       %-3d items                                         │\n" "$STATUS_UNKNOWN_RESOURCES"
        
        echo "│                                                                     │"
        echo "$box_bottom"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Verification Display Functions - Moved from verify.sh  
# ─────────────────────────────────────────────────────────────────────────────

# Generate comprehensive verification report
# Usage: generate_verification_report
generate_verification_report() {
    info_message "═══════════════════════════════════════════════════════════════════════════"
    info_message "✅ COMPREHENSIVE VERIFICATION REPORT"
    info_message "═══════════════════════════════════════════════════════════════════════════"
    info_message "Total Checks: $VERIFICATION_TOTAL_CHECKS"
    info_message "✅ Passed: $VERIFICATION_PASSED_CHECKS"
    info_message "❌ Failed: $VERIFICATION_FAILED_CHECKS"
    info_message "⚠️  Warnings: $VERIFICATION_WARNING_CHECKS"
    info_message "═══════════════════════════════════════════════════════════════════════════"
    
    if [[ $VERIFICATION_FAILED_CHECKS -eq 0 && $VERIFICATION_WARNING_CHECKS -eq 0 ]]; then
        success_message "🎉 All verifications passed! Infrastructure state is consistent."
        return 0
    elif [[ $VERIFICATION_FAILED_CHECKS -eq 0 ]]; then
        warn_message "⚠️  Verifications completed with warnings (see details above)"
        return 0
    else
        warn_message "❌ Verifications failed with $VERIFICATION_FAILED_CHECKS critical issues"
        return 1
    fi
}

# Show verification summary (alias for generate_verification_report for compatibility)
# Usage: show_verification_summary
show_verification_summary() {
    generate_verification_report
}

# ─────────────────────────────────────────────────────────────────────────────
# Status Display Functions - Additional Functions from status.sh
# ─────────────────────────────────────────────────────────────────────────────

# Print pretty header for status operations
# Usage: print_pretty_header "title"
print_pretty_header() {
    local title="$1"
    local border="🌈═══════════════════════════════════════════════════════════════════════════🌈"
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${CYAN}${border}${NC}"
        echo -e "${WHITE}🦄 ✨ ${title} ✨ 🦄${NC}"
        echo -e "${CYAN}${border}${NC}"
    else
        echo "$border"
        echo "🦄 ✨ ${title} ✨ 🦄"
        echo "$border"
    fi
}

# Create a beautiful section header
# Usage: print_section_header "section title"
print_section_header() {
    local title="$1"
    local decoration="🌸────────────────────────────────────────────────────────────────────────🌸"
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${PURPLE}${decoration}${NC}"
        echo -e "${WHITE}💖 ${title} 💖${NC}"
        echo -e "${PURPLE}${decoration}${NC}"
    else
        echo "$decoration"
        echo "💖 ${title} 💖"
        echo "$decoration"
    fi
}

# Print a pretty status line with proper formatting
# Usage: print_pretty_status_line "label" "status" "details"
print_pretty_status_line() {
    local label="$1"
    local status="$2"
    local details="${3:-}"
    
    local indicator=$(get_pretty_status_indicator "$status")
    local status_text=$(get_pretty_status_text "$status")
    
    # Choose colors per status (centralized color policy)
    local indicator_color="$WHITE"
    local status_color="$GREEN"
    case "$status" in
        $STATUS_ONLINE)
            indicator_color="$GREEN"
            status_color="$GREEN"
            ;;
        $STATUS_OFFLINE)
            indicator_color="$BRIGHT_RED"
            status_color="$BRIGHT_RED"
            ;;
        $STATUS_WARNING)
            indicator_color="$YELLOW"
            status_color="$YELLOW"
            ;;
        $STATUS_UNKNOWN)
            indicator_color="$RED"
            status_color="$RED"
            ;;
    esac
    
    # Format with columns: indicator (8), label (20), status (15), details (rest)
    if [[ "$NO_COLOR" != true ]]; then
        printf "${indicator_color}%-8s ${CYAN}%-20s ${status_color}%-15s ${YELLOW}%s${NC}\n" \
            "$indicator" "$label" "$status_text" "$details"
    else
        printf "%-8s %-20s %-15s %s\n" \
            "$indicator" "$label" "$status_text" "$details"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Diagnostics Tabular Display Helpers
# ─────────────────────────────────────────────────────────────────────────────

# EC2
print_diag_table_header_ec2() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-20s %-10s %-12s %-12s %-16s %-16s${NC}\n" \
            "InstanceID" "State" "Type" "AZ" "PublicIP" "PrivateIP"
        echo -e "${PURPLE}$(printf '%0.s-' {1..92})${NC}"
    else
        printf "%-20s %-10s %-12s %-12s %-16s %-16s\n" \
            "InstanceID" "State" "Type" "AZ" "PublicIP" "PrivateIP"
        printf '%0.s-' {1..92}; echo
    fi
}
print_diag_table_row_ec2() {
    local id="$1" state="$2" type="$3" az="$4" pub="$5" priv="$6"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-20s ${GREEN}%-10s ${WHITE}%-12s ${WHITE}%-12s ${WHITE}%-16s ${WHITE}%-16s${NC}\n" \
            "$id" "$state" "$type" "$az" "${pub:-none}" "$priv"
    else
        printf "%-20s %-10s %-12s %-12s %-16s %-16s\n" \
            "$id" "$state" "$type" "$az" "${pub:-none}" "$priv"
    fi
}

# Security Groups
print_diag_table_header_sg() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-18s %-20s %-15s %-8s %-8s %-8s${NC}\n" \
            "GroupID" "Name" "VPC" "Ingress" "Egress" "Inst"
        echo -e "${PURPLE}$(printf '%0.s-' {1..82})${NC}"
    else
        printf "%-18s %-20s %-15s %-8s %-8s %-8s\n" "GroupID" "Name" "VPC" "Ingress" "Egress" "Inst"
        printf '%0.s-' {1..82}; echo
    fi
}
print_diag_table_row_sg() {
    local id="$1" name="$2" vpc="$3" in="$4" eg="$5" inst="$6"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-18s ${WHITE}%-20s ${WHITE}%-15s ${GREEN}%-8s ${GREEN}%-8s ${WHITE}%-8s${NC}\n" \
            "$id" "$name" "$vpc" "$in" "$eg" "$inst"
    else
        printf "%-18s %-20s %-15s %-8s %-8s %-8s\n" "$id" "$name" "$vpc" "$in" "$eg" "$inst"
    fi
}

# VPCs
print_diag_table_header_vpc() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-18s %-10s %-18s %-7s %-12s %-8s %-10s %-4s${NC}\n" \
            "VpcID" "State" "CIDR" "Default" "DHCP" "Subnets" "RouteTbls" "IGW"
        echo -e "${PURPLE}$(printf '%0.s-' {1..92})${NC}"
    else
        printf "%-18s %-10s %-18s %-7s %-12s %-8s %-10s %-4s\n" \
            "VpcID" "State" "CIDR" "Default" "DHCP" "Subnets" "RouteTbls" "IGW"
        printf '%0.s-' {1..92}; echo
    fi
}
print_diag_table_row_vpc() {
    local id="$1" state="$2" cidr="$3" def="$4" dhcp="$5" subnets="$6" routes="$7" igw="$8"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-18s ${GREEN}%-10s ${WHITE}%-18s ${WHITE}%-7s ${WHITE}%-12s ${WHITE}%-8s ${WHITE}%-10s ${WHITE}%-4s${NC}\n" \
            "$id" "$state" "$cidr" "$def" "$dhcp" "$subnets" "$routes" "$igw"
    else
        printf "%-18s %-10s %-18s %-7s %-12s %-8s %-10s %-4s\n" \
            "$id" "$state" "$cidr" "$def" "$dhcp" "$subnets" "$routes" "$igw"
    fi
}

# VPC Route Tables
print_diag_table_header_vpc_routes() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-18s %-8s %-12s${NC}\n" "RouteTableID" "Routes" "Associations"
        echo -e "${PURPLE}$(printf '%0.s-' {1..44})${NC}"
    else
        printf "%-18s %-8s %-12s\n" "RouteTableID" "Routes" "Associations"
        printf '%0.s-' {1..44}; echo
    fi
}
print_diag_table_row_vpc_routes() {
    local id="$1" routes="$2" assoc="$3"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-18s ${WHITE}%-8s ${WHITE}%-12s${NC}\n" "$id" "$routes" "$assoc"
    else
        printf "%-18s %-8s %-12s\n" "$id" "$routes" "$assoc"
    fi
}

# Detailed VPC Route Entry Table
# Why: Show per-route details (destination, target, type, state, origin) for clarity when diagnosing routing
print_diag_table_header_vpc_route_entries() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-22s %-22s %-10s %-8s %-14s${NC}\n" \
            "Destination" "Target" "Type" "State" "Origin"
        echo -e "${PURPLE}$(printf '%0.s-' {1..80})${NC}"
    else
        printf "%-22s %-22s %-10s %-8s %-14s\n" \
            "Destination" "Target" "Type" "State" "Origin"
        printf '%0.s-' {1..80}; echo
    fi
}
print_diag_table_row_vpc_route_entry() {
    local destination="$1" target="$2" target_type="$3" state="$4" origin="$5"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-22s ${WHITE}%-22s ${WHITE}%-10s ${GREEN}%-8s ${WHITE}%-14s${NC}\n" \
            "$destination" "${target:-none}" "${target_type:-unknown}" "${state:-unknown}" "${origin:-unknown}"
    else
        printf "%-22s %-22s %-10s %-8s %-14s\n" \
            "$destination" "${target:-none}" "${target_type:-unknown}" "${state:-unknown}" "${origin:-unknown}"
    fi
}

# VPC Route Associations Table
# Why: Show which subnets (or main) are associated to each route table for quick diagnosis
print_diag_table_header_vpc_route_associations() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-20s %-6s %-22s %-18s${NC}\n" \
            "AssociationID" "Main" "SubnetID" "RouteTableID"
        echo -e "${PURPLE}$(printf '%0.s-' {1..72})${NC}"
    else
        printf "%-20s %-6s %-22s %-18s\n" \
            "AssociationID" "Main" "SubnetID" "RouteTableID"
        printf '%0.s-' {1..72}; echo
    fi
}
print_diag_table_row_vpc_route_association() {
    local assoc_id="$1" main_flag="$2" subnet_id="$3" rtb_id="$4"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-20s ${WHITE}%-6s ${WHITE}%-22s ${WHITE}%-18s${NC}\n" \
            "${assoc_id:-none}" "${main_flag:-false}" "${subnet_id:-none}" "${rtb_id}"
    else
        printf "%-20s %-6s %-22s %-18s\n" \
            "${assoc_id:-none}" "${main_flag:-false}" "${subnet_id:-none}" "${rtb_id}"
    fi
}

# EBS
print_diag_table_header_ebs() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-20s %-10s %-8s %-10s %-12s %-9s${NC}\n" \
            "VolumeID" "State" "SizeGB" "Type" "AZ" "Encrypted"
        echo -e "${PURPLE}$(printf '%0.s-' {1..75})${NC}"
    else
        printf "%-20s %-10s %-8s %-10s %-12s %-9s\n" "VolumeID" "State" "SizeGB" "Type" "AZ" "Encrypted"
        printf '%0.s-' {1..75}; echo
    fi
}
print_diag_table_row_ebs() {
    local id="$1" state="$2" size="$3" type="$4" az="$5" enc="$6"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-20s ${GREEN}%-10s ${WHITE}%-8s ${WHITE}%-10s ${WHITE}%-12s ${WHITE}%-9s${NC}\n" \
            "$id" "$state" "$size" "$type" "$az" "$enc"
    else
        printf "%-20s %-10s %-8s %-10s %-12s %-9s\n" "$id" "$state" "$size" "$type" "$az" "$enc"
    fi
}

# EIPs
print_diag_table_header_eips() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-16s %-20s %-20s %-18s %-18s %-8s${NC}\n" \
            "PublicIP" "AllocationID" "AssociationID" "InstanceID" "ENI" "Domain"
        echo -e "${PURPLE}$(printf '%0.s-' {1..102})${NC}"
    else
        printf "%-16s %-20s %-20s %-18s %-18s %-8s\n" "PublicIP" "AllocationID" "AssociationID" "InstanceID" "ENI" "Domain"
        printf '%0.s-' {1..102}; echo
    fi
}
print_diag_table_row_eips() {
    local ip="$1" alloc="$2" assoc="$3" inst="$4" eni="$5" dom="$6"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-16s ${WHITE}%-20s ${WHITE}%-20s ${WHITE}%-18s ${WHITE}%-18s ${WHITE}%-8s${NC}\n" \
            "$ip" "${alloc:-none}" "${assoc:-none}" "${inst:-none}" "${eni:-none}" "$dom"
    else
        printf "%-16s %-20s %-20s %-18s %-18s %-8s\n" \
            "$ip" "${alloc:-none}" "${assoc:-none}" "${inst:-none}" "${eni:-none}" "$dom"
    fi
}

# ECR
print_diag_table_header_ecr() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-24s %-8s %-14s %-11s${NC}\n" "Repository" "Images" "TagMutability" "ScanOnPush"
        echo -e "${PURPLE}$(printf '%0.s-' {1..62})${NC}"
    else
        printf "%-24s %-8s %-14s %-11s\n" "Repository" "Images" "TagMutability" "ScanOnPush"
        printf '%0.s-' {1..62}; echo
    fi
}
print_diag_table_row_ecr() {
    local repo="$1" images="$2" mut="$3" scan="$4"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-24s ${WHITE}%-8s ${WHITE}%-14s ${WHITE}%-11s${NC}\n" "$repo" "$images" "$mut" "$scan"
    else
        printf "%-24s %-8s %-14s %-11s\n" "$repo" "$images" "$mut" "$scan"
    fi
}

# Peering
print_diag_table_header_peering() {
    if [[ "$NO_COLOR" != true ]]; then
        printf "${WHITE}%-20s %-12s %-18s %-18s${NC}\n" "PeeringID" "Status" "RequesterVPC" "AccepterVPC"
        echo -e "${PURPLE}$(printf '%0.s-' {1..72})${NC}"
    else
        printf "%-20s %-12s %-18s %-18s\n" "PeeringID" "Status" "RequesterVPC" "AccepterVPC"
        printf '%0.s-' {1..72}; echo
    fi
}
print_diag_table_row_peering() {
    local id="$1" status="$2" req="$3" acc="$4"
    if [[ "$NO_COLOR" != true ]]; then
        printf "${CYAN}%-20s ${WHITE}%-12s ${WHITE}%-18s ${WHITE}%-18s${NC}\n" "$id" "$status" "$req" "$acc"
    else
        printf "%-20s %-12s %-18s %-18s\n" "$id" "$status" "$req" "$acc"
    fi
}

# Print colored info message
# Usage: print_colored_info "icon" "message" "color"
print_colored_info() {
    local icon="$1"
    local message="$2"
    local color="${3:-$WHITE}"
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${color}${icon} ${message}${NC}"
    else
        echo "${icon} ${message}"
    fi
}

# Print detailed section header
# Usage: print_detailed_section_header "title"
print_detailed_section_header() {
    local title="$1"
    
    if [[ "$NO_COLOR" != true ]]; then
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${WHITE} 📋 ${title}$(printf "%*s" $((66 - ${#title})) "")${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    else
        echo "┌─────────────────────────────────────────────────────────────────────────┐"
        echo "│ 📋 ${title}$(printf "%*s" $((66 - ${#title})) "")|"
        echo "└─────────────────────────────────────────────────────────────────────────┘"
    fi
}

# Generate comprehensive status summary
# Usage: generate_status_summary
generate_status_summary() {
    # Use the beautiful new summary format
    generate_pretty_status_summary
}

# Generate comprehensive status summary with beautiful formatting
# Usage: generate_pretty_status_summary
generate_pretty_status_summary() {
    echo ""
    print_summary_box
    echo ""
    
    # Determine overall health with cute messages
    if [[ $STATUS_OFFLINE_RESOURCES -eq 0 && $STATUS_WARNING_RESOURCES -eq 0 && $STATUS_UNKNOWN_RESOURCES -eq 0 ]]; then
        if [[ "$NO_COLOR" != true ]]; then
            echo -e "${GREEN}🎉 ✨ All infrastructure resources are sparkling and online! ✨ 🎉${NC}"
            echo -e "${GREEN}💖 Your infrastructure is healthy and happy! 💖${NC}"
            echo -e "${GREEN}🦄 🌈 Everything is magical! 🌈 🦄${NC}"
        else
            echo "🎉 ✨ All infrastructure resources are sparkling and online! ✨ 🎉"
            echo "💖 Your infrastructure is healthy and happy! 💖"
            echo "🦄 🌈 Everything is magical! 🌈 🦄"
        fi
        return 0
    elif [[ $STATUS_OFFLINE_RESOURCES -eq 0 ]]; then
        if [[ "$NO_COLOR" != true ]]; then
            echo -e "${YELLOW}⚠️  🌸 Infrastructure has some warnings but is mostly blooming! 🌸${NC}"
            echo -e "${YELLOW}💛 Some resources need attention but things are okay! 💛${NC}"
        else
            echo "⚠️  🌸 Infrastructure has some warnings but is mostly blooming! 🌸"
            echo "💛 Some resources need attention but things are okay! 💛"
        fi
        return 0
    else
        if [[ "$NO_COLOR" != true ]]; then
            echo -e "${RED}💔 Some infrastructure resources need love and attention! 💔${NC}"
            echo -e "${RED}🚨 Please check the offline resources above! 🚨${NC}"
        else
            echo "💔 Some infrastructure resources need love and attention! 💔"
            echo "🚨 Please check the offline resources above! 🚨"
        fi
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Module Export
# ─────────────────────────────────────────────────────────────────────────────

# Export functions for use by other modules
debug_message "Display module loaded successfully" 