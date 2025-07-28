# Infrastructure Management System v2.0 - System Architecture

**Last Updated:** January 14, 2025 at 10:30 AM CST  
**Version:** 2.0.31  
**Purpose:** Document the system architecture, module relationships, and operational flow

---

## 🎯 **System Overview**

The Infrastructure Management System v2.0 is a **simplified, reliable orchestration layer** for Terraform/Terragrunt operations with the following key architectural principles:

### **Core Architectural Principles**
- **Single Source of Truth**: `modules.yml` defines all modules and their relationships
- **Unified Execution Strategy**: All operations use `terragrunt --all` with targeted exclusions
- **Centralized Flag Management**: All terragrunt flags handled by `execute_terragrunt()`
- **Protected Module Preservation**: Output files for protected modules preserved during destroy operations
- **Secrets Protection**: Modules with `destroy: false` have values cleared instead of infrastructure destroyed
- **Parallel Processing**: Multiple modules process outputs simultaneously for optimal performance
- **Automatic State Management**: State-changing operations automatically generate outputs
- **Consistent Environment Context**: All operations execute from correct environment directory 