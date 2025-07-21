#!/usr/bin/env bats

# VPC Module Network ACL Integration Tests
# Tests the Network ACL functionality of the VPC module

load '../helpers/terraform_helper'
load '../helpers/aws_helper'
load '../helpers/test_helper'

@test "VPC module variables accept network_acls configuration" {
    # Test that the VPC module accepts network_acls configuration without errors
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Create a minimal terraform plan to validate variables
    run terraform validate
    [ "$status" -eq 0 ]
    
    # Check that network_acls variable is defined
    grep -q "network_acls" variables.tf
    [ "$?" -eq 0 ]
}

@test "Default NACL management is optional" {
    # Test that default NACL management is optional and defaults to false
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Verify that manage_default_network_acl is optional with default false
    grep -A 5 "manage_default_network_acl" variables.tf | grep -q "optional(bool, false)"
    [ "$?" -eq 0 ]
}

@test "Network ACL rules support all required fields" {
    # Test that NACL rule configuration supports all AWS NACL rule fields
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Check that rule configuration includes all necessary fields
    local required_fields=(
        "rule_number"
        "rule_action"
        "protocol"
        "cidr_block"
        "ipv6_cidr_block"
        "from_port"
        "to_port"
        "icmp_type"
        "icmp_code"
    )
    
    for field in "${required_fields[@]}"; do
        grep -q "$field" variables.tf
        [ "$?" -eq 0 ]
    done
}

@test "Dedicated NACL configuration per subnet type" {
    # Test that dedicated NACLs can be configured for any subnet type
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Check that subnet types support dedicated NACL configuration
    grep -A 10 "private = optional" variables.tf | grep -q "dedicated"
    [ "$?" -eq 0 ]
    
    grep -A 10 "public = optional" variables.tf | grep -q "dedicated"
    [ "$?" -eq 0 ]
    
    grep -A 10 "endpoint = optional" variables.tf | grep -q "dedicated"
    [ "$?" -eq 0 ]
}

@test "NACL resources are conditionally created" {
    # Test that NACL resources are only created when configured
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Check that default NACL resource has conditional count
    grep -A 5 'resource "aws_default_network_acl" "default"' main.tf | grep -q 'count.*manage_default_network_acl'
    [ "$?" -eq 0 ]
    
    # Check that dedicated NACLs use for_each
    grep -A 5 'resource "aws_network_acl" "dedicated"' main.tf | grep -q 'for_each'
    [ "$?" -eq 0 ]
}

@test "NACL outputs are properly defined" {
    # Test that all expected NACL outputs are defined
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    local expected_outputs=(
        "default_network_acl_id"
        "managed_default_network_acl_id"
        "managed_default_network_acl_arn"
        "network_acl_ids_by_type"
        "network_acl_arns_by_type"
        "network_acl_configurations"
    )
    
    for output in "${expected_outputs[@]}"; do
        grep -q "output \"$output\"" outputs.tf
        [ "$?" -eq 0 ]
    done
}

@test "Legacy compatibility outputs exist" {
    # Test that legacy NACL outputs are maintained for backward compatibility
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    local legacy_outputs=(
        "private_network_acl_id"
        "private_network_acl_arn"
        "public_network_acl_id"
        "public_network_acl_arn"
        "endpoint_network_acl_id"
        "endpoint_network_acl_arn"
    )
    
    for output in "${legacy_outputs[@]}"; do
        grep -q "output \"$output\"" outputs.tf
        [ "$?" -eq 0 ]
    done
}

@test "Environment wrapper passes NACL configuration" {
    # Test that the environment wrapper correctly passes NACL configuration
    cd "${PROJECT_ROOT}/src/envs/vpcs"
    
    # Check that main.tf passes network_acls to the module
    grep -A 20 'module "vpc"' main.tf | grep -q "network_acls.*each.value.network_acls"
    [ "$?" -eq 0 ]
    
    # Check that variables.tf includes network_acls definition
    grep -q "network_acls.*optional" variables.tf
    [ "$?" -eq 0 ]
}

@test "YAML configuration example is valid" {
    # Test that the example NACL configuration in dev VPC YAML is valid
    local yaml_file="${PROJECT_ROOT}/src/live/dev/vpcs/networks/vpc.yaml"
    
    # Check that YAML file exists and contains NACL configuration
    [ -f "$yaml_file" ]
    
    # Verify NACL configuration sections exist
    grep -q "network_acls:" "$yaml_file"
    [ "$?" -eq 0 ]
    
    grep -q "manage_default_network_acl:" "$yaml_file"
    [ "$?" -eq 0 ]
    
    grep -q "dedicated:" "$yaml_file"
    [ "$?" -eq 0 ]
    
    grep -q "ingress_rules:" "$yaml_file"
    [ "$?" -eq 0 ]
    
    grep -q "egress_rules:" "$yaml_file"
    [ "$?" -eq 0 ]
}

@test "NACL rule validation handles all protocols" {
    # Test that the module correctly handles different protocol types
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Check that the module can handle protocol "-1" (all protocols)
    grep -q 'protocol.*each.value.rule.protocol' main.tf
    [ "$?" -eq 0 ]
    
    # Verify that ICMP fields are handled
    grep -q 'icmp_type' main.tf
    [ "$?" -eq 0 ]
    
    grep -q 'icmp_code' main.tf
    [ "$?" -eq 0 ]
}

@test "NACL configuration supports IPv6" {
    # Test that IPv6 CIDR blocks are supported in NACL rules
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Check that IPv6 CIDR block is handled in rule creation
    grep -q 'ipv6_cidr_block.*lookup.*ipv6_cidr_block' main.tf
    [ "$?" -eq 0 ]
}

@test "Terraform plan succeeds with NACL configuration" {
    # Test that terraform plan succeeds with a complete NACL configuration
    if [ "$SKIP_AWS_TESTS" = "true" ]; then
        skip "AWS tests disabled"
    fi
    
    cd "${PROJECT_ROOT}/src/modules/vpc"
    
    # Create a test configuration
    cat > test_vpc_nacl.tf << EOF
variable "test_tags" {
  default = {
    Environment = "test"
    Terraform   = "true"
  }
}

module "test_vpc" {
  source = "./"
  
  vpc = {
    name = "test-vpc"
    cidr = "10.0.0.0/16"
    azs  = ["us-east-2a"]
    
    subnets = {
      private = ["10.0.1.0/24"]
      public  = ["10.0.101.0/24"]
    }
    
    network_acls = {
      manage_default_network_acl = true
      default_network_acl_ingress = []
      default_network_acl_egress = []
      
      private = {
        dedicated = true
        ingress_rules = [
          {
            rule_number = 100
            rule_action = "allow"
            protocol    = "tcp"
            cidr_block  = "10.0.99.0/24"
            from_port   = 22
            to_port     = 22
          }
        ]
        egress_rules = [
          {
            rule_number = 100
            rule_action = "allow"
            protocol    = "-1"
            cidr_block  = "0.0.0.0/0"
            from_port   = 0
            to_port     = 0
          }
        ]
        tags = {
          Purpose = "Test NACL"
        }
      }
    }
  }
  
  tags = var.test_tags
}
EOF
    
    # Run terraform plan
    terraform init > /dev/null 2>&1
    run terraform plan -var-file=terraform.tfvars.example -out=test.plan
    
    # Clean up
    rm -f test_vpc_nacl.tf test.plan
    
    [ "$status" -eq 0 ]
}

# Helper function to check if variable exists in terraform configuration
variable_exists() {
    local var_name="$1"
    local file="$2"
    grep -q "variable \"$var_name\"" "$file"
}

# Helper function to check if output exists in terraform configuration  
output_exists() {
    local output_name="$1"
    local file="$2"
    grep -q "output \"$output_name\"" "$file"
} 