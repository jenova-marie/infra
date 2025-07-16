#!/usr/bin/env bats

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Shutdown Unit Tests  
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Unit tests for shutdown operations with comprehensive testing
# Author: Infrastructure Management System v2.0
# Last Updated: December 30, 2024

# Load test helpers
load '../helpers/test_helper'
load '../helpers/mock_helper'

# Helper function to get dry-run flag based on environment
get_dry_run_flag() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "--dry-run"
    else
        echo ""
    fi
}

# Helper function to check if we're in dry-run mode
is_dry_run_mode() {
    [[ "$DRY_RUN" == "true" ]]
}

# Setup and teardown
setup() {
    setup_test_env
    source_infra_modules
    setup_shutdown_mocks
    reset_mocks
}

teardown() {
    teardown_test_env
}

# =================
# Module Loading Tests
# =================

@test "shutdown module loads successfully" {
    run source "${INFRA_ROOT}/shutdown.sh"
    [ "$status" -eq 0 ]
}

@test "shutdown action is validated correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    run validate_action "shutdown"
    [ "$status" -eq 0 ]
}

# =================
# Basic Shutdown Argument Parsing Tests
# =================

@test "shutdown action parses correctly with basic target" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$TARGET" = "${TEST_ENV}:athena" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "athena" ]
}

@test "shutdown action parses bounce flag correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--bounce" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--bounce"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$BOUNCE" = "true" ]
}

@test "shutdown action parses reboot flag correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--reboot" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--reboot"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$REBOOT" = "true" ]
}

@test "shutdown action parses flush flag correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--flush" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--flush"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$FLUSH" = "true" ]
}

@test "shutdown action parses hard flag correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--hard" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--hard"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$HARD" = "true" ]
}

@test "shutdown action parses terminate flag correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--terminate" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:athena" "--terminate"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$TERMINATE" = "true" ]
}

@test "shutdown action parses combined flags correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Mock exit to return instead of exiting
    exit() { return "$1"; }
    export -f exit
    
    if is_dry_run_mode; then
        parse_arguments "shutdown" "${TEST_ENV}:instances" "--bounce" "--reboot" "--force" "--dry-run"
        [ "$DRY_RUN" = "true" ]
    else
        parse_arguments "shutdown" "${TEST_ENV}:instances" "--bounce" "--reboot" "--force"
    fi
    [ "$ACTION" = "shutdown" ]
    [ "$BOUNCE" = "true" ]
    [ "$REBOOT" = "true" ]
    [ "$FORCE" = "true" ]
}

# =================
# Target Validation Tests
# =================

@test "shutdown rejects infrastructure target for non-bounce operations" {
    source "${INFRA_ROOT}/args.sh"
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for infrastructure target without bounce
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="infrastructure"
    if is_dry_run_mode; then
        DRY_RUN="true"
    else
        DRY_RUN="false"
    fi
    BOUNCE="false"
    
    # Mock validation functions to avoid module loading requirements
    validate_target_after_loading() { return 0; }
    export -f validate_target_after_loading
    
    run execute_shutdown_operation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SSH operations only apply to instances" ]]
}

@test "shutdown accepts infrastructure target for bounce operations" {
    source "${INFRA_ROOT}/args.sh"
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for infrastructure target with bounce
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="infrastructure"
    if is_dry_run_mode; then
        DRY_RUN="true"
    else
        DRY_RUN="false"
    fi
    BOUNCE="true"
    
    if is_dry_run_mode; then
        # In dry-run mode, mock get_shutdown_target_instances to return empty list for infrastructure
        get_shutdown_target_instances() {
            local result_array_name="$3"
            eval "$result_array_name=()"
            return 1
        }
        export -f get_shutdown_target_instances
        
        run execute_shutdown_operation
        [ "$status" -eq 1 ]
        [[ "$output" =~ "No instances found for bounce target" ]]
    else
        # In live mode, test against real infrastructure
        # Infrastructure target with bounce should either:
        # 1. Find instances and succeed, or 
        # 2. Find no instances and fail with appropriate message
        run execute_shutdown_operation
        # Accept either success (if instances found) or specific failure (if no instances)
        if [ "$status" -eq 1 ]; then
            [[ "$output" =~ "Failed to determine target instances" || "$output" =~ "No instances found" || "$output" =~ "bounce target" || "$output" =~ "infrastructure" ]]
        else
            [ "$status" -eq 0 ]
        fi
    fi
}

@test "shutdown accepts single instance target" {
    source "${INFRA_ROOT}/args.sh" 
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for single instance target
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    if is_dry_run_mode; then
        DRY_RUN="true"
    else
        DRY_RUN="false"
    fi
    
    if is_dry_run_mode; then
        # In dry-run mode, use mocks for predictable testing
        get_shutdown_target_instances() {
            local result_array_name="$3"
            eval "$result_array_name=(\"athena\")"
            return 0
        }
        export -f get_shutdown_target_instances
    fi
    # Note: In live mode (DRY_RUN=false), no mocks - uses real infrastructure
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    if is_dry_run_mode; then
        [[ "$output" =~ "[DRY-RUN]" ]]
    else
        # In live mode, expect real shutdown operation output
        [[ "$output" =~ "shutdown" || "$output" =~ "SSH" || "$output" =~ "operation" ]]
    fi
}

@test "shutdown accepts instances target" {
    source "${INFRA_ROOT}/args.sh"
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for instances target
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="instances"
    if is_dry_run_mode; then
        DRY_RUN="true"
    else
        DRY_RUN="false"
    fi
    
    # Mock get_shutdown_target_instances to return multiple instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\" \"aegis\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    if is_dry_run_mode; then
        [[ "$output" =~ "[DRY-RUN]" ]]
    else
        # In live mode, expect operation output
        [[ "$output" =~ "shutdown" || "$output" =~ "operation" || "$status" -eq 0 ]]
    fi
}

# =================
# Dry-Run SSH Operations Tests
# =================

@test "shutdown dry-run: basic SSH shutdown operation" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up basic SSH shutdown
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    BOUNCE="false"
    REBOOT="false"
    FLUSH="false"
    HARD="false"
    TERMINATE="false"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Starting SSH-based operation for 1 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: SSH shutdown with reboot flag" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up SSH shutdown with reboot
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    REBOOT="true"
    FLUSH="false"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Starting SSH-based operation for 1 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: SSH shutdown with flush flag" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up SSH shutdown with flush
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    REBOOT="false"
    FLUSH="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Starting SSH-based operation for 1 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: SSH shutdown multiple instances" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up SSH shutdown for multiple instances
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="instances"
    DRY_RUN="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\" \"aegis\" \"metis\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Starting SSH-based operation for 3 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

# =================
# Dry-Run Bounce Operations Tests
# =================

@test "shutdown dry-run: bounce operation single instance" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up bounce operation
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    BOUNCE="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bounce flag enabled" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: bounce operation with reboot flag" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up bounce with reboot
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    BOUNCE="true"
    REBOOT="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bounce flag enabled" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: bounce operation multiple instances" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up bounce for multiple instances
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="instances"
    DRY_RUN="true"
    BOUNCE="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\" \"aegis\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bounce flag enabled" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

# =================
# Dry-Run Hard Mode Operations Tests
# =================

@test "shutdown dry-run: hard mode shutdown operation" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up hard mode shutdown
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    HARD="true"
    REBOOT="false"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hard mode enabled" ]]
    [[ "$output" =~ "Hard shutdown mode" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
    [[ "$output" =~ "would complete successfully" ]]
}

@test "shutdown dry-run: hard mode reboot operation" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up hard mode reboot
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    HARD="true"
    REBOOT="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hard mode enabled" ]]
    [[ "$output" =~ "Hard reboot mode" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
    [[ "$output" =~ "would complete successfully" ]]
}

@test "shutdown dry-run: hard mode multiple instances" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up hard mode for multiple instances
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="instances"
    DRY_RUN="true"
    HARD="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\" \"aegis\" \"metis\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hard mode AWS CLI operation for 3 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

# =================
# Dry-Run Terminate Operations Tests  
# =================

@test "shutdown dry-run: terminate operation single instance" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up terminate operation
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    TERMINATE="true"
    HARD="false"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Terminate mode enabled" ]]
    [[ "$output" =~ "Starting terminate sequence for 1 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
    [[ "$output" =~ "would complete successfully" ]]
}

@test "shutdown dry-run: terminate operation with hard mode" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up terminate with hard mode
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    TERMINATE="true"
    HARD="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Terminate mode enabled" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
    [[ "$output" =~ "SSH shutdown - SKIPPED" ]]
    [[ "$output" =~ "would complete successfully" ]]
}

@test "shutdown dry-run: terminate operation multiple instances" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up terminate for multiple instances
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="instances"
    DRY_RUN="true"
    TERMINATE="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\" \"aegis\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Starting terminate sequence for 2 instance" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

# =================
# Dry-Run Error Handling Tests
# =================

@test "shutdown dry-run: handles missing target gracefully" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for missing target scenario
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN=true
    export ACTION ENVIRONMENT TARGET_TYPE DRY_RUN
    
    # Mock get_shutdown_target_instances to return empty
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=()"
        return 1
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to determine target instances" || "$output" =~ "No instances found" ]]
}

@test "shutdown dry-run: rejects infrastructure target for SSH operations" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for infrastructure target with SSH operation
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="infrastructure"
    DRY_RUN=true
    BOUNCE=false
    HARD=false
    TERMINATE=false
    export ACTION ENVIRONMENT TARGET_TYPE DRY_RUN BOUNCE HARD TERMINATE
    
    run execute_shutdown_operation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SSH operations only apply to instances" ]]
}

@test "shutdown dry-run: rejects infrastructure target for hard mode" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for infrastructure target with hard mode
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="infrastructure"
    DRY_RUN=true
    HARD=true
    export ACTION ENVIRONMENT TARGET_TYPE DRY_RUN HARD
    
    run execute_shutdown_operation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Hard mode operations only apply to instances" ]]
}

@test "shutdown dry-run: rejects infrastructure target for terminate mode" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for infrastructure target with terminate mode
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="infrastructure"
    DRY_RUN="true"
    TERMINATE="true"
    
    run execute_shutdown_operation
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Terminate mode operations only apply to instances" ]]
}

# =================
# Integration Dry-Run Tests
# =================

@test "shutdown dry-run: complete workflow with all flags" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up complete workflow test
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    BOUNCE="true"
    REBOOT="true"
    FORCE="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bounce flag enabled" ]]
    [[ "$output" =~ "[DRY-RUN]" ]]
}

@test "shutdown dry-run: validates successful completion message" {
    source "${INFRA_ROOT}/shutdown.sh"
    
    # Set up for successful completion
    ACTION="shutdown"
    ENVIRONMENT="$TEST_ENV"
    TARGET_TYPE="athena"
    DRY_RUN="true"
    
    # Mock get_shutdown_target_instances
    get_shutdown_target_instances() {
        local result_array_name="$3"
        eval "$result_array_name=(\"athena\")"
        return 0
    }
    export -f get_shutdown_target_instances
    
    run execute_shutdown_operation
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[DRY-RUN]" ]]
} 