# 📝 Infrastructure Management System Changelog

All notable changes to the infrastructure management system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - 2025-08-11 - Clean enhancements and peering RTB details

### Added
- Clean action `--volumes` flag: when used, also removes `<module>/volumes.yml` for instance modules during clean operations.
- AWS helper `aws_list_route_tables_for_pcx(env, pcx_id)` to find route tables referencing a VPC peering connection.
- `diag.peering.sh` now prints associated route tables, detailed routes, and associations for each peering connection using existing display helpers.
- Developer diary (`DEV-DIARY.md`) generated from full git history with day-by-day narrative for quicker onboarding and review.

### Changed
- `clean.sh`: respects new `--volumes` flag and removes instance `volumes.yml` files when present.
- `args.sh`: parses `--volumes` for clean and exposes `is_volumes` helper.

### Impact
- Safer housekeeping and clearer diagnostics around peering-related routing. No breaking changes.
- Documentation quality improved via daily narrative in `DEV-DIARY.md`.

---

## [Unreleased] - 2025-08-09 - Diagnostics refactor: extract vpc_routes logic

### Changed
- Moved `vpc_routes` diagnostics from `infra/diag.vpc.sh` into a dedicated module `infra/diag.vpc_routes.sh` for clearer separation of concerns and easier maintenance.
- Updated `infra/diag.vpc.sh` to delegate `vpc_routes` handling to `diag_vpc_routes_module` while keeping `vpcs` diagnostics local.

### Impact
- No behavior change. Command `infra diag <env>:vpc_routes` continues to work; implementation is now modular. Other modules unaffected.

---
