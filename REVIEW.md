# Code Review Guidelines

This file provides guidelines for automated code review using Claude Code.

## Core Principle

**Follow the documentation exactly.** All test commands must come from `docs/` files - no improvised or modified commands.

---

## Path to Documentation Mapping

When files in these paths are changed, find and follow the corresponding documentation:

| Path Pattern | Documentation | Profile |
|--------------|---------------|---------|
| `cdc/flink/*` | `docs/CDC_Flink.md` | `--profile be --profile flink` |
| `cdc/risingwave/*` | `docs/CDC_RisingWave.md` | `--profile be --profile risingwave` |
| `bi/rill-project/*` | `docs/Dashboard_Rill.md` | `--profile be --profile rill` |
| `bi/<tool>/*` | `docs/Dashboard_<Tool>.md` | `--profile be --profile <tool>` |
| `orchestration/<tool>/*` | `docs/Orchestration_<Tool>.md` | `--profile be --profile <tool>` |
| `config/*` | Check affected profiles | `--profile be` or `--profile cn` |
| `scripts/*.sql` | Check which profile uses it | Corresponding profile |
| `docker-compose.yml` | All affected profiles | Detect from changes |
| `docs/*.md` | Validate commands in the doc | - |

> **Convention**: `<category>/<tool>/` maps to `docs/<Category>_<Tool>.md`

---

## Test Execution Flow

```
1. Analyze PR changed files
2. For each affected path:
   a. Find corresponding docs file from mapping table
   b. Read the documentation
   c. Execute commands in order:
      - docker compose up (with correct profiles)
      - Wait for healthy (timeout: 3 minutes)
      - Run test commands from docs (timeout: 5 minutes)
      - Capture results
      - docker compose down -v (always, even on failure)
3. If multiple profiles affected: test sequentially (port conflicts)
4. Report results to PR
5. Mark PR as Failed if any test failed
```

---

## Rules

### DO

- Execute commands exactly as written in docs
- Wait for services to be healthy before testing
- Capture error messages before cleanup
- Continue testing other profiles if one fails
- Clean up (down -v) after each profile test

### DO NOT

- Modify or improvise commands
- Skip documented steps
- Execute commands not in documentation
- Leave containers running after test

---

## Timeout Settings

| Phase | Timeout |
|-------|---------|
| Container startup (healthy) | 3 minutes |
| Test execution per profile | 5 minutes |
| Total workflow | 15 minutes |

---

## PR Comment Format

### All Tests Passed

```
## Test Results ✓

All tests passed.

| Profile | Documentation | Status |
|---------|---------------|--------|
| flink | docs/CDC_Flink.md | Passed |
```

### Some Tests Failed

```
## Test Results

| Profile | Documentation | Status | Error |
|---------|---------------|--------|-------|
| flink | docs/CDC_Flink.md | Passed | - |
| risingwave | docs/CDC_RisingWave.md | Failed | Connection refused on port 4566 |
```

---

## Documentation-Only Changes

When only `docs/*.md` files are changed:

1. Verify all commands in the document are syntactically correct
2. Check file paths referenced exist
3. Verify SQL syntax is valid
4. Check for consistency with current folder structure
5. No functional test needed (just validation)

---

## Adding New Profiles

To add a new testable profile:

1. Create folder: `<category>/<tool>/` (e.g., `bi/metabase/`, `orchestration/dbt/`, `orchestration/airflow/`)
2. Create documentation: `docs/<Category>_<Tool>.md`
3. Add profile to `docker-compose.yml`
4. Include in docs:
   - How to start (`docker compose --profile ... up -d`)
   - How to verify (health checks, test commands)
   - How to clean up (`docker compose ... down -v`)

The review system will automatically pick it up based on the naming convention.

---

## Permissions Required

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
  actions: read
```

**Self-hosted runner requirements:**
- Docker installed (user in docker group)
- MySQL client
- PostgreSQL client (psql)
- curl
