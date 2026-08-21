---
trigger: always_on
description: Ruflo multi-agent orchestration and persistent memory guidelines for Avishkar.
---

# Ruflo Agent Guidelines for Avishkar

When responding to tasks in this project:
1. **Memory First**: Query Ruflo persistent memory (`ruflo memory search -q "<topic>"`) before starting complex features or architectural modifications.
2. **Memory Persistence**: Store key architectural decisions, service patterns, and newly implemented API/DB contracts into Ruflo memory (`ruflo memory store --key ... --value ...`).
3. **Structured Execution**: Follow the Ruflo intelligence pipeline:
   - **RETRIEVE**: Query codebase and memory for existing implementations and tests.
   - **JUDGE**: Formulate architecture, identify risks, and verify null-safety/error handling.
   - **DISTILL / EXECUTE**: Implement code with modular separation of concerns.
   - **CONSOLIDATE**: Verify with tests (`flutter test`) and record outcomes in memory.
4. **Specialized Roles**: Adopt specialized personas as needed (Flutter Coder, Unit Tester, Security Auditor, Code Reviewer) based on the task scope.
