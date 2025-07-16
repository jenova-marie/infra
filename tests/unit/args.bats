#!/usr/bin/env bats

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Args Unit Tests
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Unit tests for command-line argument parsing and validation
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2025

# Load test helpers
load '../helpers/test_helper'
load '../helpers/mock_helper'

# Setup and teardown
setup() {
    setup_test_env
    source_infra_modules
    setup_args_mocks
    reset_mocks
}

teardown() {
    teardown_test_env
}

# =================
# Module Loading Tests
# =================

@test "args module loads successfully" {
    run source "${INFRA_ROOT}/args.sh"
    [ "$status" -eq 0 ]
}

@test "global variables are initialized correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    # Check that all global variables are initialized
    [ "$ACTION" = "" ]
    [ "$TARGET" = "" ]
    [ "$ENVIRONMENT" = "" ]
    [ "$TARGET_TYPE" = "" ]
    [ "$DRY_RUN" = "false" ]
    [ "$VERBOSE_LEVEL" = "0" ]
    [ "$NO_COLOR" = "false" ]
    [ "$FORCE" = "false" ]
    [ "$BACKUP" = "false" ]
    [ "$REFRESH" = "false" ]
    [ "$VOLUME_NAME" = "" ]
    [ "$VOLUME_ACTION" = "" ]
}

# =================
# Basic Argument Parsing Tests
# =================

@test "parse_arguments handles apply action correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$ACTION" = "apply" ]
    [ "$TARGET" = "${TEST_ENV}:infrastructure" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "infrastructure" ]
}

@test "parse_arguments handles destroy action correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "destroy" "${TEST_ENV}:athena" "--test-mode"
    [ "$ACTION" = "destroy" ]
    [ "$TARGET" = "${TEST_ENV}:athena" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "athena" ]
}

@test "parse_arguments handles plan action correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "plan" "${TEST_ENV}:all" "--test-mode"
    [ "$ACTION" = "plan" ]
    [ "$TARGET" = "${TEST_ENV}:all" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "all" ]
}

@test "parse_arguments requires action argument" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments
    [ "$status" -eq 1 ]
}

@test "parse_arguments validates action" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "invalid_action" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unsupported action" ]]
}

@test "parse_arguments handles verbose flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--verbose" "1" "--test-mode"
    [ "$VERBOSE_LEVEL" = "1" ]
}

@test "parse_arguments handles verbose flag without level" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--verbose" "--test-mode"
    [ "$VERBOSE_LEVEL" = "1" ]
}

@test "parse_arguments handles dry-run flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--dry-run" "--test-mode"
    [ "$DRY_RUN" = "true" ]
}

@test "parse_arguments handles force flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--force" "--test-mode"
    [ "$FORCE" = "true" ]
}

@test "parse_arguments handles backup flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--backup" "--test-mode"
    [ "$BACKUP" = "true" ]
}

@test "parse_arguments handles no-color flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--no-color" "--test-mode"
    [ "$NO_COLOR" = "true" ]
}

@test "parse_arguments rejects unknown flags" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "apply" "${TEST_ENV}:infrastructure" "--unknown-flag" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown flag" ]]
}

# =================
# Flag Parsing Tests
# =================

@test "dry_run flag is properly parsed and stored" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--dry-run" "--test-mode"
    [ "$DRY_RUN" = "true" ]
    
    run is_dry_run
    [ "$status" -eq 0 ]
}

@test "verbose flag is properly parsed and stored" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--verbose" "1" "--test-mode"
    [ "$VERBOSE_LEVEL" = "1" ]
    
    run is_verbose
    [ "$status" -eq 0 ]
}

@test "no_color flag is properly parsed and stored" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--no-color" "--test-mode"
    [ "$NO_COLOR" = "true" ]
}

@test "force flag is supported for AWS CLI operations only" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "volume" "${TEST_ENV}:athena" "my-volume" "--detach" "--force" "--test-mode"
    [ "$FORCE" = "true" ]
    
    run is_force
    [ "$status" -eq 0 ]
    
    parse_arguments "reboot" "${TEST_ENV}:athena" "--force" "--test-mode"
    [ "$FORCE" = "true" ]
    
    run is_force
    [ "$status" -eq 0 ]
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--force" "--test-mode"
    [ "$FORCE" = "true" ]
    
    run is_force
    [ "$status" -eq 0 ]
}

@test "backup flag is properly parsed and stored" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--backup" "--test-mode"
    [ "$BACKUP" = "true" ]
    
    run is_backup
    [ "$status" -eq 0 ]
}

@test "backup flag defaults to false" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$BACKUP" = "false" ]
    
    run is_backup
    [ "$status" -eq 1 ]
}

@test "refresh flag is properly parsed and stored for output action" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "output" "${TEST_ENV}:infrastructure" "--refresh" "--test-mode"
    [ "$REFRESH" = "true" ]
    
    run is_refresh
    [ "$status" -eq 0 ]
}

@test "refresh flag defaults to false" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "output" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$REFRESH" = "false" ]
    
    run is_refresh
    [ "$status" -eq 1 ]
}

@test "refresh flag is rejected for non-output operations" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--refresh" "--test-mode"
    [ "$REFRESH" = "true" ]
    
    run is_refresh
    [ "$status" -eq 0 ]
}

@test "multiple flags can be combined" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--dry-run" "--verbose" "1" "--backup" "--test-mode"
    [ "$DRY_RUN" = "true" ]
    [ "$VERBOSE_LEVEL" = "1" ]
    [ "$BACKUP" = "true" ]
}

# =================
# Volume Operation Argument Tests
# =================

@test "volume operation parsing handles attach correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "volume" "${TEST_ENV}:athena" "my-volume" "--attach" "--test-mode"
    [ "$ACTION" = "volume" ]
    [ "$TARGET" = "${TEST_ENV}:athena" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "athena" ]
    [ "$VOLUME_NAME" = "my-volume" ]
    [ "$VOLUME_ACTION" = "attach" ]
}

@test "volume operation parsing handles detach correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "volume" "test:aegis" "data-volume" "--detach" "--test-mode"
    [ "$ACTION" = "volume" ]
    [ "$TARGET" = "test:aegis" ]
    [ "$ENVIRONMENT" = "test" ]
    [ "$TARGET_TYPE" = "aegis" ]
    [ "$VOLUME_NAME" = "data-volume" ]
    [ "$VOLUME_ACTION" = "detach" ]
}

@test "volume operation requires volume name" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "volume" "${TEST_ENV}:athena" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Volume operation requires" ]]
}

@test "volume operation requires action flag" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "volume" "${TEST_ENV}:athena" "my-volume"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Volume operation requires" ]]
}

@test "volume operation rejects invalid action" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "volume" "${TEST_ENV}:athena" "my-volume" "--invalid" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid volume action" ]]
}

@test "volume operation handles force flag" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "volume" "${TEST_ENV}:athena" "my-volume" "--detach" "--force" "--test-mode"
    [ "$ACTION" = "volume" ]
    [ "$VOLUME_ACTION" = "detach" ]
    [ "$FORCE" = "true" ]
}

# =================
# Reboot Operation Argument Tests
# =================

@test "reboot operation parsing works correctly" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "reboot" "${TEST_ENV}:athena" "--test-mode"
    [ "$ACTION" = "reboot" ]
    [ "$TARGET" = "${TEST_ENV}:athena" ]
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "athena" ]
}

@test "reboot operation requires target" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "reboot"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Target required for reboot operation" ]]
}

# =================
# Target Parsing Tests
# =================

@test "target parsing handles environment:target format" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "infrastructure" ]
}

@test "target parsing handles single environment format" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}" "--test-mode"
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
    [ "$TARGET_TYPE" = "all" ]
}

@test "target parsing rejects invalid format" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "apply" ":invalid" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid target format" ]]
}

# =================
# Accessor Function Tests
# =================

@test "is_dry_run returns correct status" {
    source "${INFRA_ROOT}/args.sh"
    
    DRY_RUN=false
    run is_dry_run
    [ "$status" -eq 1 ]
    
    DRY_RUN=true
    run is_dry_run
    [ "$status" -eq 0 ]
}

@test "is_verbose returns correct status" {
    source "${INFRA_ROOT}/args.sh"
    
    VERBOSE_LEVEL=0
    run is_verbose
    [ "$status" -eq 1 ]
    
    VERBOSE_LEVEL=1
    run is_verbose
    [ "$status" -eq 0 ]
}

@test "is_force returns correct status" {
    source "${INFRA_ROOT}/args.sh"
    
    FORCE=false
    run is_force
    [ "$status" -eq 1 ]
    
    FORCE=true
    run is_force
    [ "$status" -eq 0 ]
}

@test "is_backup returns correct status" {
    source "${INFRA_ROOT}/args.sh"
    
    BACKUP=false
    run is_backup
    [ "$status" -eq 1 ]
    
    BACKUP=true
    run is_backup
    [ "$status" -eq 0 ]
}

@test "is_refresh returns correct status" {
    source "${INFRA_ROOT}/args.sh"
    
    REFRESH=false
    run is_refresh
    [ "$status" -eq 1 ]
    
    REFRESH=true
    run is_refresh
    [ "$status" -eq 0 ]
}

# =================
# Environment Validation Tests  
# =================

@test "environment validation accepts valid environments" {
    source "${INFRA_ROOT}/args.sh"
    
    parse_arguments "apply" "${TEST_ENV}:infrastructure" "--test-mode"
    [ "$ENVIRONMENT" = "$TEST_ENV" ]
}

@test "environment validation rejects invalid environments" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "apply" "invalid:infrastructure" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SECURITY: Tests can only run against" ]]
} 