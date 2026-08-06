# frozen_string_literal: true

# HEXP-0101: Add authority fields to strategic plans
# Replaces self-approval (approval_verified_at) with DWOS-verified projection model
class AddAuthorityFieldsToStrategicPlans < ActiveRecord::Migration[7.1]
  def up
    add_column :cityos_strategy_plans, :baseline_status, :integer, null: false, default: 0
    # enum: not_requested(0), pending(1), rejected(2), approved(3), revoked(4)
    add_column :cityos_strategy_plans, :baseline_requested_at, :datetime
    add_column :cityos_strategy_plans, :baseline_requested_by, :integer
    add_column :cityos_strategy_plans, :baseline_content_hash, :string

    add_column :cityos_strategy_plans, :approval_source_revision, :string
    add_column :cityos_strategy_plans, :approval_subject_hash, :string
    add_column :cityos_strategy_plans, :approval_projected_at, :datetime

    # Deprecate old self-approval field (keep for backward compatibility, remove in next migration)
    rename_column :cityos_strategy_plans, :approval_verified_at, :approval_verified_at_deprecated

    # Backfill: existing active plans get baseline approved (historical data only)
    execute <<-SQL
      UPDATE cityos_strategy_plans
      SET baseline_status = 3,
          baseline_content_hash = 'historical-migration',
          approval_projected_at = approval_verified_at_deprecated
      WHERE status = 3
    SQL
  end

  def down
    remove_column :cityos_strategy_plans, :baseline_status
    remove_column :cityos_strategy_plans, :baseline_requested_at
    remove_column :cityos_strategy_plans, :baseline_requested_by
    remove_column :cityos_strategy_plans, :baseline_content_hash
    remove_column :cityos_strategy_plans, :approval_source_revision
    remove_column :cityos_strategy_plans, :approval_subject_hash
    remove_column :cityos_strategy_plans, :approval_projected_at
    rename_column :cityos_strategy_plans, :approval_verified_at_deprecated, :approval_verified_at
  end
end
