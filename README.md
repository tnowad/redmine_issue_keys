# redmine_issue_keys

Jira-style issue keys for Redmine. Adds project-level prefixes and auto-generated keys that coexist with Redmine's native numeric issue IDs.

---

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Usage](#usage)
5. [Commit Message Integration](#commit-message-integration)
6. [REST API](#rest-api)
7. [Architecture](#architecture)
8. [Database Schema](#database-schema)
9. [Known Limitations](#known-limitations)
10. [Running Tests](#running-tests)
11. [Integration with redmine_dev_integration](#integration-with-redmine_dev_integration)

---

## Features

### Project Prefix Configuration
- Each project can define an `issue_key_prefix` (2–16 uppercase letters/digits, must start with a letter)
- Prefixes are normalized to uppercase and whitespace-stripped
- Case-insensitive uniqueness enforced across all projects
- Immutable once the project has issues (prevents key collisions)

### Automatic Issue Key Generation
- New issues receive a per-project sequential number: `{PREFIX}-{N}`
- `ProjectIssueCounter` table with row-level locking ensures thread-safe concurrent creation
- No key generated for projects without a prefix
- Continues from existing counters on migration — doesn't reset

### Dual URL Lookup
- `/browse/AUTH-1` — direct browse route via plugin routing
- `/issues/AUTH-1` — resolved by patched `ApplicationController#find_issue` (case-insensitive)
- `/issues/123` — numeric IDs continue to work unchanged

### Display Integration
- Issue headings: `Bug AUTH-1` instead of `Bug #123`
- `link_to_issue` helper shows issue keys when available
- `display_id` returns `issue_key.presence || "##{id}"`
- Issue list queries: `issue_key` as a filterable and sortable column

### Search Redirect
- Exact issue-key queries (`AUTH-1`) in the search box redirect directly to the issue
- Partial queries show normal search results
- API searches are not redirected (only web UI)

### Text Auto-Linking
- Plain-text issue keys in wiki pages, issue descriptions, and comments are auto-linked
- Skips existing `<a>`, `<pre>`, and `<code>` blocks
- Respects Redmine's existing auto-linking rules

### Commit Message Integration
- Extends Redmine's native changeset keyword system to support issue keys
- Supports `Setting.commit_ref_keywords` (default: `refs, references, IssueID`)
- Supports `Setting.commit_update_keywords` (e.g., `fixes, closes` for status changes)
- Mixed numeric (`#123`) and key (`AUTH-1`) references coexist in the same commit
- Time logging via `@2.5h` syntax when `commit_logtime_enabled` is set
- Cross-project issue key references when `commit_cross_project_ref` is enabled
- Wildcard keyword (`*`) matches any bare issue key without a keyword prefix

### REST API
- JSON: `"issue_key": "AUTH-1"`, `"project_issue_number": 1` alongside numeric `"id": 123`
- XML: `<issue_key>AUTH-1</issue_key>`, `<project_issue_number>1</project_issue_number>`
- Numeric `id` field is preserved — no API breakage

### Auto-Complete Integration
- Issue key search in repository and issue auto-complete fields
- Keys displayed alongside subjects in autocomplete dropdown

### Repository View Integration
- Clickable issue key links in commit messages on repository pages
- "Add related issue" form on revision pages accepts issue keys
- Breadcrumbs show issue key references in commit listings
- `linkify_repository_ref_issue_keys` helper auto-links keys in repository views

### Immutability Enforcement
- `issue_key` cannot change after issue creation
- `project_issue_number` cannot change after issue creation
- `issue_key_prefix` cannot change once the project has issues

### Database Backfill
- Migration adds `issue_key`, `project_issue_number` to existing issues
- Adds `issue_key_prefix` to existing projects with deterministic prefix generation
- `ProjectIssueCounter` records created from existing max issue numbers

---

## Installation

```sh
# From Redmine root:
bundle exec rake redmine:plugins:migrate NAME=redmine_issue_keys RAILS_ENV=production
```

**Requirements:**
- Redmine >= 6.0.0

---

## Quick Start

1. Run migrations
2. Edit a project: fill in **Issue key prefix** (e.g., `DEV`)
3. Create an issue — it becomes `DEV-1`
4. Visit `/browse/DEV-1` to jump directly to the issue
5. Use `DEV-1` in commit messages to link changesets to issues

---

## Usage

### Setting a Project Prefix

Edit the project and fill in the **Issue key prefix** field in the project information form. The field is injected via the `ProjectFormHook`.

**Validation rules:**
- 2–16 characters
- Must start with a letter (A–Z)
- Remaining characters: letters or digits (A–Z, 0–9)
- Case-insensitive uniqueness

**Example valid prefixes:** `DEV`, `AUTH`, `BUG`, `PROJ1`, `TICKET`

### Creating Issues

After setting a prefix, create issues normally. The first issue becomes `{PREFIX}-1`, the second `{PREFIX}-2`, etc.

```
Project: My Project (prefix: DEV)
  Issue 1 → DEV-1
  Issue 2 → DEV-2
  Issue 3 → DEV-3
```

### Browsing

| URL | Behavior |
|---|---|
| `/browse/DEV-1` | Direct browse — opens issue page |
| `/issues/DEV-1` | Resolved via key lookup |
| `/issues/dev-1` | Case-insensitive — same issue |
| `/issues/1` | Numeric ID still works |

### Searching

Type `DEV-1` in the search box and press Enter:

- **Exact match**: Redirected directly to the issue page
- **Partial match** (e.g., `DEV`): Shows normal search results
- **API searches**: Not redirected — normal API search behavior

### Issue Lists

Add the `issue_key` column to your issue query to see keys in the issue list. You can also filter by issue key (contains/equals search).

---

## Commit Message Integration

### Syntax

```
refs DEV-1 implemented login feature
fixes DEV-1 closes #resolve
DEV-1 #time 2.5h
refs DEV-1, DEV-2 and #3
```

### Keywords

Keywords are configured in Redmine's global settings (**Administration → Settings → Repositories**):

| Setting | Default | Purpose |
|---|---|---|
| Referencing keywords | `refs, references, IssueID` | Links changeset to issue |
| Fixing keywords | `fixes, closes` | Links + transitions issue status |
| Time logging | (checkbox) | Enables `@2.5h` time logging |
| Cross-project refs | (checkbox) | Allows keys from other projects |

### How it works

The plugin extends Redmine's `Changeset#scan_comment_for_issue_ids` to support issue keys alongside numeric references:

```
Ref: DEV-1, DEV-2                       → Links both issues
Fixes: DEV-1                            → Links + closes issue
Ref: DEV-1 @2.5h                        → Links + logs 2.5 hours
Ref: DEV-1 and #1                       → Links both key and numeric
DEV-1 (with wildcard keyword "*")       → Links (no keyword needed)
```

The patch maintains full compatibility with Redmine's native `#123` references and keyword system.

---

## REST API

### GET /issues/DEV-1.json

```json
{
  "issue": {
    "id": 123,
    "issue_key": "DEV-1",
    "project_issue_number": 1,
    "subject": "Fix login bug",
    ...
  }
}
```

### GET /issues/DEV-1.xml

```xml
<issue>
  <id>123</id>
  <issue_key>DEV-1</issue_key>
  <project_issue_number>1</project_issue_number>
  <subject>Fix login bug</subject>
  ...
</issue>
```

Both formats preserve the numeric `id` for API compatibility.

---

## Architecture

### Monkey Patches

All patches use `prepend` (safe Ruby module prepend — preserves `super` chain):

| Patch | What it adds |
|---|---|
| `ProjectPatch` | `issue_key_prefix` validation, normalization, immutability |
| `IssuePatch` | `issue_key`, `project_issue_number` generation; `find_by_issue_key`; `display_id` |
| `ApplicationControllerPatch` | Resolves `/issues/AUTH-1` via `find_issue` |
| `ApplicationHelperPatch` | Auto-links keys in text; `link_to_issue` uses `display_id` |
| `IssuesHelperPatch` | `issue_heading` shows key |
| `IssueQueryPatch` | `issue_key` as filterable/sortable column |
| `ChangesetPatch` | Scans commits for keys; links, fixes, logs time |
| `SearchControllerPatch` | Redirects exact key queries to issue page |
| `AutoCompletesControllerPatch` | Shows keys in autocomplete results |
| `RepositoriesControllerPatch` | Accepts keys in "add related issue" form |
| `RepositoriesHelperPatch` | Auto-links keys in repo views (breadcrumbs, commit listings) |
| `ProjectFormHook` | Adds prefix field to project form |

### Key Models

**`ProjectIssueCounter`** — Thread-safe per-project issue counter:

| Column | Notes |
|---|---|
| `project_id` | FK, unique |
| `counter` | Integer, incremented atomically with row lock |
| `updated_at` | |

Uses `with_lock` to ensure atomic increment even under concurrent issue creation.

### Routes

```
GET  /browse/:issue_key    → ApplicationController#find_issue (resolved from key)
GET  /issues/:issue_key    → ApplicationController#find_issue (resolved from key)
```

The `:issue_key` parameter is constrained to match `[A-Za-z][A-Za-z0-9]{1,15}-\d+`.

---

## Database Schema

### Columns added to existing tables

**`issues` table:**
| Column | Type | Notes |
|---|---|---|
| `issue_key` | string | `{PREFIX}-{N}`, immutable after create |
| `project_issue_number` | integer | Sequential per-project, immutable after create |
| `issue_key` index | `[issue_key]` | Unique, case-insensitive |

**`projects` table:**
| Column | Type | Notes |
|---|---|---|
| `issue_key_prefix` | string | Nullable, immutable once project has issues |

### New tables

**`project_issue_counters`:**
| Column | Notes |
|---|---|
| `project_id` | FK, unique |
| `counter` | Integer, atomically incremented |

---

## Known Limitations

1. **SQLite concurrent writes**: The `ProjectIssueCounter` uses row-level locking which works on PostgreSQL and MySQL but has limited concurrent write support on SQLite. Production deployments should use PostgreSQL or MySQL
2. **Bare issue keys without keywords**: A commit with just `DEV-1` (no `refs` keyword) will only link if `commit_ref_keywords` includes `*` (wildcard). This is consistent with Redmine's native behavior for `#123`
3. **Prefix changes blocked after issues exist**: Permits changing the prefix only when `issues.count == 0` — there is no key migration for existing issues
4. **No parent/child issue key propagation**: Sub-issues don't inherit or derive keys from parent issues

---

## Running Tests

```sh
# Full plugin test suite
bin/rails test plugins/redmine_issue_keys/test/

# Specific categories
bin/rails test plugins/redmine_issue_keys/test/unit/
bin/rails test plugins/redmine_issue_keys/test/functional/
bin/rails test plugins/redmine_issue_keys/test/integration/
bin/rails test:system

# Plugin rake task (does NOT run system tests)
bundle exec rake redmine:plugins:test NAME=redmine_issue_keys RAILS_ENV=test
```

### Test Database Setup

```sh
RAILS_ENV=test bin/rails db:migrate
bundle exec rake redmine:plugins:migrate NAME=redmine_issue_keys RAILS_ENV=test
```

### Test File Reference

| File | Type | Coverage |
|---|---|---|
| `test/unit/project_issue_keys_test.rb` | Unit | Prefix validation, normalization, uniqueness, immutability |
| `test/unit/issue_issue_keys_test.rb` | Unit | Key generation, sequencing, thread safety, immutability, lookup |
| `test/unit/issue_query_keys_test.rb` | Unit | Query column and filter |
| `test/unit/changeset_issue_keys_test.rb` | Unit | Commit scanning |
| `test/unit/backfill_issue_keys_test.rb` | Unit | Backfill rake task |
| `test/helpers/application_helper_test.rb` | Helper | Link parsing with keys |
| `test/functional/issues_controller_test.rb` | Functional | Key routing in IssuesController |
| `test/functional/projects_controller_test.rb` | Functional | Prefix CRUD |
| `test/functional/repositories_controller_test.rb` | Functional | Key references in repository |
| `test/functional/auto_completes_controller_test.rb` | Functional | Autocomplete with keys |
| `test/functional/search_controller_test.rb` | Functional | Search redirect |
| `test/integration/issues_test.rb` | Integration | HTTP requests with keys |
| `test/integration/routing/issues_test.rb` | Integration | Route assertions |
| `test/integration/api_test/issues_test.rb` | Integration | API responses |
| `test/integration/issue_key_commit_linking_test.rb` | Integration | Commit → issue linking, time logging, cross-project refs |
| `test/integration/issue_key_repository_integration_test.rb` | Integration | Repository integration |
| `test/system/issue_key_browse_smoke_test.rb` | System | Browser smoke test |
| `test/system/issue_key_full_workflow_test.rb` | System | Full prefix → issue → browse workflow |
| `test/system/issue_key_browse_search_test.rb` | System | Browse and search redirect |

---

## Integration with redmine_dev_integration

This plugin is the foundation for `redmine_dev_integration`'s issue linking capabilities:

```
redmine_issue_keys (this plugin)
├── Issue.find_by_issue_key("DEV-1") → returns issue
├── issue_key column on issues table
├── display_id returns "DEV-1" instead of "#123"

redmine_dev_integration (companion plugin)
├── IssueKeyExtractor — regex scans webhook data for "DEV-1" pattern
├── IssueLinker — calls Issue.find_by_issue_key to resolve matches
├── Webhook processors — link branches, commits, PRs, builds, deployments to issues
├── Smart commits — parse "#done", "#time", "#assign" from commit messages
└── Dev panel — displays linked development data on issue pages
```

Without this plugin, `redmine_dev_integration` stores all data but cannot link records to issues.
