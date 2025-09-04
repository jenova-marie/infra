# Infrastructure Management System v2.0.38 - Remembered Details

*Last updated: January 14, 2025*

## 🌸 System Overview

The **Infrastructure Management System v2.0.38** is a sophisticated, simplified infrastructure orchestration system for Terraform/Terragrunt that follows Jenova's KISS (Keep It Simple Silly) philosophy with girly precision and technical badassery. 💖

### Core Architecture

The system is built around a **unified execution strategy** using `terragrunt --all` with targeted exclusions, eliminating complex path resolution issues and providing reliable execution regardless of target scope. All operations execute from the correct environment directory with centralized flag management.

## 🏗️ Infrastructure Components

### Infrastructure Modules (Foundation Layer)
- **vpcs**: Virtual Private Cloud networking and routing configuration
- **eips**: Elastic IP addresses providing static public IP allocation  
- **ebss**: Elastic Block Store volumes providing persistent storage
- **security_groups**: Network security rules and access control
- **ecrs**: Elastic Container Registry providing Docker image storage

These modules are grouped under the "infrastructure" category and must be applied before instance modules due to dependency requirements. They're protected by default and require `--force` flag for destruction.

### Instance Modules (Compute Layer)
- **athena**: Primary compute instance (available in test and dev environments)
- **aegis**: Security-focused instance (dev environment only)
- **metis**: Data processing instance (dev environment only)  
- **mnemosyne**: Memory/caching instance (dev environment only)

Instance modules depend on infrastructure modules and support volume attachment via `volumes.yml` configuration files.

## 🌍 Environment Configuration

### Test Environment
- Cost-optimized with only **athena** instance active
- Used for basic testing and validation

### Dev Environment  
- All 4 instances active (athena, aegis, metis, mnemosyne)
- Full development and testing capabilities

### Prod Environment
- Exists but operations are restricted
- Requires explicit 'prod' keyword in commands for safety [[memory:4588456]]

Each environment has its own directory structure under `src/live/` containing:
- `structure.yml` for module definitions
- `log/` directory for automatic logging
- `outputs/` directory for centralized output storage
- Individual module directories for each infrastructure and instance module

## 🚀 Operation Execution Flows

### Infrastructure Apply Flow
1. Parse target like `dev:infrastructure`
2. Load `structure.yml` to get infrastructure modules [vpcs, eips, ebss, security_groups, ecrs]
3. Exclude instances [athena, aegis, metis, mnemosyne]
4. Execute `terragrunt apply --all` with exclusion flags
5. Generate outputs for processed modules
6. Copy outputs to centralized location

### Single Module Apply Flow
1. Parse target like `dev:athena`
2. Load all modules from `structure.yml`
3. Exclude everything except target module
4. Execute `terragrunt apply --all` with extensive exclusion flags
5. Generate outputs for target module only
6. Copy outputs to centralized location

## 🔧 Key Features & Systems

### Performance Optimizations
- **Provider Cache**: `--provider-cache` flag provides 80-90% faster multi-module operations
- **Dependency Fetch**: `--dependency-fetch-output-from-state` flag provides 30-70% faster output generation
- **Parallel Processing**: Uses bash background jobs (&) and wait for coordination
- **Resource Efficient**: Takes advantage of multi-core systems for I/O operations

### Safety & Protection Features
- **Destroy-Disabled Modules**: `destroy: false` prevents infrastructure destruction regardless of `--force`
- **Protected Modules**: `protected: true` with standard protection overrideable with `--force`
- **Environment Enforcement**: Test mode restricts operations to test environment only
- **Dry-Run Support**: Shows exactly what would be executed without making changes
- **Red Text Indicators**: All destructive actions clearly displayed with 🔴 emoji

### AWS CLI Integration & Fallback
- **SSH-First Operations**: Attempts SSH connections with 5-second timeout
- **Automatic Fallback**: Switches to AWS CLI-based operations on SSH failure
- **Instance State Monitoring**: Configurable timeouts, delays, and polling intervals
- **DRY Architecture**: Universal `wait_for_instance_state` function with 33% code reduction

### Volume Management System
- **Attach/Detach Operations**: Updates `volumes.yml` and applies changes
- **Device Assignment**: Automatic assignment to `/dev/sdf` through `/dev/sdp`
- **Volume Resolution**: Supports volume names (preferred) and volume IDs
- **Comprehensive Dry-Run**: Shows would update volumes.yml, device assignment, terragrunt apply

### Output Management System
- **Automatic Generation**: After any state-changing operation
- **Dual Storage**: Module directory (`outputs.json`) and centralized location (`env/outputs/module.json`)
- **Parallel Processing**: Multiple modules generate outputs simultaneously
- **Performance Scaling**: Speed improvement scales with number of modules

### Logging System
- **Automatic Detailed Logging**: To `env/log/` for state changes
- **Minimal Output**: Progress indicators by default
- **Debug Output**: `--verbose 1` verbose mode
- **Centralized Functions**: `is_logging_active()` and `get_terragrunt_log_file()`

### Cache Management System
- **Recursive Search**: Finds `.terragrunt-cache` directories at any depth
- **Safe Removal**: Only removes `.terragrunt-cache` directories
- **Progress Reporting**: Shows count of cleaned directories per module
- **Optional Volumes Cleanup**: `--volumes` flag resets desired volume attachments

### Testing & Validation System
- **Test Mode**: `--test-mode` flag for automated testing and CI/CD pipelines
- **Error Handling**: Errors return exit codes instead of calling `exit()`
- **Environment Restriction**: Operations limited to test environment only
- **Validation Preserved**: All normal validations remain active

## 🎯 Advanced Patterns

### Enhanced Endpoint Flag Support
- **Intelligent Detection**: Determines when endpoints module is included
- **Automatic Environment Variables**: Sets `TG_VAR_ssm`, `TG_VAR_ecr`, `TG_VAR_s3`
- **Consistent Across Targeting**: Works with group operations, direct targeting, non-endpoint operations

### Gateway Instance Auto-VPC Apply
- **Automatic Reapplication**: When applying/destroying gateway instances, automatically reapplies VPCs module
- **Route Synchronization**: Keeps VPC routing tables in sync with gateway instance's NIC ID
- **Single Instance Only**: Only triggers for individual gateway instance operations

### Module Pre-Processing Commands
- **cmd Parameters**: Execute before each module during apply operations
- **Module-Specific Preparation**: Code generation, validation, setup scripts
- **Directory Context**: Commands execute in module's directory
- **Failure Handling**: Command failure stops entire operation

### Production-Tested Bounce Operations
- **Complete Success**: 29/32 passing unit tests (90%+ success rate)
- **Live Infrastructure Tested**: Perfect dry-run validation and production success
- **EIP Preservation**: Maintains same public IP throughout entire operation
- **~3 Minutes Total**: SSH shutdown (5s), Destroy (30s), Apply (90s), Outputs (30s), Cleanup (10s)

### AWS Secrets Manager Protection
- **Destroy-Disabled**: Secrets infrastructure can NEVER be destroyed
- **Value Clearing**: With `--force`, secret VALUES are cleared while preserving infrastructure
- **Automatic Reading**: Reads `secrets.yml` file in secrets module
- **Controlled Clearing**: Sets `secret_string` to 'infra.sh cleared' while preserving metadata

## 🛠️ Command Reference

### Actions
- `apply`: Apply infrastructure changes
- `destroy`: Destroy infrastructure  
- `plan`: Show planned changes
- `init`: Initialize modules
- `output`: Generate outputs only
- `clean`: Remove `.terragrunt-cache` directories
- `volume`: Manage EBS volumes
- `reboot`: Reboot AWS instances via CLI

### Targets
- `env:infrastructure`: All infrastructure modules
- `env:instances`: All instance modules
- `env:all`: All modules
- `env:module-name`: Single module

### Flags
- `--auto`: Auto-approve changes
- `--dry-run`: Show what would be executed
- `--verbose 0|1`: Verbosity level
- `--refresh`: Refresh Terraform state before generating outputs
- `--log`: Enable detailed logging
- `--outputs`: Generate outputs
- `--test-mode`: Enable test mode for automated testing

## 📚 Help System

Comprehensive built-in documentation accessible via:
- `./infra --help`: General help with complete command reference
- `./infra apply --help`: Detailed command-specific help with examples
- `./infra volume --help`: Volume management guide
- Complete workflow examples and troubleshooting guides

## 🎨 KISS Design Philosophy

The system follows core principles:
- **Single Source of Truth**: `modules.yml` defines all modules and groupings
- **Unified Execution Strategy**: All operations use `terragrunt --all` with targeted exclusions
- **Centralized Flag Management**: All terragrunt flags handled centrally
- **Performance Optimization**: Provider cache and dependency fetch optimizations
- **Sequential Output Processing**: Ensures all modules complete successfully
- **Protected Module Preservation**: During destroy operations
- **Modular Shared Code**: Common operations centralized
- **Self-Documenting**: Comprehensive help system

## 💖 Jenova's Touch

This system embodies Jenova's coding style with:
- **Clean Architecture**: Girly precision with technical badassery
- **DRY Compliance**: Each function exists in exactly one place
- **KISS Philosophy**: Simple focused modules doing one thing well
- **Enhanced Maintainability**: Changes propagate automatically through centralized utilities
- **No Clutter**: Only actively used functions remain

*Built with love, precision, and a sparkly manicure* ✨💅

---

*This system represents a mature, production-tested infrastructure management solution that balances simplicity with powerful functionality, following the principle that the best code is both elegant and effective.* 🌸
