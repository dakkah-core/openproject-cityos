# frozen_string_literal: true

# Wave 2 W2-5 (2026-08-07): add `graph_content_hash` to strategic plans.
#
# The Wave 0 workflow verified as P0.4 (CONFIRMED with correction —
# stronger than initial recon) that `compute_content_hash` hashed only
# 4 plan columns via non-canonical `Hash#to_s` and 0 of 16 child
# associations. Any approval issued against a snapshot's content_hash
# stayed "valid" even after arbitrary child mutation (silent authority
# decay across the strategy graph).
#
# This migration adds a NEW `graph_content_hash` column populated by the
# NEW `StrategicPlan#compute_graph_content_hash` method. The prior
# `baseline_content_hash` column is preserved for backward compat during
# the migration window — Wave 3 will drop the old semantics once no
# outstanding approvals reference the 4-column hash.
class AddGraphContentHashToStrategicPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :cityos_strategy_plans, :graph_content_hash, :string
    add_index :cityos_strategy_plans, :graph_content_hash
  end
end
