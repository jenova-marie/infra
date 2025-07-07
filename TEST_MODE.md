# TEST_MODE.md - Test Mode Infrastructure Documentation

## Overview

The Infrastructure Management System v2.0 includes a comprehensive test mode infrastructure that enables safe, controlled testing of all operations without affecting live environments or causing test processes to exit on errors.

## Purpose

Test mode was implemented to solve several critical testing challenges:

1. **Error Testing**: Allow tests to verify error conditions without the test process exiting
2. **Environment Isolation**: Enforce testing only against designated test environments
3. **Safe Operations**: Enable comprehensive testing of all code paths including error scenarios
4. **Continuous Integration**: Support automated testing pipelines with proper exit codes

## The `--test-mode` Flag

### Syntax
```bash
./infra <action> <target> --test-mode [other-flags]
```

### Examples
```bash
# Standard operations with test mode
./infra apply test:infrastructure --test-mode
./infra destroy test:athena --dry-run --test-mode
./infra volume test:athena my-volume --attach --test-mode

# Error validation testing
./infra apply invalid:infrastructure --test-mode  # Returns error code instead of exiting
```

## Technical Implementation

### Global Variable
- **Variable**: `TEST_MODE` (boolean)
- **Default**: `false`
- **Scope**: Global across all modules
- **Set by**: `--test-mode` flag in argument parsing

### Function: `is_test_mode()`
**Location**: `src/infra/args.sh`
```bash
is_test_mode() {
    [[ "$TEST_MODE" == true ]]
}
```

### Enhanced `handle_error()` Function
**Location**: `src/infra/shared.sh`

The centralized error handling function automatically detects test mode:

```bash
handle_error() {
    local message="$1"
    local exit_code="${2:-1}"
    
    # ... error logging and display ...
    
    # Check if test mode is enabled (from args module)
    if declare -f is_test_mode >/dev/null 2>&1 && is_test_mode; then
        debug_message "Test mode: returning error code $exit_code instead of exiting"
        return "$exit_code"
    fi
    
    # Exit if exit code provided (production behavior)
    if [[ "$exit_code" -gt 0 ]]; then
        exit "$exit_code"
    fi
}
```

## Behavior Differences

### Production Mode (Default)
- Errors call `exit()` with appropriate exit codes
- Invalid operations terminate the process
- Designed for interactive and production use

### Test Mode (`--test-mode`)
- Errors return error codes instead of exiting
- Calling functions can catch and verify error conditions
- Test processes continue running after errors
- Enables comprehensive error path testing

## Security Features

### Environment Enforcement
When test mode is active, additional security checks ensure:

1. **Test Environment Only**: All operations are restricted to the `test` environment
2. **No Live Environment Access**: Prevents accidental operations against `dev`, `dev`, or other live environments
3. **Validation Bypass Prevention**: Ensures test mode doesn't bypass critical validations

### Example Security Check
```bash
validate_environment() {
    local env="$1"
    
    # SECURITY: In test mode, only allow test environment
    if is_test_mode && [[ "$env" != "test" ]]; then
        handle_error "SECURITY: Test mode can only operate against 'test' environment, not '$env'"
        return 1
    fi
    
    # ... normal validation ...
}
```

## Error Propagation Chain

Test mode enables proper error propagation throughout the system:

```
parse_arguments()
├── validate_parsed_arguments() || return 1
    ├── validate_environment() || return 1
        ├── handle_error() → return 1 (test mode)
        └── exit 1 (production mode)
    └── validate_target_type() || return 1
```

## Testing Integration

### Bats Test Framework Usage
```bash
@test "environment validation rejects invalid environments" {
    source "${INFRA_ROOT}/args.sh"
    
    run parse_arguments "apply" "invalid:infrastructure" "--test-mode"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "SECURITY: Tests can only run against" ]]
}
```

### Test Helper Integration
**Location**: `tests/helpers/test_helper.bash`

The test helper automatically:
- Sets `TEST_MODE=true` during test setup
- Enforces `TEST_ENV="test"` for all operations
- Provides mock functions that respect test mode behavior

## Supported Operations

All infrastructure operations support test mode:

### Standard Operations
- `apply` - Infrastructure deployment testing
- `destroy` - Infrastructure removal testing  
- `plan` - Change preview testing
- `init` - Initialization testing
- `output` - Output generation testing
- `clean` - Cache cleanup testing

### Specialized Operations
- `volume` - EBS volume management testing
- `shutdown` - Instance shutdown testing
- `reboot` - Instance reboot testing
- `verify` - Infrastructure verification testing
- `status` - Status checking testing

## Development Guidelines

### When to Use Test Mode
1. **Unit Tests**: All unit tests should use `--test-mode`
2. **Integration Tests**: Tests that verify error conditions
3. **CI/CD Pipelines**: Automated testing scenarios
4. **Development**: When testing error handling paths

### When NOT to Use Test Mode
1. **Production Operations**: Never use in live environments
2. **Interactive Use**: Normal operational usage
3. **Live Infrastructure**: Any non-test environment operations

## Debugging with Test Mode

Test mode provides enhanced debugging capabilities:

```bash
# Enable verbose debugging with test mode
./infra apply test:infrastructure --test-mode --verbose 1

# Dry-run with test mode for safe operation preview
./infra destroy test:all --test-mode --dry-run --verbose 1
```

### Debug Output Example
```
🔍 DEBUG: Test mode enabled - errors will return instead of exit
🔍 DEBUG: Validating environment: test at path: /path/to/test
❌ ERROR: Some validation error
🔍 DEBUG: Test mode: returning error code 1 instead of exiting
```

## Best Practices

### Test Development
1. **Always use `--test-mode`** in automated tests
2. **Combine with `--dry-run`** for safe operation testing
3. **Use `TEST_ENV` variable** instead of hardcoded environment names
4. **Verify error codes** in addition to error messages

### Error Handling
1. **Check return codes** after all validation function calls
2. **Use `|| return 1`** pattern for error propagation
3. **Provide meaningful error messages** that help with debugging
4. **Test both success and failure paths**

### Security
1. **Never disable environment validation** in test mode
2. **Use test-specific data** and configurations
3. **Verify test isolation** from live environments
4. **Audit test mode usage** in production systems

## Version History

- **v2.0**: Initial implementation of comprehensive test mode infrastructure
- **v2.0.1**: Enhanced error propagation and security features
- **v2.0.2**: Improved integration with Bats testing framework

---

*Last Updated: December 30, 2024*
*Infrastructure Management System v2.0*
