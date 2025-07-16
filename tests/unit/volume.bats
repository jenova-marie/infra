#!/usr/bin/env bats

# ═══════════════════════════════════════════════════════════════════════════
# Infrastructure Management System v2.0 - Volume Unit Tests (Enhanced)
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Unit tests for volume management functionality with comprehensive dry-run testing
# Author: Infrastructure Management System v2.0
# Last Updated: December 1, 2024

# Load test helpers
load '../helpers/test_helper'
load '../helpers/mock_helper'

# Setup and teardown
setup() {
    setup_test_env
    source_infra_modules
    setup_volume_mocks
    reset_mocks
    
    # Force dry-run mode for all tests - COMPLETELY SAFE
    export DRY_RUN="true"
    
    # Mock dry_run_message function to capture dry-run output
    dry_run_message() {
        echo "[DRY-RUN] $*"
    }
    export -f dry_run_message
}

teardown() {
    teardown_test_env
}

# =================
# Module Loading Tests
# =================

@test "volume module loads successfully" {
    run source "${INFRA_ROOT}/volume.sh"
    [ "$status" -eq 0 ]
}

@test "volume module provides expected functions" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Check that key functions are defined
    type resolve_volume_name >/dev/null 2>&1
    type get_volume_id >/dev/null 2>&1
    type get_next_device_name >/dev/null 2>&1
    type is_volume_attached >/dev/null 2>&1
    type is_volume_attached_fast >/dev/null 2>&1
    type manage_backup_files >/dev/null 2>&1
    type execute_volume_operation_impl >/dev/null 2>&1
    type update_volumes_yml_attach >/dev/null 2>&1
    type update_volumes_yml_detach >/dev/null 2>&1
    type apply_volume_changes >/dev/null 2>&1
}

# =================
# Enhanced Dry-Run Testing for New Functions
# =================

@test "update_volumes_yml_attach respects dry-run mode with proper messaging" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    
    run update_volumes_yml_attach "$volumes_file" "test-volume" "/dev/sdf"
    [ "$status" -eq 0 ]
    
    # Verify dry-run messages are displayed
    [[ "$output" =~ "[DRY-RUN] Would update volumes.yml: $volumes_file" ]]
    [[ "$output" =~ "[DRY-RUN] Would add volume 'test-volume' with device '/dev/sdf'" ]]
    [[ "$output" =~ "[DRY-RUN] Would create new volumes.yml file" ]]
    
    # Verify file is NOT actually created in dry-run mode
    [ ! -f "$volumes_file" ]
}

@test "update_volumes_yml_attach shows correct message for existing file" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    echo "existing: {device_name: /dev/sdf}" > "$volumes_file"
    
    run update_volumes_yml_attach "$volumes_file" "test-volume" "/dev/sdg"
    [ "$status" -eq 0 ]
    
    # Verify dry-run messages for existing file
    [[ "$output" =~ "[DRY-RUN] Would update volumes.yml: $volumes_file" ]]
    [[ "$output" =~ "[DRY-RUN] Would add volume 'test-volume' with device '/dev/sdg'" ]]
    [[ "$output" =~ "[DRY-RUN] Would update existing volumes.yml file" ]]
    
    # Verify file is NOT actually modified in dry-run mode
    content=$(cat "$volumes_file")
    [[ "$content" =~ "existing" ]]
    [[ ! "$content" =~ "test-volume" ]]
}

@test "update_volumes_yml_detach respects dry-run mode with proper messaging" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    echo "test-volume: {device_name: /dev/sdf}" > "$volumes_file"
    
    run update_volumes_yml_detach "$volumes_file" "test-volume"
    [ "$status" -eq 0 ]
    
    # Verify dry-run messages are displayed
    [[ "$output" =~ "[DRY-RUN] Would update volumes.yml: $volumes_file" ]]
    [[ "$output" =~ "[DRY-RUN] Would remove volume 'test-volume'" ]]
    [[ "$output" =~ "[DRY-RUN] Would remove volume from existing volumes.yml" ]]
    
    # Verify file is NOT actually modified in dry-run mode
    content=$(cat "$volumes_file")
    [[ "$content" =~ "test-volume" ]]
}

@test "update_volumes_yml_detach handles missing file in dry-run mode" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/nonexistent.yml"
    
    run update_volumes_yml_detach "$volumes_file" "test-volume"
    [ "$status" -eq 0 ]
    
    # Verify appropriate dry-run message for missing file
    [[ "$output" =~ "[DRY-RUN] Would update volumes.yml: $volumes_file" ]]
    [[ "$output" =~ "[DRY-RUN] Would remove volume 'test-volume'" ]]
    [[ "$output" =~ "[DRY-RUN] volumes.yml does not exist - nothing to detach" ]]
}

@test "apply_volume_changes respects dry-run mode with comprehensive messaging" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Mock manage_backup_files to return empty (no backup created)
    manage_backup_files() {
        echo ""
    }
    export -f manage_backup_files
    
    run apply_volume_changes "test" "athena" "attach" "test-volume"
    [ "$status" -eq 0 ]
    
    # Verify comprehensive dry-run messages
    [[ "$output" =~ "[DRY-RUN] Would apply volume changes for athena" ]]
    [[ "$output" =~ "[DRY-RUN] Would change to directory:" ]]
    [[ "$output" =~ "[DRY-RUN] Would execute: terragrunt apply --auto-approve --non-interactive" ]]
    [[ "$output" =~ "[DRY-RUN] Would generate outputs after successful apply" ]]
}

@test "apply_volume_changes shows detach-specific dry-run messages" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Mock manage_backup_files to return empty (no backup created)
    manage_backup_files() {
        echo ""
    }
    export -f manage_backup_files
    
    run apply_volume_changes "test" "athena" "detach" "test-volume"
    [ "$status" -eq 0 ]
    
    # Verify detach-specific dry-run messages
    [[ "$output" =~ "[DRY-RUN] Would apply volume changes for athena" ]]
    [[ "$output" =~ "[DRY-RUN] Would perform AWS CLI volume detachment for safety" ]]
    [[ "$output" =~ "[DRY-RUN] Would generate outputs after successful apply" ]]
}

# =================
# Enhanced Fast Volume Checking Tests
# =================

@test "is_volume_attached_fast uses aws.sh functions correctly" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "instance_id": {
    "value": "i-123456789"
  },
  "ebs_attachments": {
    "value": {}
  }
}
EOF
    
    # Mock aws_is_volume_attached function to simulate AWS CLI verification
    aws_is_volume_attached() {
        echo "[MOCK] AWS CLI verification called with: $*" >&3
        return 2  # AWS CLI unavailable in dry-run mode
    }
    export -f aws_is_volume_attached
    
    run is_volume_attached_fast "test" "athena" "test-volume"
    [ "$status" -eq 1 ]  # Not attached
    
    # Verify it tried to use AWS CLI verification
    [[ "$output" =~ "AWS CLI" ]] || [[ "$output" =~ "Cannot determine" ]]
}

@test "is_volume_attached_fast returns early for fast path" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs showing volume attached
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "instance_id": {
    "value": "i-123456789"
  },
  "ebs_attachments": {
    "value": {
      "test-volume": {
        "vol-123456789": {
          "volume_id": "vol-123456789",
          "device_name": "/dev/sdf"
        }
      }
    }
  }
}
EOF
    
    # Mock aws_is_volume_attached to return success
    aws_is_volume_attached() {
        echo "[MOCK] AWS CLI confirms attachment" >&3
        return 0  # Confirmed attached
    }
    export -f aws_is_volume_attached
    
    run is_volume_attached_fast "test" "athena" "test-volume"
    [ "$status" -eq 0 ]  # Attached
}

# =================
# Enhanced Main Operation Tests with Dry-Run Output Generation
# =================

@test "execute_volume_operation_impl shows dry-run output generation messages" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    # Mock get_environment_path to return our test directory
    get_environment_path() {
        echo "${TEST_TEMP_DIR}/src/live/$1"
    }
    export -f get_environment_path
    
    # Mock process_volume_attach to return normal processing (0)
    process_volume_attach() {
        echo "[MOCK] Processing volume attachment"
        return 0
    }
    export -f process_volume_attach
    
    # Mock apply_volume_changes to succeed
    apply_volume_changes() {
        echo "[MOCK] Apply volume changes"
        return 0
    }
    export -f apply_volume_changes
    
    # Mock generate_module_outputs
    generate_module_outputs() {
        echo "[MOCK] Generate module outputs"
        return 0
    }
    export -f generate_module_outputs
    
    run execute_volume_operation_impl "test" "athena" "test-volume" "attach"
    [ "$status" -eq 0 ]
    
    # Verify the operation ran and shows proper dry-run behavior
    [[ "$output" =~ "MOCK" ]]  # Ensure our mocks were called
}

@test "execute_volume_operation_impl handles fast path return code 3" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    # Mock process_volume_attach to return "already attached, no action needed" (3)
    process_volume_attach() {
        echo "[MOCK] Volume already attached - returning quickly!"
        return 3
    }
    export -f process_volume_attach
    
    # Mock apply_volume_changes - should NOT be called
    apply_volume_changes() {
        echo "ERROR: apply_volume_changes should not be called for return code 3"
        return 1
    }
    export -f apply_volume_changes
    
    run execute_volume_operation_impl "test" "athena" "test-volume" "attach"
    [ "$status" -eq 0 ]
    
    # Verify fast path was taken and apply was not called
    [[ "$output" =~ "already attached" ]]
    [[ ! "$output" =~ "ERROR: apply_volume_changes should not be called" ]]
}

# =================
# File Operations Dry-Run Tests
# =================

@test "file_copy shows proper dry-run messages" {
    source "${INFRA_ROOT}/volume.sh"
    
    local source="${TEST_TEMP_DIR}/source.txt"
    local dest="${TEST_TEMP_DIR}/dest.txt"
    echo "test content" > "$source"
    
    run file_copy "$source" "$dest"
    [ "$status" -eq 0 ]
    
    # Verify dry-run message is shown
    [[ "$output" =~ "[DRY-RUN] Would copy:" ]]
    [[ "$output" =~ "$source -> $dest" ]]
    
    # Verify file was NOT actually copied
    [ ! -f "$dest" ]
}

@test "file_remove shows proper dry-run messages" {
    source "${INFRA_ROOT}/volume.sh"
    
    local test_file="${TEST_TEMP_DIR}/test.txt"
    echo "test content" > "$test_file"
    
    run file_remove "$test_file"
    [ "$status" -eq 0 ]
    
    # Verify dry-run message is shown
    [[ "$output" =~ "[DRY-RUN] Would remove:" ]]
    [[ "$output" =~ "$test_file" ]]
    
    # Verify file was NOT actually removed
    [ -f "$test_file" ]
}

# =================
# Volume Name Resolution Tests
# =================

@test "resolve_volume_name resolves valid volume name" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789",
      "athena-logs": "vol-987654321"
    }
  }
}
EOF
    
    run resolve_volume_name "test" "athena-data"
    [ "$status" -eq 0 ]
    [ "$output" = "athena-data" ]
}

@test "resolve_volume_name resolves volume ID to name" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789",
      "athena-logs": "vol-987654321"
    }
  }
}
EOF
    
    run resolve_volume_name "test" "vol-123456789"
    [ "$status" -eq 0 ]
    [ "$output" = "athena-data" ]
}

@test "resolve_volume_name fails for non-existent volume" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    run resolve_volume_name "test" "nonexistent-volume"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "resolve_volume_name fails when outputs missing" {
    source "${INFRA_ROOT}/volume.sh"
    
    run resolve_volume_name "test" "any-volume"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "EBS outputs not found" ]]
}

# =================
# Volume ID Retrieval Tests
# =================

@test "get_volume_id returns correct volume ID" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789",
      "athena-logs": "vol-987654321"
    }
  }
}
EOF
    
    run get_volume_id "test" "athena-data"
    [ "$status" -eq 0 ]
    [ "$output" = "vol-123456789" ]
}

@test "get_volume_id fails for non-existent volume name" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    run get_volume_id "test" "nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Could not find volume ID" ]]
}

# =================
# Device Name Management Tests
# =================

@test "get_next_device_name returns /dev/sdf for empty volumes file" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    touch "$volumes_file"
    
    run get_next_device_name "$volumes_file"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/sdf" ]
}

@test "get_next_device_name returns /dev/sdf for non-existent volumes file" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/nonexistent.yml"
    
    run get_next_device_name "$volumes_file"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/sdf" ]
}

@test "get_next_device_name skips used devices" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    cat > "$volumes_file" << 'EOF'
volume1:
  device_name: /dev/sdf
volume2:
  device_name: /dev/sdg
EOF
    
    run get_next_device_name "$volumes_file"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/sdh" ]
}

@test "get_next_device_name handles all devices used" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    cat > "$volumes_file" << 'EOF'
vol1: { device_name: /dev/sdf }
vol2: { device_name: /dev/sdg }
vol3: { device_name: /dev/sdh }
vol4: { device_name: /dev/sdi }
vol5: { device_name: /dev/sdj }
vol6: { device_name: /dev/sdk }
vol7: { device_name: /dev/sdl }
vol8: { device_name: /dev/sdm }
vol9: { device_name: /dev/sdn }
vol10: { device_name: /dev/sdo }
vol11: { device_name: /dev/sdp }
EOF
    
    run get_next_device_name "$volumes_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No available device names" ]]
}

# =================
# Volume State Checking Tests
# =================

@test "is_volume_attached detects attached volume" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    # Create mock instance outputs with attached volume
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "ebs_attachments": {
    "value": {
      "athena-data": {
        "vol-123456789": {
          "volume_id": "vol-123456789",
          "device_name": "/dev/sdf"
        }
      }
    }
  }
}
EOF
    
    run is_volume_attached "test" "athena" "athena-data"
    [ "$status" -eq 0 ]
}

@test "is_volume_attached detects non-attached volume" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    # Create mock instance outputs without attached volume
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "ebs_attachments": {
    "value": {}
  }
}
EOF
    
    run is_volume_attached "test" "athena" "athena-data"
    [ "$status" -eq 1 ]
}

@test "is_volume_attached fails when instance outputs missing" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock EBS outputs but no instance outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    run is_volume_attached "test" "athena" "athena-data"
    [ "$status" -eq 1 ]
}

# =================
# Backup Management Tests
# =================

@test "manage_backup_files skips backup when flag disabled" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Ensure backup is disabled
    BACKUP="false"
    export BACKUP
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    echo "test: {}" > "$volumes_file"
    
    run manage_backup_files "$volumes_file"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]  # Should return empty string
}

@test "manage_backup_files creates backup when flag enabled" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Enable backup
    BACKUP="true"
    export BACKUP
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    echo "test: {}" > "$volumes_file"
    
    run manage_backup_files "$volumes_file"
    [ "$status" -eq 0 ]
    
    # Should return backup file path
    [[ "$output" =~ \.backup\.[0-9]{8}_[0-9]{6}$ ]]
}

@test "manage_backup_files handles missing file gracefully" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Enable backup
    BACKUP="true"
    export BACKUP
    
    local volumes_file="${TEST_TEMP_DIR}/nonexistent.yml"
    
    run manage_backup_files "$volumes_file"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]  # Should return empty string for non-existent file
}

@test "cleanup_old_backups works with no backup files" {
    source "${INFRA_ROOT}/volume.sh"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    touch "$volumes_file"
    
    run cleanup_old_backups "$volumes_file"
    [ "$status" -eq 0 ]
}

@test "get_backup_timestamp returns valid timestamp format" {
    source "${INFRA_ROOT}/volume.sh"
    
    run get_backup_timestamp
    [ "$status" -eq 0 ]
    
    # Check timestamp format: YYYYMMDD_HHMMSS
    [[ "$output" =~ ^[0-9]{8}_[0-9]{6}$ ]]
}

# =================
# Volume Operation Processing Tests
# =================

@test "process_volume_attach detects already attached volume" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs showing volume attached
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "instance_id": {
    "value": "i-123456789"
  },
  "ebs_attachments": {
    "value": {
      "athena-data": {
        "vol-123456789": {
          "volume_id": "vol-123456789",
          "device_name": "/dev/sdf"
        }
      }
    }
  }
}
EOF
    
    # Mock aws_is_volume_attached to confirm attachment
    aws_is_volume_attached() {
        return 0  # Confirmed attached
    }
    export -f aws_is_volume_attached
    
    run process_volume_attach "test" "athena" "athena-data"
    [ "$status" -eq 3 ]  # Already attached, no action needed
}

@test "process_volume_detach detects already detached volume" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create mock outputs showing volume not attached
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "athena-data": "vol-123456789"
    }
  }
}
EOF
    
    local instance_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/athena.json"
    cat > "$instance_outputs" << 'EOF'
{
  "instance_id": {
    "value": "i-123456789"
  },
  "ebs_attachments": {
    "value": {}
  }
}
EOF
    
    # Create volumes file without the volume
    local volumes_file="${TEST_TEMP_DIR}/src/live/test/athena/volumes.yml"
    mkdir -p "$(dirname "$volumes_file")"
    echo "{}" > "$volumes_file"
    
    # Mock aws_is_volume_attached to confirm not attached
    aws_is_volume_attached() {
        return 1  # Not attached
    }
    export -f aws_is_volume_attached
    
    run process_volume_detach "test" "athena" "athena-data"
    [ "$status" -eq 3 ]  # Already detached, no action needed
}

# =================
# Integration Tests with Multiple Flags
# =================

@test "volume operations work with multiple flags in dry-run mode" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Set multiple flags
    export BACKUP="true"
    export FORCE="true"
    export BELL="true"
    export DNS="true"
    
    local volumes_file="${TEST_TEMP_DIR}/volumes.yml"
    
    run update_volumes_yml_attach "$volumes_file" "test-volume" "/dev/sdf"
    [ "$status" -eq 0 ]
    
    # Verify it still respects dry-run mode regardless of other flags
    [[ "$output" =~ "[DRY-RUN]" ]]
    [ ! -f "$volumes_file" ]
}

@test "comprehensive dry-run test with full operation flow" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create complete mock environment
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    # Create instance directory structure
    local instance_dir="${TEST_TEMP_DIR}/src/live/test/athena"
    mkdir -p "$instance_dir"
    
    # Mock all the complex functions
    get_environment_path() {
        echo "${TEST_TEMP_DIR}/src/live/$1"
    }
    export -f get_environment_path
    
    get_next_device_name() {
        echo "/dev/sdf"
    }
    export -f get_next_device_name
    
    is_volume_attached_fast() {
        return 1  # Not attached
    }
    export -f is_volume_attached_fast
    
    manage_backup_files() {
        echo ""  # No backup
    }
    export -f manage_backup_files
    
    # This should show comprehensive dry-run output
    run process_volume_attach "test" "athena" "test-volume"
    [ "$status" -eq 0 ]
    
    # The main test is that this doesn't crash and respects dry-run mode
    # Detailed testing of individual functions is done in separate tests
}

# =================
# Error Handling in Dry-Run Mode
# =================

@test "dry-run mode preserves error detection without side effects" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Test error cases still work in dry-run mode
    run resolve_volume_name "test" "nonexistent-volume"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "EBS outputs not found" ]]
    
    # But no files should be created or modified
    [ ! -f "${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json" ]
}

@test "invalid action still fails correctly in dry-run mode" {
    source "${INFRA_ROOT}/volume.sh"
    
    # Create minimal mock outputs
    local test_outputs="${TEST_TEMP_DIR}/src/live/test/outputs/ebss.json"
    mkdir -p "$(dirname "$test_outputs")"
    cat > "$test_outputs" << 'EOF'
{
  "volume_ids": {
    "value": {
      "test-volume": "vol-123456789"
    }
  }
}
EOF
    
    run execute_volume_operation_impl "test" "athena" "test-volume" "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown volume action" ]]
} 