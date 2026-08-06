# 004 — HELM Governance: Self-Approval Defect Fixes

## Purpose

Apply the expansion-pack-01 §3 corrections to prevent HELM from self-approving
strategy decisions. HELM owns strategy and planning; DWOS owns approval creation.

## Applied Corrections

### 1. StrategicPlan#baseline! — No self-verification
- `strategic-plan-baseline.rb` overwrites `#baseline!` to publish a DWOS-bound
  command instead of writing `approval_verified_at`.
- `approval_verified_at` column is deprecated; `approval_ref` replaces it.

### 2. Enum predicate defects
- `enum-predicate-fixes.rb` fixes inconsistent prefixed enum predicates in
  initiative and scenario services.
- Adds lifecycle-transition regression guards.

### 3. Initiative-Program explicit join
- `initiative-program-join.rb` replaces the `has_many :initiatives, through: :portfolio`
  association with an explicit `initiative_programs` join table supporting
  primary, supporting, dependent, and impacted relationships.

### 4. Stable IDs
- Adds `stable_id` column generation for all strategy record families.
- Prohibits title-based reconciliation.

### 5. Read permissions
- Strategy/investment reads restricted from broadly public to explicit
  project/portfolio roles and classification-aware policy.

## Integration Points

- DWOS approval service: `http://dwos-runtime:3051/api/governance/approvals`
- Work Control command: `http://work-control:3065/api/commands`
- HELM bridge sync: validates that approvals exist before marking "verified"

## Validation

```bash
# After applying patches, verify no self-approval paths:
grep -r "approval_verified_at" app/models/strategic_plan.rb && echo "FAIL: self-verification still present" || echo "PASS"
grep -r "self.baseline!" app/services/strategic_plans/ && echo "FAIL: self-baseline still present" || echo "PASS"
```

## Non-Claims
- These patches are development/staging fixes, not production-hardened.
- DWOS integration requires the DWOS runtime to be healthy.
- Patches must be re-validated after each OpenProject upgrade.
