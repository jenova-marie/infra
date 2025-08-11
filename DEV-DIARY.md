# DEV-DIARY

A concise, plain-English diary of noteworthy activity. Entries are grouped by calendar day and ordered ascending (earliest first). Documentation-only; no infra behavior implied by this file.

## 2025-07-07
- Unified output handling: centralized outputs with improved cleanup and logging. Respect user-supplied REFRESH. Refactor shutdown to focus on destroy → apply → output sequence. Set `LIVE_ROOT` via `LIVE_HOME`. Initial commit.

## 2025-07-09
- Introduced gateway instance tracking and automatic VPC reapply after gateway changes. Added query operation support and associated argument parsing. Added `mcp.json` and memory-bank project_id.

## 2025-07-11
- Consolidated `.cursor/mcp.json` documentation in `activeContext.md`.

## 2025-07-12
- Safer destroy cleanup: only remove actually destroyed modules; ignore protected/disabled.

## 2025-07-13
- Endpoint flags groundwork: added SSM/ECR flags and output handling for endpoints.

## 2025-07-14
- Enhanced endpoint flag support across group operations. Clean ops now remove Terraform state files when requested; improved safety checks and dry-run messages.

## 2025-07-16
- Argument parsing refactor for new flags; improved usability and examples.

## 2025-07-17
- `activeContext.md` updates reflecting added BATS core/test fixtures.

## 2025-07-19
- `activeContext.md` content refresh.

## 2025-07-20
- New flags for S3 and VPCs; conditional VPC apply in operations.

## 2025-07-21
- Document recent code changes; enhance cleanup with `--outputs`; refine known_hosts dry-run with clearer detection.

## 2025-07-23
- Secrets Protection System: `destroy: false` ensures secret infra lives; `--force` clears values only. Docs updated.

## 2025-07-25
- AWS secrets handling simplified (single `secrets.yml`), sturdier cache cleanup with race protection, and traversal-safe output validation.

## 2025-07-26
- Expanded FQDN coverage for known_hosts cleanup across `.cmd`, `.dev`, `.prod`.

## 2025-07-27
- Rename environment from `command` → `cmd` across docs. Misc short commit.

## 2025-07-29
- Global provider cache flag for 80–90% perf gain; add `.mutagen.yml` and ignore `.mutagen-session`. New `--no-outputs` clean behavior. Active context documentation of expanded BATS/test fixtures.

## 2025-07-31
- Sequential output generation for reliability. Integration test NACL CIDR adjustment. Added `list` operation for module management.

## 2025-08-01
- Add `.gitignore` rule for `activeContext.md`. KISS rewrite in AWS CLI module with real-time volume attach verification and sturdier instance ops. Clean operation refactor: `--outputs` flips default to preserve outputs; docs and structure updated.

## 2025-08-02
- Output generation performance: `--dependency-fetch-output-from-state` for 30–70% speedup where safe; docs bumped to v2.0.38.

## 2025-08-03
- Docs: clarify `env` parameter; merged PR #1 to sync that doc change.

## 2025-08-08
- Diagnostics expansion: add diag operation and display helpers; status hardened with jq fallbacks; lightweight `validate_aws_cli()` to avoid false negatives. Data-driven routing in status checks.

## 2025-08-09
- Safer arithmetic increments across scripts for portability. Added `aws_list_route_tables_for_pcx` and integrated into peering diagnostics.

## 2025-08-10
- Hostname/FQDN domain format update to `.dev.rso` across reboot and known_hosts cleanup paths.

## 2025-08-11
- This diary created: synthesized day-by-day narrative from full git history. Docs only.
