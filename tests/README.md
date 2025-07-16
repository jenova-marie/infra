# Infrastructure Management System v2.0 - Test Suite

Comprehensive testing framework for the Infrastructure Management System with unit tests, integration tests, and live AWS validation.

## 🧪 Testing Architecture

### Test Mode Infrastructure

#### 🎯 **`--test-mode` Flag Support**
The infrastructure system includes comprehensive test mode support that enables safe, controlled testing of all operations including error conditions:

**Test Mode Benefits:**
- **Error Testing**: Tests can verify error conditions without process termination
- **Environment Isolation**: All test operations restricted to `test` environment only
- **CI/CD Friendly**: Automated testing pipelines work correctly with proper exit codes
- **Development Support**: Easy testing of error handling and validation paths

**Usage in Tests:**
```bash
# Unit tests automatically use test mode
run parse_arguments "apply" "invalid:infrastructure" "--test-mode"
[ "$status" -eq 1 ]

# Integration tests with test mode
run src/infra/infra apply test:infrastructure --test-mode --dry-run
[ "$status" -eq 0 ]
```

**Security Features:**
- **Environment Enforcement**: Only `test` environment allowed in test mode
- **Validation Preserved**: All normal validations remain active
- **No Bypass**: Test mode doesn't disable security checks

### Test Types

#### 🔒 **Unit Tests** (`test/unit/`) - **ALWAYS SAFE**
- **No AWS resources created**: Pure logic testing with mocked dependencies
- **Fast execution**: Typically complete in seconds
- **No costs**: Zero AWS charges or resource consumption
- **Always safe to run**: Can be executed in any environment without risk

#### 🔒 **Dry-Run Tests** (`test/integration/dry_run.bats`) - **SAFE SIMULATION**
- **Simulation only**: Tests `--dry-run` mode across all operations
- **No real resources**: Validates command parsing and logic without creating infrastructure
- **Requires AWS CLI**: Needs configured AWS credentials for validation
- **No costs**: Zero AWS charges (simulation only)

#### 🚨 **Integration Tests** (`test/integration/`) - **⚠️ CREATES REAL AWS RESOURCES**
- **Live infrastructure**: Creates actual VPCs, EC2 instances, EBS volumes, security groups, EIPs
- **Real AWS costs**: Incurs actual AWS charges during test execution
- **Complete lifecycle**: Tests full infrastructure creation → operation → destruction
- **Automatic cleanup**: Includes AWS CLI verification and cleanup of any dangling resources
- **Production validation**: Tests against real AWS APIs and services

### Safety Model

```bash
# 🔒 SAFE - Default behavior (unit tests only)
./run_tests.sh

# 🔒 SAFE - Explicit unit tests
./run_tests.sh --unit

# 🔒 SAFE - Dry-run simulation (no real resources)
./run_tests.sh --dry-run

# 🚨 DANGEROUS - Creates real AWS infrastructure (costs money!)
./run_tests.sh --integration
```

## 🚀 Quick Start

### Safe Testing (Default)
```bash
# Run all unit tests (completely safe)
cd test
./run_tests.sh

# Run specific unit test
./run_tests.sh logger

# Run with verbose output
./run_tests.sh --verbose
```

### Simulation Testing
```bash
# Test dry-run functionality (safe simulation)
./run_tests.sh --dry-run

# Dry-run with verbose output
./run_tests.sh --dry-run --verbose
```

### Live Integration Testing (⚠️ Costs Money!)
```bash
# WARNING: Creates real AWS resources!
./run_tests.sh --integration

# Integration tests with verbose output
./run_tests.sh --integration --verbose
```

## 📁 Test Structure

```
test/
├── README.md                 # This file - testing documentation
├── INTEGRATION.md            # Integration testing guide and AWS resource details
├── UNIT_TESTING.md          # Unit testing guide and test writing patterns
├── run_tests.sh             # Main test runner with safety controls
├── unit/                    # 🔒 Unit tests (always safe)
│   ├── logger.bats         #    Logger module tests
│   ├── args.bats           #    Argument parsing tests (NEW)
│   ├── volume.bats         #    Volume management tests (NEW)
│   └── backup.bats         #    Backup system tests (NEW)
├── integration/             # 🚨 Integration tests (creates real resources)
│   ├── dry_run.bats        #    🔒 Dry-run simulation tests (safe)
│   ├── infrastructure.bats #    🚨 Live infrastructure tests
│   ├── volume_ops.bats     #    🚨 Live volume operation tests (NEW)
│   └── backup_ops.bats     #    🚨 Live backup system tests (NEW)
├── helpers/                 # Test utilities and helpers
│   ├── test_helper.bash    #    Common test utilities
│   ├── aws_helper.bash     #    AWS CLI helpers and cleanup functions
│   └── mock_helper.bash    #    Mocking utilities for unit tests (NEW)
└── fixtures/               # Test data and configurations
    ├── modules.yml         #    Sample modules configuration
    ├── test_volumes.yml    #    Sample volumes configuration (NEW)
    └── test_config/        #    Sample test environment configs (NEW)
```

## 🎯 Test Categories

### Unit Tests (`test/unit/`)

**Purpose**: Test individual modules and functions in isolation
**Safety**: ✅ Always safe - no real resources created
**Speed**: ⚡ Fast (seconds)
**Cost**: 💰 Free

- **`logger.bats`** - Logger module functionality
- **`args.bats`** - Command-line argument parsing and validation
- **`volume.bats`** - Volume management logic (backup system, state checking)
- **`backup.bats`** - Backup flag system and cleanup logic
- **`shared.bats`** - Shared utilities and helper functions
- **`modules.bats`** - Module discovery and management

### Integration Tests (`test/integration/`)

#### Dry-Run Tests (Safe)
- **`dry_run.bats`** - ✅ Safe simulation testing
  - Tests `--dry-run` mode across all operations
  - Validates command parsing without creating resources
  - No AWS costs incurred

#### Live Infrastructure Tests (⚠️ Dangerous)
- **`infrastructure.bats`** - 🚨 Complete infrastructure lifecycle
  - Creates → tests → destroys real AWS infrastructure
  - Tests: VPCs, security groups, EIPs, EBS volumes, ECR repositories
  - Validates actual AWS resource creation and management
  
- **`volume_ops.bats`** - 🚨 Live volume operations
  - Tests volume attachment/detachment with real EBS volumes
  - Validates backup system with real files
  - Tests AWS CLI integration and force operations
  
- **`backup_ops.bats`** - 🚨 Live backup system validation
  - Tests backup creation, cleanup, and rollback
  - Validates production backup workflows
  - Tests backup flag system with real operations

## 🔧 Test Runner Features

### Safety Controls
- **Default safe mode**: Only unit tests run by default
- **Explicit confirmation**: Integration tests require explicit `--integration` flag
- **AWS validation**: Checks AWS CLI configuration before dangerous operations
- **Resource cleanup**: Automatic AWS CLI verification and cleanup after integration tests

### Execution Options
```bash
# Test targeting
./run_tests.sh logger              # Run tests matching 'logger'
./run_tests.sh --unit args         # Run unit tests matching 'args'
./run_tests.sh --dry-run volume    # Run dry-run tests matching 'volume'

# Output control
./run_tests.sh --verbose           # Detailed test output
./run_tests.sh --skip-aws          # Skip AWS CLI validation (for CI/CD)

# Safety options
./run_tests.sh --unit              # Unit tests only (safest)
./run_tests.sh --dry-run           # Simulation tests only (safe)
./run_tests.sh --integration       # All tests including live resources (dangerous)
```

### Automatic Cleanup
Integration tests include automatic cleanup verification:
1. **Test execution**: Creates and tests infrastructure
2. **Terraform cleanup**: Uses `destroy` operations to remove resources
3. **AWS CLI verification**: Scans for any dangling EC2 instances
4. **Force termination**: Terminates any remaining instances with AWS CLI
5. **Cleanup reporting**: Reports all cleanup actions taken

## 🛡️ Safety Guidelines

### Development Workflow
1. **Always start with unit tests**: `./run_tests.sh --unit`
2. **Use dry-run for integration logic**: `./run_tests.sh --dry-run`
3. **Only use integration tests when necessary**: Real infrastructure testing
4. **Monitor AWS costs**: Integration tests create billable resources
5. **Verify cleanup**: Check AWS console after integration tests

### CI/CD Integration
```bash
# Safe CI pipeline (no real resources)
./run_tests.sh --unit --skip-aws

# Simulation testing in CI
./run_tests.sh --dry-run --skip-aws

# Full integration (only in dedicated environments)
./run_tests.sh --integration
```

### Cost Management
- **Integration tests**: Typically cost $0.50-2.00 per full run
- **Resource types**: t3.micro instances, small EBS volumes, minimal networking
- **Duration**: Most resources exist for 5-15 minutes during testing
- **Cleanup**: Automatic termination prevents ongoing charges

## 🎯 Test Environment

### AWS Requirements for Integration Tests
- **AWS CLI**: Configured with appropriate permissions
- **IAM Permissions**: 
  - EC2 full access (instances, VPCs, security groups, EIPs, EBS)
  - ECR access for repository testing
  - IAM role and policy management
- **Region**: Tests use `us-west-2` (configured in test environment)
- **State Storage**: Tests use temporary S3 state storage

### Test Environment Location
Integration tests use the live `test` environment:
- **Path**: `src/live/test/`
- **Configuration**: Real AWS resources in test account
- **Isolation**: Separate from dev/prod environments
- **Cleanup**: Automatic destruction after each test run

## ✅ Test Reporting

### Success Indicators
- ✅ **Green checkmarks**: Successful test completion
- 📋 **Test summaries**: Clear pass/fail counts
- 🧹 **Cleanup confirmations**: AWS resource cleanup verification

### Failure Handling
- ❌ **Red X marks**: Failed test identification
- 📝 **Detailed logs**: Comprehensive error reporting
- 🚨 **Cleanup warnings**: Alerts if AWS resources weren't cleaned up
- 🔧 **Recovery suggestions**: Guidance for manual cleanup if needed

## 🔄 Continuous Integration

### GitHub Actions Integration
```yaml
# Example CI configuration
- name: Run Safe Tests
  run: |
    cd test
    ./run_tests.sh --unit --skip-aws

- name: Run Simulation Tests
  run: |
    cd test
    ./run_tests.sh --dry-run --skip-aws
```

### Local Development
```bash
# Daily development testing
./run_tests.sh --unit

# Before committing changes
./run_tests.sh --unit && ./run_tests.sh --dry-run

# Before major releases (cost-aware)
./run_tests.sh --integration
```

## 🎓 Writing New Tests

### Unit Test Pattern
```bash
# test/unit/example.bats
@test "module function handles valid input" {
    # Setup
    source src/infra/module.sh
    
    # Execute
    run function_name "valid_input"
    
    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected_result" ]]
}
```

### Integration Test Pattern
```bash
# test/integration/example.bats
@test "infrastructure lifecycle completes successfully" {
    # Setup test environment
    setup_test_environment
    
    # Create resources
    run src/infra/infra apply test:component
    [ "$status" -eq 0 ]
    
    # Verify resources exist
    verify_aws_resources_exist
    
    # Cleanup
    run src/infra/infra destroy test:component
    [ "$status" -eq 0 ]
    
    # Verify cleanup
    verify_aws_cleanup_complete
}
```

## ✨ **Enhanced Volume Testing with Comprehensive Dry-Run Coverage**

### **🎯 Volume Module Testing Excellence** 
The `tests/unit/volume.bats` file now provides **38 comprehensive test cases** that focus exclusively on `--dry-run` operations for complete safety:

#### **🔧 Key Testing Areas**
- **Enhanced Dry-Run Functions**: All new dry-run functionality in `volume.sh` thoroughly tested
- **File Operations Safety**: Verify no actual files are created/modified during dry-run
- **Multi-Flag Compatibility**: Test dry-run with `--backup`, `--force`, `--bell`, `--dns`
- **Fast Path Optimization**: Test performance improvements and early returns
- **Error Handling**: Ensure error detection works without side effects
- **AWS Integration**: Test integration with `aws.sh` functions in dry-run mode

#### **🛡️ Complete Safety**
- **Zero Infrastructure Risk**: All tests run exclusively in `--dry-run` mode
- **File System Safety**: Tests verify no actual file modifications occur
- **Mock Integration**: Comprehensive mocking of external dependencies
- **Isolated Testing**: No real AWS resources accessed during testing

#### **📈 Test Coverage Highlights**
```bash
# Enhanced test categories:
✅ update_volumes_yml_attach/detach dry-run messaging (6 tests)
✅ apply_volume_changes comprehensive dry-run flow (2 tests) 
✅ is_volume_attached_fast AWS integration (2 tests)
✅ execute_volume_operation_impl dry-run generation (2 tests)
✅ file_copy/file_remove safety verification (2 tests)
✅ Volume resolution and validation (4 tests)
✅ Device name management (4 tests)
✅ Volume state checking (3 tests)
✅ Backup management (4 tests)
✅ Volume operation processing (2 tests)
✅ Multi-flag integration (1 test)
✅ Full operation flow (1 test)
✅ Error handling safety (2 tests)
✅ Invalid action handling (1 test)

Total: 38 comprehensive test cases
```

#### **🚀 Benefits Realized**
- **Complete dry-run verification** for all volume operations
- **File modification safety** ensuring no side effects during testing
- **Performance optimization testing** for fast volume checking
- **Multi-flag compatibility** verification
- **Error preservation** without infrastructure risk
- **Future-proof structure** for easy test additions

---

**Last Updated**: December 30, 2024 11:55 PM CST

For detailed information on specific test types, see:
- **[UNIT_TESTING.md](./UNIT_TESTING.md)** - Unit test writing guide
- **[INTEGRATION.md](./INTEGRATION.md)** - Integration testing and AWS resource management 