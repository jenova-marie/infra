# Integration Testing Guide

Comprehensive guide for running integration tests against real AWS infrastructure for the Infrastructure Management System v2.0.

## ⚠️ SAFETY WARNING

**Integration tests create REAL AWS resources that incur REAL costs!**

- **💰 Cost Impact**: Typically $0.50-2.00 per full test run
- **⏱️ Duration**: Resources exist for 5-15 minutes during testing
- **🧹 Auto-Cleanup**: Automatic destruction and AWS CLI verification
- **🚨 Risk**: Failed cleanup can result in ongoing charges

## 🎯 Integration Testing Philosophy

Integration tests validate the complete infrastructure lifecycle against real AWS APIs:

- **🔴 Live Resources**: Creates actual VPCs, EC2 instances, EBS volumes, security groups, EIPs
- **✅ Complete Validation**: Tests full creation → operation → destruction cycle
- **🌐 Real AWS APIs**: Validates against actual AWS service behavior
- **🧹 Automatic Cleanup**: Comprehensive cleanup with AWS CLI verification
- **✅ Production Validation**: Ensures system works in real-world scenarios

## 🏗️ AWS Resources Created

### Core Infrastructure (`infrastructure.bats`)
```bash
# VPC and Networking
aws_vpc.main                    # Custom VPC with DNS support
aws_internet_gateway.main       # Internet gateway for public access
aws_route_table.main           # Route table with internet access
aws_subnet.main                # Public subnet in us-west-2a

# Security
aws_security_group.ssh         # SSH access (port 22)
aws_security_group.web         # HTTP/HTTPS access (ports 80, 443)
aws_security_group.internal    # Internal communication

# IAM
aws_iam_role.instance_role     # EC2 instance role
aws_iam_instance_profile.main  # Instance profile for EC2

# ECR
aws_ecr_repository.app_repo    # Container image repository
```

### Instance Infrastructure (`volume_ops.bats`)
```bash
# EC2 Instance
aws_instance.athena            # t3.micro instance for testing
aws_eip.athena                 # Elastic IP for stable access

# EBS Volumes
aws_ebs_volume.test_volume     # 10GB gp3 volume for attachment testing
aws_volume_attachment.test     # Volume attachment to instance
```

### Typical Cost Breakdown
```
EC2 t3.micro (15 minutes):     $0.002
EBS 10GB volume (15 minutes):  $0.003  
EIP allocation (15 minutes):   $0.002
Data transfer (minimal):       $0.001
VPC/networking (included):     $0.000
Total per test run:           ~$0.008-0.015
```

## 🚀 Running Integration Tests

### Prerequisites
```bash
# Verify AWS CLI configuration
aws sts get-caller-identity

# Verify Terragrunt installation
terragrunt --version

# Verify test environment exists
ls src/live/test/
```

### Safe Execution Pattern
```bash
# 1. Always start with unit tests (safe)
cd test
./run_tests.sh --unit

# 2. Test dry-run mode (safe simulation)
./run_tests.sh --dry-run

# 3. Run integration tests (creates real resources)
./run_tests.sh --integration

# 4. Verify cleanup completed
aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name!=`terminated`]'
```

### Specific Test Execution
```bash
# Run specific integration test suites
./run_tests.sh --integration infrastructure
./run_tests.sh --integration volume_ops
./run_tests.sh --integration backup_ops

# Run with verbose output for debugging
./run_tests.sh --integration --verbose infrastructure
```

## 🧪 Test Suites

### 1. Infrastructure Lifecycle (`infrastructure.bats`)

**Purpose**: Validates complete infrastructure creation and destruction

**Test Flow**:
```bash
1. 🏗️  Create base infrastructure (VPC, subnets, security groups)
2. 🖥️  Deploy EC2 instance with EIP
3. 💾  Create and attach EBS volume
4. 🔍  Verify all resources exist via AWS CLI
5. 🗑️  Destroy all infrastructure
6. ✅  Verify complete cleanup via AWS CLI
```

**AWS Resources Tested**:
- VPC creation and configuration
- Security group rules and associations
- EIP allocation and association
- EC2 instance launch and configuration
- EBS volume creation and attachment
- ECR repository creation

### 2. Volume Operations (`volume_ops.bats`)

**Purpose**: Tests EBS volume management with backup system

**Test Flow**:
```bash
1. 🏗️  Setup test infrastructure (instance + volume)
2. 📎  Test volume attachment with backup creation
3. 🔓  Test volume detachment with AWS CLI force
4. 📋  Verify backup file management (creation, cleanup)
5. 🔄  Test multiple attach/detach cycles
6. 🧹  Cleanup infrastructure and verify AWS state
```

**Key Validations**:
- Volume attachment status in AWS
- Device name allocation and tracking
- Backup file creation with `--backup` flag
- Backup file cleanup (3 most recent)
- AWS CLI force detachment
- Centralized outputs consistency

### 3. Backup Operations (`backup_ops.bats`)

**Purpose**: Validates backup system behavior with real operations

**Test Flow**:
```bash
1. 🏗️  Setup test infrastructure
2. 📁  Test operations without backup flag (no files created)
3. 📦  Test operations with backup flag (files created)
4. 🧹  Test backup cleanup (old files removed)
5. ❌  Test failure scenarios (backup preservation)
6. 🗑️  Cleanup and verify AWS state
```

**Backup System Validations**:
- No backup files created by default
- Backup files created only with `--backup` flag
- Timestamp format: `volumes.yml.backup.YYYYMMDD_HHMMSS`
- Cleanup keeps only 3 most recent files
- Failed operations preserve backup files
- Successful operations remove backup files when flag enabled

## 🧹 Cleanup Procedures

### Automatic Cleanup (Default)
Integration tests include comprehensive automatic cleanup:

```bash
1. Terragrunt Destroy Phase:
   - Runs `destroy` operations for all modules
   - Removes Terraform state and resources
   - Validates destruction completion

2. AWS CLI Verification Phase:
   - Scans for dangling EC2 instances
   - Lists any remaining EBS volumes
   - Checks for unattached EIPs
   - Reports any orphaned resources

3. Force Cleanup Phase:
   - Terminates any remaining EC2 instances
   - Detaches and deletes orphaned EBS volumes
   - Releases unassociated EIPs
   - Reports all cleanup actions
```

### Manual Cleanup (If Needed)
If automatic cleanup fails, use these commands:

```bash
# Find and terminate any running instances
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId,State.Name]' \
  --output table

aws ec2 terminate-instances --instance-ids i-xxxxxxxxxxxxx

# Find and delete any test volumes
aws ec2 describe-volumes \
  --filters Name=tag:Environment,Values=test \
  --query 'Volumes[?State!=`deleting`].[VolumeId,State]' \
  --output table

aws ec2 delete-volume --volume-id vol-xxxxxxxxxxxxx

# Release any unassociated EIPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' \
  --output table

aws ec2 release-address --allocation-id eipalloc-xxxxxxxxxxxxx
```

### Cleanup Verification
```bash
# Verify no test instances remain
aws ec2 describe-instances \
  --filters Name=tag:Environment,Values=test \
  --query 'Reservations[*].Instances[?State.Name!=`terminated`]'

# Should return empty array: []

# Verify no test volumes remain  
aws ec2 describe-volumes \
  --filters Name=tag:Environment,Values=test \
  --query 'Volumes[?State!=`deleting`]'

# Should return empty array: []
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### Tests Fail Due to AWS Permissions
```bash
# Check current AWS identity
aws sts get-caller-identity

# Verify required permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USERNAME \
  --action-names ec2:RunInstances ec2:CreateVolume ec2:DescribeInstances \
  --resource-arns "*"
```

#### Tests Fail Due to Resource Limits
```bash
# Check EC2 limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A  # Running On-Demand instances

# Check EBS limits  
aws service-quotas get-service-quota \
  --service-code ebs \
  --quota-code L-D18FCD1D  # General Purpose SSD volume storage
```

#### Tests Fail During Cleanup
```bash
# Run manual cleanup (see Manual Cleanup section above)

# Check for dependency issues
aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`running`]'
aws ec2 describe-volumes --query 'Volumes[?State==`in-use`]'

# Force cleanup if needed
./run_tests.sh --force-cleanup  # Custom cleanup mode
```

#### State File Corruption
```bash
# Remove corrupted state files
cd src/live/test/
find . -name "*.tfstate*" -delete
find . -name ".terraform.lock.hcl" -delete

# Reinitialize Terragrunt
terragrunt init --reconfigure
```

## ✅ Test Monitoring

### Success Indicators
```bash
✅ All infrastructure created successfully
✅ Volume operations completed successfully  
✅ Backup system functioning correctly
✅ All AWS resources destroyed successfully
✅ AWS CLI verification confirms cleanup
✅ No orphaned resources remain
```

### Failure Indicators
```bash
❌ Infrastructure creation failed
❌ Volume operations failed
❌ Backup system malfunction
❌ Cleanup incomplete
❌ AWS CLI found orphaned resources
🚨 Manual cleanup required
```

### Cost Monitoring
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-05-01,End=2025-05-29 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Check daily costs for test runs
aws ce get-cost-and-usage \
  --time-period Start=2025-05-28,End=2025-05-29 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🔄 CI/CD Integration

### Safe CI Pipeline
```yaml
# GitHub Actions example
name: Infrastructure Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Unit Tests (Safe)
        run: |
          cd test
          ./run_tests.sh --unit --skip-aws

  dry-run-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      - name: Run Dry-Run Tests (Safe)
        run: |
          cd test
          ./run_tests.sh --dry-run

  integration-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests, dry-run-tests]
    if: github.ref == 'refs/heads/main'  # Only on main branch
    steps:
      - uses: actions/checkout@v3
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2
      - name: Run Integration Tests (⚠️ Costs Money!)
        run: |
          cd test
          ./run_tests.sh --integration
```

## 📈 Performance Metrics

### Typical Test Execution Times
```bash
Unit Tests:           15-30 seconds
Dry-Run Tests:        1-2 minutes
Infrastructure Tests: 8-12 minutes
Volume Operations:    5-8 minutes
Backup Operations:    3-5 minutes
Full Integration:     15-25 minutes
```

### Resource Creation Times
```bash
VPC + Networking:     2-3 minutes
EC2 Instance:         2-4 minutes
EBS Volume:           1-2 minutes
Volume Attachment:    30-60 seconds
Destruction:          3-5 minutes
AWS Verification:     30-60 seconds
```

## 🎯 Best Practices

### Development Workflow
1. **Always start with unit tests**: Fast feedback, no costs
2. **Use dry-run for logic validation**: Safe simulation testing
3. **Run integration tests sparingly**: Only when necessary
4. **Monitor costs**: Check AWS billing after test runs
5. **Verify cleanup**: Always confirm resources are destroyed

### Cost Optimization
- **Run tests during development hours**: Avoid overnight failures
- **Use smallest instance types**: t3.micro sufficient for testing
- **Clean up immediately**: Don't leave resources running
- **Batch test runs**: Group multiple tests into single sessions
- **Use test-specific tags**: Easy identification for cleanup

### Safety Protocols
- **Never run integration tests on production accounts**
- **Use dedicated test AWS accounts when possible**
- **Set up billing alerts**: Monitor unexpected charges
- **Regular cleanup verification**: Weekly orphaned resource checks
- **Document failed cleanup**: Track any manual cleanup needed

---

**Last Updated**: May 28, 2025 6:30 PM CST

Integration testing provides essential validation but must be used responsibly. Always prioritize unit tests and dry-run testing for development workflows, reserving integration tests for final validation and release preparation. 