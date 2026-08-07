# cityos-strategy Migration Hazards (Wave 0 W0-4 record)

This directory holds the OpenProject-side `cityos-strategy` Rails migrations. Wave 0 W0-4 (2026-08-07) resolved the **structural** hazards (timestamp collisions, one missing table). A **semantic** hazard remains and needs owner decision — do not silently fix.

## Fixed by Wave 0 W0-4

### 1. Seven timestamp collisions (RESOLVED)

Seven pairs of migration files shared identical `YYYYMMDDHHMMSS` prefixes (`20260806000024`…`30`). Rails ordering is lexical, so the second file in each pair ran deterministically — but the collision meant future edits could reorder invisibly, and Rails' internal `schema_migrations` table stores only one row per prefix, so re-running with a different file at the same prefix would silently skip work.

Wave 0 renamed the alphabetically-second file in each pair to a fresh timestamp (`20260806000031`…`37`), preserving the lexical run order:

| Original prefix | Alphabetically-first (kept) | Alphabetically-second (renamed) | New prefix |
|---|---|---|---|
| 20260806000024 | `add_authority_fields_to_strategic_plans` | `create_cityos_strategy_engineering_service_bindings` | 20260806000031 |
| 20260806000025 | `add_stable_ids_and_program_join` | `create_cityos_strategy_coverage_baselines` | 20260806000032 |
| 20260806000026 | `create_cityos_strategy_plan_authorizations` | `create_governance_sync_receipts` | 20260806000033 |
| 20260806000027 | `create_cityos_strategy_release_candidates` | `create_strategy_event_outbox` | 20260806000034 |
| 20260806000028 | `create_cityos_strategy_feedback_signals` | `create_universal_strategy_models` | 20260806000035 |
| 20260806000029 | `create_cityos_strategy_globalization_bindings` | `create_release_evidence_and_operations_models` | 20260806000036 |
| 20260806000030 | `create_cityos_strategy_sync_cursors` | `create_executive_cockpit_and_ui_models` | 20260806000037 |

**Impact on existing databases.** ActiveRecord tracks applied migrations by version prefix. Any environment that already applied the collision-era migrations will have `schema_migrations` rows for `20260806000024`…`30` but NOT for `20260806000031`…`37`. On next `rails db:migrate`, Rails will **re-run** the renamed migrations against a schema that already has those tables. Migrations that use unadorned `create_table` will raise `PG::DuplicateTable`.

**Recommended one-time fix for existing environments** (dev + staging):

```sql
-- Move the collision-era version rows to the new prefixes:
UPDATE schema_migrations SET version = '20260806000031' WHERE version = '20260806000024' AND '20260806000031' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000032' WHERE version = '20260806000025' AND '20260806000032' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000033' WHERE version = '20260806000026' AND '20260806000033' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000034' WHERE version = '20260806000027' AND '20260806000034' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000035' WHERE version = '20260806000028' AND '20260806000035' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000036' WHERE version = '20260806000029' AND '20260806000036' NOT IN (SELECT version FROM schema_migrations);
UPDATE schema_migrations SET version = '20260806000037' WHERE version = '20260806000030' AND '20260806000037' NOT IN (SELECT version FROM schema_migrations);
-- Then re-insert the alphabetically-first-file rows if they were the ones tracked:
INSERT INTO schema_migrations (version)
VALUES ('20260806000024'),('20260806000025'),('20260806000026'),('20260806000027'),('20260806000028'),('20260806000029'),('20260806000030')
ON CONFLICT DO NOTHING;
```

Note: which file "won" the collision-era row depends on which file Rails saw first, which depends on `Dir.children` order — usually alphabetical, but not guaranteed across filesystems. Verify with `SELECT version FROM schema_migrations WHERE version BETWEEN '20260806000024' AND '20260806000030'` and treat the actual state as truth. For a fresh DB this is not applicable.

### 2. Missing table: `cityos_strategy_release_scope_bindings` (RESOLVED)

Model `open_project/cityos_strategy/release_scope_binding.rb` existed but no migration created its backing table. Added `20260806000038_create_cityos_strategy_release_scope_bindings.rb`.

## NOT fixed — needs owner decision (SEMANTIC HAZARD)

### 3. Migration 20260806000035 (`create_universal_strategy_models`) duplicates 3 existing tables with a DIFFERENT schema

Migration 35 (renamed from 28) creates 6 tables — 2 are unique (`plan_hierarchy`, `semantic_scope_bindings`) and 4 collide with tables created by other migrations, **using different columns**:

| Table | Migration 35 schema (universal_strategy_models) | Other migration's schema | Conflict |
|---|---|---|---|
| `cityos_strategy_coverage_baselines` | `stable_id`, `plan_id`, `dimension`, `current_value`, `target_value`, `transition_gap`, `unit`, `measured_at`, `target_date`, `status` | Migration 32 (create_cityos_strategy_coverage_baselines): `baseline_id`, `version`, `universe_version`, `included_node_set[]`, `node_set_hash`, `approval_ref`, `effective_from`/`until`, `superseded_by`, `owner_id`, `snapshot_data jsonb` | Whichever runs first "wins" via `PG::DuplicateTable` on the second (or the second is silently ignored under `if_not_exists: true`) |
| `cityos_strategy_globalization_bindings` | `stable_id`, `plan_id`, `country_cell`, `locale`, `currency`, `timezone`, `calendar_type`, `rtl_enabled`, `localization_overrides jsonb`, `status` | Migration 29: `binding_id`, `objective_id`, `initiative_id`, `country_cell`, `jurisdiction`, `language`, `currency`, `residency_zone`, `cultural_profile`, `accessibility_profile`, `fiscal_profile`, `identity_federation`, `applicable_from` | Same |
| `cityos_strategy_contribution_profiles` | `stable_id`, `initiative_id`, `profile_type`, `contribution_weight`, `evidence_summary`, `metrics jsonb`, `status` | Migration 29 (create_cityos_strategy_globalization_bindings) also creates `cityos_strategy_core_contribution_profiles` (note `_core_` prefix — different table): `profile_id`, `scope_node_id`, `cms/agora/nexus/tryton_contribution`, `shared_systems jsonb`, `notes` | Migration 35's `contribution_profiles` has no matching model; migration 29's `core_contribution_profiles` IS what `CoreContributionProfile` model expects. So migration 35's is orphan; leave it or drop it |
| `cityos_strategy_engineering_service_bindings` | `stable_id`, `bindable_type`, `bindable_id`, `engineering_service_id`, `role`, polymorphic | Migration 31 (renamed from 24-pair): `binding_id`, `objective_id`, `initiative_id`, `service_id`, direct references | Same schema conflict |

**Available options** (owner picks one; do NOT resolve silently):

- **Option A — DROP migration 35 entirely.** Its unique 2 tables (`plan_hierarchy`, `semantic_scope_bindings`) don't appear to be referenced by any model. Reverts the entire "universal_strategy_models" attempt.
- **Option B — Trim migration 35 to only its unique tables** (`plan_hierarchy`, `semantic_scope_bindings`) and delete the 4 duplicating `create_table` calls. Preserves the two novel table designs.
- **Option C — Adopt migration 35's schema as the winner** and drop the alternative migrations (31, 29, 32). Requires model rewrites to use `bindable_type`/`bindable_id` polymorphic + `stable_id` conventions. Largest surface change.
- **Option D — Alias/merge.** Rewrite migration 35 to `ALTER TABLE ... ADD COLUMN` the fields it wants onto the pre-existing tables from 29/31/32.

Wave 0 does not pick between these. This section stays until an owner decision lands via a new migration that supersedes migration 35 (`20260806000039_*` or later).

## Change log

- **2026-08-07** — File created. Wave 0 W0-4 resolved timestamp collisions + missing release_scope_bindings table. Semantic hazard around migration 35 remains open.
