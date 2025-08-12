# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Infrastructure Management System v2.0.38** - a simplified, reliable infrastructure orchestration system for Terraform/Terragrunt with DRY AWS CLI integration. The system follows a "simplicity first" approach with unified execution strategies and comprehensive automation.

## Core Commands

### Primary Infrastructure Operations
```bash
# Main entry point - always use this script
./infra <action> <target> [flags]

# Common development workflow
./infra status dev:all                    # Check infrastructure status
./infra apply dev:infrastructure --dry-run # Preview infrastructure changes
./infra apply dev:infrastructure          # Deploy infrastructure
./infra apply dev:instances              # Deploy instances
./infra output dev:all --refresh         # Generate fresh outputs

# Testing and validation
./infra plan dev:all                     # Show planned changes
./infra clean dev:all --dry-run          # Preview cache cleanup
./infra clean dev:all                    # Clean terragrunt cache
```

### Volume Management
```bash
# Attach/detach EBS volumes
./infra volume dev:instance volume-name --attach --auto
./infra volume dev:instance volume-name --detach --auto

# Always test volume operations first
./infra volume dev:instance volume-name --attach --dry-run --verbose 1
```

### Testing Framework
```bash
# Run safe unit tests (default - always safe)
cd tests && ./run_tests.sh

# Run specific test patterns
./run_tests.sh logger                    # Test logger module
./run_tests.sh --unit args              # Test argument parsing
./run_tests.sh --dry-run                # Test dry-run simulations

# Integration tests (⚠️ creates real AWS resources - costs money!)
./run_tests.sh --integration
```

### AWS Instance Management
```bash
# Reboot instances via AWS CLI
./infra reboot dev:instance

# Shutdown with fallback to AWS CLI termination
./infra shutdown dev:instance
./infra shutdown dev:instance --bounce   # Destroy and recreate
```

## High-Level Architecture

### Modular Design Philosophy

The system uses a **unified execution strategy** where all operations use `terragrunt --all` with targeted exclusions rather than complex path resolution. This eliminates many common Terragrunt issues and provides consistent behavior.

### Core Components

1. **Main Orchestrator** (`infra` script)
   - Entry point that coordinates all operations
   - Loads modules in dependency order
   - Handles error trapping and operation finalization

2. **Module System Architecture**
   - `args.sh` - Command-line argument parsing and validation
   - `operations.sh` - Primary operation execution logic
   - `modules.sh` - Module discovery and management from `modules.yml`
   - `targeting.sh` - Target resolution and exclusion generation
   - `shared.sh` - KISS utilities and common operations
   - `aws.sh` - AWS CLI integration and instance management
   - `volume.sh` - EBS volume management with automatic device assignment
   - `shutdown.sh` - SSH and AWS CLI-based instance shutdown
   - `output.sh` - Output generation and centralized management
   - `clean.sh` - Cache and state cleanup operations

3. **Configuration-Driven Operations**
   - `modules.yml` - Single source of truth for module definitions
   - Groups: `infrastructure` (VPCs, security groups, EIPs, etc.)
   - Groups: `instances` (athena, aegis, metis, mnemosyne)
   - Module properties: `protected`, `destroy`, `gateway`, `cmd`

4. **Secrets Protection System**
   - Ultimate AWS Secrets Manager protection
   - Modules with `destroy: false` can never be destroyed
   - `--force` flag clears secret values via AWS CLI instead of destroying infrastructure
   - Automatic secret discovery from `secrets.yml` files

### Execution Flow

1. **Argument Parsing**: Parse action, target, and flags using centralized argument processor
2. **Environment Validation**: Validate environment exists and is accessible
3. **Module Resolution**: Load `modules.yml` and resolve target modules
4. **Exclusion Generation**: Calculate which modules to exclude from `terragrunt --all`
5. **Pre-processing**: Execute module `cmd` parameters if defined (apply operations only)
6. **Terragrunt Execution**: Run unified `terragrunt --all` with exclusions
7. **Output Generation**: Automatically generate outputs for state-changing operations
8. **Post-processing**: Execute cleanup, DNS updates, SSH cleanup as needed

### Unified Execution Strategy

**Key Innovation**: All operations use `terragrunt --all --terragrunt-exclude-dir=...` instead of complex targeting:

```bash
# Single module targeting
terragrunt apply --all --terragrunt-exclude-dir=vpcs,security_groups,eips,etc

# Infrastructure group
terragrunt apply --all --terragrunt-exclude-dir=athena,metis,mnemosyne

# Full environment (no exclusions)  
terragrunt apply --all
```

This provides:
- No path resolution issues
- Single execution path for all operations
- Consistent behavior across single module and full environment operations
- Enhanced reliability and simplified codebase

## Development Patterns

### KISS Utilities Usage

The system includes comprehensive KISS (Keep It Simple Silly) utilities. Always use these instead of reimplementing common patterns:

```bash
# Get operation context in one call
get_operation_context
# Sets: OP_ACTION, OP_ENV, OP_TARGET_TYPE, OP_ENV_PATH

# Standardized file operations
module_path="$(get_module_path "$env" "$module")"
output_path="$(get_module_output_path "$env" "$module")"

# Dry-run handling
if is_dry_run; then
    dry_run_message "[DRY-RUN] Would perform operation"
    return 0
fi

# Execute with dry-run support
execute_with_dry_run "command" "dry-run message"

# Post-operation cleanup
execute_post_operation_actions "Operation completed successfully"
```

### Module Configuration Patterns

**Enhanced Module Properties** in `modules.yml`:
```yaml
infrastructure:
  - vpcs
  - name: security_groups
    cmd: python3 generate.py    # Pre-processing command
  - name: eips
    protected: true             # Protected from destroy without --force
  - name: secrets
    destroy: false              # Cannot be destroyed, only values cleared

instances:
  - name: nyx
    gateway: true               # Auto-applies VPCs after gateway changes
  - athena
  - metis
```

### Testing Best Practices

**Test Mode Support**: Use `--test-mode` for automated testing:
```bash
# All operations can use test mode for safe testing
./infra apply test:infrastructure --test-mode --dry-run
```

**Safe Testing Workflow**:
1. Always start with unit tests: `./run_tests.sh --unit`
2. Use dry-run for integration logic: `./run_tests.sh --dry-run`  
3. Only use integration tests when necessary (they cost money!)

### Error Handling Patterns

The system uses consistent error handling with proper test mode support:
- Operations return exit codes instead of calling `exit()` in test mode
- All validations remain active in test mode
- Environment enforcement (test mode limited to `test` environment only)

### Performance Optimizations

**Provider Cache**: System automatically uses `--terragrunt-provider-cache` for 80-90% faster multi-module operations.

**Fast Volume Checking**: Volume operations include optimized checking with early returns for better performance.

**Sequential Output Processing**: Ensures 100% reliability over speed for output generation.

## Important Implementation Notes

### Module Dependencies and Sourcing

When working with the infrastructure modules, note the dependency order for sourcing:
1. `logger.sh` - Must be first (provides debug_message)
2. `output.sh` and `shared.sh` - Core utilities
3. All other modules can be loaded after shared utilities are available

### AWS CLI Integration

The system includes robust AWS CLI integration:
- Automatic fallback from SSH to AWS CLI for instance operations
- Instance state monitoring with configurable timeouts
- Comprehensive error handling for network/connectivity issues

### Protected Operations

**Secrets Protection**: The ultimate protection system prevents accidental destruction of AWS Secrets Manager resources:
- Modules with `destroy: false` cannot be destroyed
- `--force` flag clears values via AWS CLI instead of destroying infrastructure
- Automatic discovery of secrets from `secrets.yml` files

**Gateway Instance Automation**: When applying/destroying instances marked `gateway: true`, the system automatically reapplies VPCs to keep routing tables in sync.

## Directory Structure Context

```
/
├── infra*                    # Main entry script
├── *.sh                     # Core modules (args, operations, shared, etc.)
├── tests/                   # Comprehensive test suite
│   ├── run_tests.sh        # Test runner with safety controls
│   ├── unit/               # Safe unit tests (always safe to run)
│   ├── integration/        # Integration tests (costs money!)
│   └── helpers/            # Test utilities and mocking
├── memory-bank/            # Context and documentation
├── src/live/               # Terragrunt environments (dev, test, prod)
│   ├── dev/modules.yml     # Module configuration
│   ├── dev/outputs/        # Centralized outputs
│   └── dev/log/           # Operation logs
└── bats-core-1.12.0/       # Bats testing framework
```

This system prioritizes reliability, safety, and maintainability with comprehensive automation and protection mechanisms.