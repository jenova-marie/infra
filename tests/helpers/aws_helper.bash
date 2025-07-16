#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - AWS CLI Test Helpers
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: AWS CLI utilities for validating real infrastructure in tests
# Author: Infrastructure Management System v2.0
# Last Updated: May 26, 2024

# ─────────────────────────────────────────────────────────────────────────────
# AWS Resource Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if AWS CLI is available and configured
# Usage: validate_aws_cli
validate_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI not found" >&2
        return 1
    fi
    
    # Test AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "AWS credentials not configured or invalid" >&2
        return 1
    fi
    
    return 0
}

# Get current AWS account ID
# Usage: get_aws_account_id
get_aws_account_id() {
    aws sts get-caller-identity --query 'Account' --output text 2>/dev/null
}

# Get current AWS region
# Usage: get_aws_region
get_aws_region() {
    aws configure get region 2>/dev/null || echo "us-east-2"
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if VPC exists with specific tag
# Usage: vpc_exists "test-vpc"
vpc_exists() {
    local vpc_name="$1"
    local vpc_count=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$vpc_name" \
        --query 'length(Vpcs)' \
        --output text 2>/dev/null)
    
    [[ "$vpc_count" -gt 0 ]]
}

# Get VPC ID by name
# Usage: get_vpc_id "test-vpc"
get_vpc_id() {
    local vpc_name="$1"
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$vpc_name" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null
}

# List all VPCs with their names
# Usage: list_vpcs
list_vpcs() {
    aws ec2 describe-vpcs \
        --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],State]' \
        --output table 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 Instance Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if EC2 instance exists with specific tag
# Usage: instance_exists "test-athena"
instance_exists() {
    local instance_name="$1"
    local instance_count=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null)
    
    [[ "$instance_count" -gt 0 ]]
}

# Get instance state by name
# Usage: get_instance_state "test-athena"
get_instance_state() {
    local instance_name="$1"
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text 2>/dev/null | head -1
}

# Get instance ID by name
# Usage: get_instance_id "test-athena"
get_instance_id() {
    local instance_name="$1"
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null | head -1
}

# List all instances with their states
# Usage: list_instances
list_instances() {
    aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],InstanceType]' \
        --output table 2>/dev/null
}

# Wait for instance to reach specific state
# Usage: wait_for_instance_state "test-athena" "running" 300
wait_for_instance_state() {
    local instance_name="$1"
    local desired_state="$2"
    local timeout="${3:-300}"  # Default 5 minutes
    local start_time=$(date +%s)
    
    echo "Waiting for instance '$instance_name' to reach state '$desired_state'..."
    
    while true; do
        local current_state=$(get_instance_state "$instance_name")
        
        if [[ "$current_state" == "$desired_state" ]]; then
            echo "Instance '$instance_name' is now '$desired_state'"
            return 0
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            echo "Timeout waiting for instance '$instance_name' to reach '$desired_state'. Current state: '$current_state'"
            return 1
        fi
        
        echo "Instance '$instance_name' is '$current_state', waiting... (${elapsed}s elapsed)"
        sleep 10
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Group Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if security group exists
# Usage: security_group_exists "test-sg"
security_group_exists() {
    local sg_name="$1"
    local sg_count=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=$sg_name" \
        --query 'length(SecurityGroups)' \
        --output text 2>/dev/null)
    
    [[ "$sg_count" -gt 0 ]]
}

# Get security group ID by name
# Usage: get_security_group_id "test-sg"
get_security_group_id() {
    local sg_name="$1"
    aws ec2 describe-security-groups \
        --filters "Name=tag:Name,Values=$sg_name" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# EBS Volume Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if EBS volume exists
# Usage: volume_exists "test-volume"
volume_exists() {
    local volume_name="$1"
    local volume_count=$(aws ec2 describe-volumes \
        --filters "Name=tag:Name,Values=$volume_name" \
        --query 'length(Volumes)' \
        --output text 2>/dev/null)
    
    [[ "$volume_count" -gt 0 ]]
}

# Get volume state by name
# Usage: get_volume_state "test-volume"
get_volume_state() {
    local volume_name="$1"
    aws ec2 describe-volumes \
        --filters "Name=tag:Name,Values=$volume_name" \
        --query 'Volumes[0].State' \
        --output text 2>/dev/null
}

# Check if volume is attached to instance
# Usage: volume_attached_to_instance "test-volume" "test-athena"
volume_attached_to_instance() {
    local volume_name="$1"
    local instance_name="$2"
    
    local instance_id=$(get_instance_id "$instance_name")
    if [[ -z "$instance_id" || "$instance_id" == "None" ]]; then
        return 1
    fi
    
    local attached_instance=$(aws ec2 describe-volumes \
        --filters "Name=tag:Name,Values=$volume_name" \
        --query 'Volumes[0].Attachments[0].InstanceId' \
        --output text 2>/dev/null)
    
    [[ "$attached_instance" == "$instance_id" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# ECR Repository Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if ECR repository exists
# Usage: ecr_repository_exists "test-repo"
ecr_repository_exists() {
    local repo_name="$1"
    aws ecr describe-repositories \
        --repository-names "$repo_name" \
        &> /dev/null
}

# Get ECR repository URI
# Usage: get_ecr_repository_uri "test-repo"
get_ecr_repository_uri() {
    local repo_name="$1"
    aws ecr describe-repositories \
        --repository-names "$repo_name" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Elastic IP Validation Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if Elastic IP exists with specific tag
# Usage: eip_exists "test-eip"
eip_exists() {
    local eip_name="$1"
    local eip_count=$(aws ec2 describe-addresses \
        --filters "Name=tag:Name,Values=$eip_name" \
        --query 'length(Addresses)' \
        --output text 2>/dev/null)
    
    [[ "$eip_count" -gt 0 ]]
}

# Get Elastic IP address by name
# Usage: get_eip_address "test-eip"
get_eip_address() {
    local eip_name="$1"
    aws ec2 describe-addresses \
        --filters "Name=tag:Name,Values=$eip_name" \
        --query 'Addresses[0].PublicIp' \
        --output text 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Resource Cleanup Functions
# ─────────────────────────────────────────────────────────────────────────────

# Clean up all test resources (DANGEROUS - use with caution!)
# Usage: cleanup_test_resources "test"
cleanup_test_resources() {
    local env_prefix="$1"
    
    echo "⚠️  WARNING: This will destroy ALL resources with '$env_prefix' prefix!"
    echo "This includes:"
    echo "  - EC2 instances"
    echo "  - EBS volumes"
    echo "  - Security groups"
    echo "  - VPCs"
    echo "  - Elastic IPs"
    echo "  - ECR repositories"
    
    # In a real implementation, you'd want confirmation here
    # For now, just list what would be deleted
    echo ""
    echo "Resources that would be deleted:"
    echo "================================"
    
    echo "EC2 Instances:"
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${env_prefix}-*" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
        --output table 2>/dev/null || echo "  None found"
    
    echo ""
    echo "VPCs:"
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${env_prefix}-*" \
        --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || echo "  None found"
    
    echo ""
    echo "⚠️  Use 'terragrunt destroy' to actually remove resources"
}

# ─────────────────────────────────────────────────────────────────────────────
# Test Assertion Functions
# ─────────────────────────────────────────────────────────────────────────────

# Assert that a resource exists
# Usage: assert_resource_exists "vpc" "test-vpc"
assert_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local message="${3:-Expected $resource_type '$resource_name' to exist}"
    
    case "$resource_type" in
        "vpc")
            if ! vpc_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        "instance")
            if ! instance_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        "security_group")
            if ! security_group_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        "volume")
            if ! volume_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        "eip")
            if ! eip_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        "ecr")
            if ! ecr_repository_exists "$resource_name"; then
                echo "$message" >&2
                return 1
            fi
            ;;
        *)
            echo "Unknown resource type: $resource_type" >&2
            return 1
            ;;
    esac
}

# Assert that a resource does not exist
# Usage: assert_resource_not_exists "vpc" "test-vpc"
assert_resource_not_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local message="${3:-Expected $resource_type '$resource_name' to not exist}"
    
    if assert_resource_exists "$resource_type" "$resource_name" "" 2>/dev/null; then
        echo "$message" >&2
        return 1
    fi
}

# Assert instance is in specific state
# Usage: assert_instance_state "test-athena" "running"
assert_instance_state() {
    local instance_name="$1"
    local expected_state="$2"
    local message="${3:-Expected instance '$instance_name' to be in state '$expected_state'}"
    
    local actual_state=$(get_instance_state "$instance_name")
    if [[ "$actual_state" != "$expected_state" ]]; then
        echo "$message (actual: $actual_state)" >&2
        return 1
    fi
}

debug_message "AWS helper module loaded successfully" 