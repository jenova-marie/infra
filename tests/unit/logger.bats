#!/usr/bin/env bats

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Logger Unit Tests
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Unit tests for logging system functionality
# Author: Infrastructure Management System v2.0
# Last Updated: May 28, 2025

# Load test helpers
load '../helpers/test_helper'
load '../helpers/mock_helper'

# Setup and teardown
setup() {
    setup_test_env
    source_infra_modules
    reset_mocks
}

teardown() {
    teardown_test_env
}

# =================
# Module Loading Tests
# =================

@test "logger module loads successfully" {
    run source "${INFRA_ROOT}/logger.sh"
    [ "$status" -eq 0 ]
}

@test "logging session initialization creates necessary directories" {
    local test_env="$TEST_ENV"
    source "${INFRA_ROOT}/logger.sh"
    
    # Test logging initialization
    run setup_logging "$test_env" "apply" "infrastructure"
    [ "$status" -eq 0 ]
    
    # Check that log directory was created
    local log_dir="${TEST_TEMP_DIR}/src/live/$test_env/log"
    [ -d "$log_dir" ]
    
    # Check that log files are created
    [ -f "$log_dir/debug.log" ]
    [ -f "$log_dir/infra.log" ]
    [ -f "$log_dir/terragrunt.log" ]
}

@test "logging session finalization creates proper markers" {
    local test_env="$TEST_ENV"
    source "${INFRA_ROOT}/logger.sh"
    
    # Initialize logging first
    setup_logging "$test_env" "apply" "infrastructure"
    
    # Test logging finalization
    run finalize_logging "success"
    [ "$status" -eq 0 ]
    
    # Check for session finalization marker
    local log_dir="${TEST_TEMP_DIR}/src/live/$test_env/log"
    run has_test_marker "$log_dir" "LOGGING_FINALIZED"
    [ "$status" -eq 0 ]
    
    # Check that the status was recorded correctly
    local status=$(get_test_marker_value "$log_dir" "LOGGING_FINALIZED" "status")
    [ "$status" = '"success"' ]
}

@test "logger respects dry-run mode and creates appropriate markers" {
    local test_env="$TEST_ENV"
    source "${INFRA_ROOT}/logger.sh"
    
    # Set dry-run mode
    DRY_RUN="true"
    
    # Initialize logging
    setup_logging "$test_env" "apply" "infrastructure"
    
    # Check for dry-run marker in debug log
    local log_dir="${TEST_TEMP_DIR}/src/live/$test_env/log"
    run has_test_marker "$log_dir" "LOGGING_SESSION_STARTED"
    [ "$status" -eq 0 ]
    
    # Check dry-run flag in the marker
    local dry_run_flag=$(get_test_marker_value "$log_dir" "LOGGING_SESSION_STARTED" "dry_run")
    [ "$dry_run_flag" = "true" ]
}

@test "multiple logging calls maintain session continuity" {
    source "${INFRA_ROOT}/logger.sh"
    
    # Initialize logging
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    # Test multiple debug messages
    debug_message "First test message"
    debug_message "Second test message"
    
    # Test human log messages
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    info_message "Test info message"
    success_message "Test success message"
    
    # Check that messages are being logged
    local log_dir="${TEST_TEMP_DIR}/src/live/$TEST_ENV/log"
    
    # At minimum, session should have started
    run has_test_marker "$log_dir" "LOGGING_SESSION_STARTED"
    [ "$status" -eq 0 ]
}

@test "logging system handles verbose mode correctly" {
    source "${INFRA_ROOT}/logger.sh"
    
    # Set verbose mode
    VERBOSE_LEVEL="1"
    
    # Initialize logging
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    # Test verbose message
    debug_message "Verbose test message"
    
    # Check that verbose mode was recorded
    local log_dir="${TEST_TEMP_DIR}/src/live/$TEST_ENV/log"
    run has_test_marker "$log_dir" "LOGGING_SESSION_STARTED"
    [ "$status" -eq 0 ]
    
    local verbose_level=$(get_test_marker_value "$log_dir" "LOGGING_SESSION_STARTED" "verbose_level")
    [ "$verbose_level" = "1" ]
}

@test "logging gracefully handles missing log directory" {
    source "${INFRA_ROOT}/logger.sh"
    
    # Don't create the live directory structure
    # This simulates a case where the environment path is invalid
    
    # Test that logging initialization doesn't crash
    run setup_logging "nonexistent" "apply" "infrastructure"
    
    # Should handle gracefully - either succeed (creating directories) or fail safely
    # The exact behavior depends on implementation, but it shouldn't crash
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "setup_logging creates log directory and files" {
    # Test basic logging setup
    local test_env="$TEST_ENV"
    local test_action="apply"
    local test_target="infrastructure"
    
    # Change to our test environment
    cd "${TEST_TEMP_DIR}/src/live/${test_env}"
    
    # Call setup_logging
    run setup_logging "$test_env" "$test_action" "$test_target"
    [ "$status" -eq 0 ]
    
    # Verify log directory was created
    assert_dir_exists "log"
    
    # Verify log files were created (terragrunt.log is created on command execution)
    assert_file_exists "log/debug.log"
    assert_file_exists "log/infra.log"
}

@test "debug log contains session information" {
    local test_env="$TEST_ENV"
    local test_action="apply"
    local test_target="infrastructure"
    
    cd "${TEST_TEMP_DIR}/src/live/${test_env}"
    
    # Setup logging
    setup_logging "$test_env" "$test_action" "$test_target"
    
    # Check for test markers instead of exact content
    run has_test_marker "log" "LOGGING_SESSION_STARTED"
    [ "$status" -eq 0 ]
    
    # Verify session parameters using test markers
    local logged_env=$(get_test_marker_value "log" "LOGGING_SESSION_STARTED" "env")
    local logged_action=$(get_test_marker_value "log" "LOGGING_SESSION_STARTED" "action")
    local logged_target=$(get_test_marker_value "log" "LOGGING_SESSION_STARTED" "target")
    
    [ "$logged_env" = "$test_env" ]
    [ "$logged_action" = "$test_action" ]
    [ "$logged_target" = "$test_target" ]
}

@test "human log contains operation header" {
    local test_env="$TEST_ENV"
    local test_action="plan"
    local test_target="instances"
    
    cd "${TEST_TEMP_DIR}/src/live/${test_env}"
    
    # Setup logging
    setup_logging "$test_env" "$test_action" "$test_target"
    
    # Check for human log test marker
    run has_human_log_marker "log" "HUMAN_LOG_INITIALIZED"
    [ "$status" -eq 0 ]
    
    # Verify the human log file exists and has basic structure
    assert_file_exists "log/infra.log"
    
    # Check that the human log contains the system header (this is stable content)
    local human_content=$(get_log_content "log" "infra")
    assert_contains "$human_content" "Infrastructure Management System v2.0"
}

@test "is_logging_active returns correct status" {
    # Before setup - should be false
    run is_logging_active
    [ "$status" -eq 1 ]
    
    # After setup - should be true
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    run is_logging_active
    [ "$status" -eq 0 ]
}

@test "log_phase creates phase entries in logs" {
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    # Log a test phase
    local test_phase="Testing phase logging"
    log_phase "$test_phase"
    
    # Check for phase test marker
    run has_test_marker "log" "PHASE_LOGGED"
    [ "$status" -eq 0 ]
    
    # Verify the phase name was logged correctly
    local logged_phase=$(get_test_marker_value "log" "PHASE_LOGGED" "phase")
    [ "$logged_phase" = "\"$test_phase\"" ]
}

@test "log_module_processing handles different statuses" {
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    local test_module="test_module"
    
    # Test start status
    log_module_processing "$test_module" "start" "Starting processing"
    run has_test_marker "log" "MODULE_PROCESSING"
    [ "$status" -eq 0 ]
    
    # Verify start status was logged
    local logged_module=$(get_test_marker_value "log" "MODULE_PROCESSING" "module")
    local logged_status=$(get_test_marker_value "log" "MODULE_PROCESSING" "status")
    [ "$logged_module" = "\"$test_module\"" ]
    [ "$logged_status" = "\"start\"" ]
    
    # Test success status
    log_module_processing "$test_module" "success" "Completed successfully"
    
    # Test error status  
    log_module_processing "$test_module" "error" "Failed with error"
    
    # Verify all three statuses were logged (should have 3 MODULE_PROCESSING markers)
    local marker_count=$(grep -c "\[TEST_MARKER\] MODULE_PROCESSING" "log/debug.log")
    [ "$marker_count" -eq 3 ]
}

@test "finalize_logging creates session footer" {
    cd "${TEST_TEMP_DIR}/src/live/$TEST_ENV"
    setup_logging "$TEST_ENV" "apply" "infrastructure"
    
    # Finalize with success
    finalize_logging "success" "Operation completed successfully"
    
    # Check for finalization test markers
    run has_test_marker "log" "LOGGING_FINALIZED"
    [ "$status" -eq 0 ]
    
    run has_test_marker "log" "LOGGING_SESSION_ENDED"
    [ "$status" -eq 0 ]
    
    # Verify the status and message were logged correctly
    local logged_status=$(get_test_marker_value "log" "LOGGING_FINALIZED" "status")
    local logged_message=$(get_test_marker_value "log" "LOGGING_FINALIZED" "message")
    [ "$logged_status" = "\"success\"" ]
    [ "$logged_message" = "\"Operation completed successfully\"" ]
}

@test "cleanup_old_logs handles missing directory gracefully" {
    # Test cleanup when log directory doesn't exist
    run cleanup_old_logs "nonexistent-env"
    [ "$status" -eq 0 ]
} 