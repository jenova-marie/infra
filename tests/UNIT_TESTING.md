# Unit Testing Guide

Comprehensive guide for writing unit tests for the Infrastructure Management System v2.0.

## 🎯 Unit Testing Philosophy

Unit tests in this system focus on testing individual functions and modules in complete isolation. They are:

- **✅ Always Safe**: Never create real AWS resources or modify real files
- **⚡ Fast**: Execute in seconds, suitable for continuous development
- **🔒 Isolated**: Each test is independent with no side effects
- **📋 Comprehensive**: Cover all code paths and edge cases
- **💰 Free**: Zero AWS costs or external dependencies

## 🧪 Test Structure

### File Organization
```
test/unit/
├── logger.bats           # Logger module tests (existing)
├── args.bats             # Argument parsing tests (NEW)
├── volume.bats           # Volume management tests (NEW)
├── backup.bats           # Backup system tests (NEW)
├── shared.bats           # Shared utilities tests (NEW)
├── modules.bats          # Module discovery tests (NEW)
├── operations.bats       # Operations module tests (NEW)
├── environment.bats      # Environment setup tests (NEW)
├── display.bats          # Display module tests (NEW)
└── cache.bats            # Cache management tests (NEW)
```

### Test File Template
```bash
#!/usr/bin/env bats

# Load test helpers
load '../helpers/test_helper'
load '../helpers/mock_helper'

# Setup and teardown
setup() {
    setup_test_environment
    setup_module_mocks
}

teardown() {
    cleanup_test_environment
}

# Test cases
@test "function_name handles valid input correctly" {
    # Arrange
    local input="valid_value"
    
    # Act
    run function_name "$input"
    
    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected_result" ]]
}
```

## 🔧 Testing Patterns

### 0. Test Mode Integration
All unit tests automatically benefit from test mode infrastructure for proper error handling:

```bash
@test "error conditions return proper exit codes" {
    source src/infra/args.sh
    
    # Test mode is automatically enabled in test environment
    # Errors return instead of exiting, allowing verification
    run parse_arguments "apply" "invalid:infrastructure" "--test-mode"
    
    # Can verify error exit code without test process termination
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SECURITY: Tests can only run against" ]]
}

@test "environment validation with test mode" {
    source src/infra/shared.sh
    
    # Test mode restricts operations to 'test' environment only
    run validate_environment "prod" "--test-mode"
    
    # Should fail with security error
    [ "$status" -eq 1 ]
    [[ "$output" =~ "test.*environment" ]]
    
    # Valid test environment should succeed
    run validate_environment "test" "--test-mode"
    [ "$status" -eq 0 ]
}
```

**Test Mode Benefits:**
- **Error Testing**: Functions return error codes instead of calling `exit()`
- **Environment Security**: Operations restricted to `test` environment only
- **Process Continuation**: Test processes continue after errors for comprehensive testing
- **Validation Preservation**: All normal validation logic remains active

### 1. Function Testing
Test individual functions with various inputs and conditions:

```bash
@test "parse_arguments validates required parameters" {
    source src/infra/args.sh
    
    # Test valid arguments
    run parse_arguments "apply" "dev:infrastructure"
    [ "$status" -eq 0 ]
    
    # Test missing arguments
    run parse_arguments "apply"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Target required" ]]
}
```

### 2. State Testing
Test functions that modify global state or variables:

```bash
@test "setup_global_environment sets correct variables" {
    source src/infra/environment.sh
    
    # Mock dependencies
    mock_function "get_environment"
    mock_return_value "test"
    
    # Execute
    run setup_global_environment
    
    # Verify state
    [ "$status" -eq 0 ]
    [ "$ENVIRONMENT" = "test" ]
}
```

### 3. Error Handling Testing
Ensure proper error handling and exit codes:

```bash
@test "validate_environment fails with invalid environment" {
    source src/infra/shared.sh
    
    # Test with non-existent environment
    run validate_environment "nonexistent"
    
    # Should fail with proper exit code
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Environment 'nonexistent' not found" ]]
}
```

### 4. Flag and Option Testing
Test command-line flag parsing and validation:

```bash
@test "backup flag is properly parsed and stored" {
    source src/infra/args.sh
    
    # Test backup flag parsing
    run parse_arguments "volume" "test:athena" "vol-123" "--attach" "--backup"
    
    # Verify backup flag is set
    [ "$status" -eq 0 ]
    run is_backup
    [ "$status" -eq 0 ]  # is_backup should return true
}
```

## 🎭 Mocking Strategies

### File System Mocking
Mock file operations to avoid touching real files:

```bash
# Mock file existence
mock_file_exists() {
    local file="$1"
    case "$file" in
        "/path/to/existing/file")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

@test "function handles missing configuration file" {
    # Override file check
    eval 'function [[ { mock_file_exists "$@"; }'
    
    source src/infra/modules.sh
    
    run load_modules_config "nonexistent.yml"
    [ "$status" -eq 1 ]
}
```

### Command Mocking
Mock external commands like AWS CLI or terragrunt:

```bash
# Mock AWS CLI commands
aws() {
    case "$1 $2" in
        "sts get-caller-identity")
            echo '{"Account": "123456789012"}'
            return 0
            ;;
        "ec2 describe-instances")
            echo '{"Reservations": []}'
            return 0
            ;;
        *)
            echo "Mocked AWS CLI: $*" >&2
            return 1
            ;;
    esac
}

@test "aws_validation succeeds with valid credentials" {
    source src/infra/aws.sh
    
    run validate_aws_cli
    [ "$status" -eq 0 ]
    [[ "$output" =~ "AWS CLI validation successful" ]]
}
```

### Environment Variable Mocking
Test different environment configurations:

```bash
@test "backup management uses environment-specific paths" {
    # Set test environment variables
    export ENVIRONMENT="test"
    export PROJECT_ROOT="/mock/project"
    
    source src/infra/volume.sh
    
    run manage_backup_files "/mock/volumes.yml"
    
    # Verify correct path usage
    [ "$status" -eq 0 ]
    # Assertions about path handling
}
```

## 📋 Test Categories

### Module-Specific Tests

#### Args Module Tests (`args.bats`)
```bash
@test "volume operation arguments are parsed correctly"
@test "backup flag is recognized and stored"
@test "invalid action returns proper error"
@test "help flag displays usage information"
@test "flag combinations are validated correctly"
```

#### Volume Module Tests (`volume.bats`)
```bash
@test "volume name resolution works with both names and IDs"
@test "backup management creates files when flag enabled"
@test "backup cleanup keeps only 3 most recent files"
@test "volume state checking detects attached volumes"
@test "device name allocation avoids conflicts"
```

#### Backup System Tests (`backup.bats`)
```bash
@test "backup flag defaults to false"
@test "backup creation only occurs when flag set"
@test "backup cleanup removes oldest files"
@test "backup restoration works on failure"
@test "backup files have correct timestamp format"
```

#### Logger Module Tests (`logger.bats`)
```bash
@test "debug messages are logged when verbose enabled"
@test "log files are created in correct locations"
@test "session markers prevent log pollution"
@test "color codes are stripped from log files"
@test "log cleanup removes old files"
```

### Cross-Module Integration Tests
Test how modules work together without creating real resources:

```bash
@test "volume operation with backup flag creates proper file structure" {
    # Mock all file operations
    setup_file_mocks
    
    # Test volume operation with backup
    source src/infra/args.sh
    source src/infra/volume.sh
    
    # Parse arguments with backup flag
    run parse_arguments "volume" "test:athena" "vol-123" "--attach" "--backup"
    [ "$status" -eq 0 ]
    
    # Verify backup flag is available to volume module
    run is_backup
    [ "$status" -eq 0 ]
    
    # Test backup file creation (mocked)
    run manage_backup_files "/mock/volumes.yml"
    [ "$status" -eq 0 ]
    # Verify backup creation was attempted
}
```

## 🎯 Coverage Goals

### Function Coverage
Ensure every public function has at least:
- ✅ **Happy path test**: Normal successful execution
- ⚠️ **Error path test**: Expected failure scenarios
- 🔄 **Edge case test**: Boundary conditions and unusual inputs
- 🚫 **Invalid input test**: Malformed or missing parameters

### Code Path Coverage
- **Conditional branches**: Test both true and false conditions
- **Loop iterations**: Test empty, single, and multiple iterations
- **Error handling**: Test all error exit points
- **Flag combinations**: Test various command-line flag combinations

### State Coverage
- **Initial state**: Test functions with clean initial state
- **Modified state**: Test functions with pre-existing state
- **Invalid state**: Test functions with corrupted or unexpected state

## 🔍 Testing Best Practices

### Test Naming
```bash
# Good: Descriptive and specific
@test "parse_volume_operation_args rejects missing volume name"
@test "backup_cleanup_keeps_three_most_recent_files"
@test "aws_region_extraction_handles_missing_root_hcl"

# Bad: Vague or unclear
@test "parsing works"
@test "backup test"
@test "region stuff"
```

### Test Organization
```bash
# Group related tests
# =================
# Argument Parsing Tests
# =================

@test "parse_arguments handles apply action correctly"
@test "parse_arguments handles volume action correctly"
@test "parse_arguments handles reboot action correctly"

# =================
# Flag Validation Tests
# =================

@test "backup flag is properly validated"
@test "dry_run flag is properly validated"
@test "verbose flag accepts valid levels"
```

### Assertion Patterns
```bash
# Check exit codes
[ "$status" -eq 0 ]          # Success
[ "$status" -eq 1 ]          # General error
[ "$status" -eq 2 ]          # Specific error condition

# Check output content
[[ "$output" =~ "expected text" ]]           # Contains text
[[ "$output" == "exact match" ]]             # Exact match
[[ "$lines[0]" == "first line" ]]           # Specific line

# Check variable state
[ -n "$VARIABLE" ]                           # Variable is set
[ "$VARIABLE" = "expected_value" ]           # Variable has value
[ ${#array[@]} -eq 3 ]                      # Array has specific length
```

### Mock Verification
```bash
@test "function calls expected external commands" {
    # Track mock calls
    declare -a mock_calls=()
    
    # Override external function
    external_function() {
        mock_calls+=("$*")
        return 0
    }
    
    # Execute test
    run function_under_test
    
    # Verify calls
    [ "$status" -eq 0 ]
    [ ${#mock_calls[@]} -eq 2 ]
    [[ "${mock_calls[0]}" == "expected first call" ]]
    [[ "${mock_calls[1]}" == "expected second call" ]]
}
```

## 🚀 Running Unit Tests

### Basic Execution
```bash
# Run all unit tests
cd test
./run_tests.sh --unit

# Run specific module tests
./run_tests.sh --unit args
./run_tests.sh --unit volume
./run_tests.sh --unit backup

# Run with verbose output
./run_tests.sh --unit --verbose
```

### Development Workflow
```bash
# Fast development cycle
while true; do
    # Edit code
    vim src/infra/args.sh
    
    # Test immediately
    ./run_tests.sh --unit args
    
    # Continue if tests pass
    [ $? -eq 0 ] && break
done
```

### Debugging Failed Tests
```bash
# Run single test with maximum verbosity
./run_tests.sh --unit --verbose args

# Check specific test function
bats test/unit/args.bats -f "parse_arguments"

# Add debug output to tests
@test "debug example" {
    echo "Debug: Testing with input=$input" >&3
    run function_under_test "$input"
    echo "Debug: Got status=$status output=$output" >&3
    [ "$status" -eq 0 ]
}
```

## 📚 Common Test Utilities

### Test Helper Functions
```bash
# Setup clean test environment
setup_test_environment() {
    export TEST_TMPDIR="$(mktemp -d)"
    export PROJECT_ROOT="/mock/project"
    cd "$TEST_TMPDIR"
}

# Cleanup after tests
cleanup_test_environment() {
    cd /
    rm -rf "$TEST_TMPDIR"
}

# Create mock files
create_mock_file() {
    local file="$1"
    local content="$2"
    mkdir -p "$(dirname "$file")"
    echo "$content" > "$file"
}

# Assert file contains content
assert_file_contains() {
    local file="$1"
    local expected="$2"
    [ -f "$file" ]
    grep -q "$expected" "$file"
}
```

---

**Last Updated**: May 28, 2025 6:30 PM CST

This guide provides the foundation for comprehensive unit testing of the Infrastructure Management System. Unit tests should be the primary testing method during development, with integration tests reserved for final validation. 

# Unit Testing Documentation

## Overview
This document covers the unit testing framework for the Infrastructure Management System v2.0. Unit tests focus on testing individual functions and modules in isolation using mocks and test doubles.

## Test Structure

### Test Files
- `args.bats` - Command-line argument parsing and validation
- `backup.bats` - Backup functionality testing  
- `logger.bats` - Logging system testing
- `volume.bats` - EBS volume management testing
- `shutdown.bats` - Shutdown operations testing

### Test Organization
Each test file follows this structure:
```bash
# Module Loading Tests - Verify modules load correctly
# Basic Functionality Tests - Core feature testing
# Error Handling Tests - Edge cases and validation
# Integration Tests - Cross-module interactions
```

## Shutdown Tests (`shutdown.bats`)

### Coverage
The shutdown tests provide comprehensive coverage of all shutdown operation modes:

#### Module Loading Tests
- ✅ `shutdown module loads successfully`
- ✅ `shutdown action is validated correctly`

#### Argument Parsing Tests  
- ✅ `shutdown action parses correctly with basic target`
- ✅ `shutdown action parses bounce flag correctly`
- ✅ `shutdown action parses reboot flag correctly`
- ✅ `shutdown action parses flush flag correctly`
- ✅ `shutdown action parses hard flag correctly`
- ✅ `shutdown action parses terminate flag correctly`
- ✅ `shutdown action parses combined flags correctly`

#### Target Validation Tests
- ✅ `shutdown rejects infrastructure target for non-bounce operations`
- ✅ `shutdown accepts infrastructure target for bounce operations`
- ✅ `shutdown accepts single instance target`
- ✅ `shutdown accepts instances target`

#### Dry-Run SSH Operations Tests
- ✅ `shutdown dry-run: basic SSH shutdown operation`
- ✅ `shutdown dry-run: SSH shutdown with reboot flag`
- ✅ `shutdown dry-run: SSH shutdown with flush flag`
- ✅ `shutdown dry-run: SSH shutdown multiple instances`

#### Dry-Run Bounce Operations Tests
- ✅ `shutdown dry-run: bounce operation single instance`
- ✅ `shutdown dry-run: bounce operation with reboot flag`
- ✅ `shutdown dry-run: bounce operation multiple instances`

#### Dry-Run Hard Mode Operations Tests
- ✅ `shutdown dry-run: hard mode shutdown operation`
- ✅ `shutdown dry-run: hard mode reboot operation`
- ✅ `shutdown dry-run: hard mode multiple instances`

#### Dry-Run Terminate Operations Tests
- ✅ `shutdown dry-run: terminate operation single instance`
- ✅ `shutdown dry-run: terminate operation with hard mode`
- ✅ `shutdown dry-run: terminate operation multiple instances`

#### Error Handling Tests
- ✅ `shutdown dry-run: handles missing target gracefully`
- ✅ `shutdown dry-run: rejects infrastructure target for SSH operations`
- ✅ `shutdown dry-run: rejects infrastructure target for hard mode`
- ✅ `shutdown dry-run: rejects infrastructure target for terminate mode`

#### Integration Tests
- ✅ `shutdown dry-run: complete workflow with all flags`
- ✅ `shutdown dry-run: validates successful completion message`

### Operation Modes Tested
1. **SSH Mode**: Basic SSH-based shutdown operations
2. **Bounce Mode**: SSH shutdown → destroy → apply → output sequence  
3. **Hard Mode**: AWS CLI-only operations (no SSH)
4. **Terminate Mode**: SSH shutdown → AWS CLI terminate
5. **Combined Modes**: Multiple flags working together

### Flags Tested
- `--bounce` - Infrastructure recreation sequence
- `--reboot` - SSH shutdown + AWS restart
- `--flush` - SSH-based cleanup operations
- `--hard` - AWS CLI only (no SSH scripts)
- `--terminate` - SSH shutdown then AWS CLI terminate
- `--force` - Force operations
- `--dry-run` - Show what would be executed

### Safety Features
- All tests run in dry-run mode only
- No real AWS resources are affected
- Complete mock system for all external dependencies
- Comprehensive error handling validation

## Running Unit Tests