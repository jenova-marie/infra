# 📝 Infrastructure Management System Changelog

All notable changes to the infrastructure management system will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - 2025-08-09 - Diagnostics refactor: extract vpc_routes logic

### Changed
- Moved `vpc_routes` diagnostics from `infra/diag.vpc.sh` into a dedicated module `infra/diag.vpc_routes.sh` for clearer separation of concerns and easier maintenance.
- Updated `infra/diag.vpc.sh` to delegate `vpc_routes` handling to `diag_vpc_routes_module` while keeping `vpcs` diagnostics local.

### Impact
- No behavior change. Command `infra diag <env>:vpc_routes` continues to work; implementation is now modular. Other modules unaffected.

---

