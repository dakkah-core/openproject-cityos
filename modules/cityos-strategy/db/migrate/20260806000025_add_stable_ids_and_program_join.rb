# frozen_string_literal: true

# HEXP-0104: Add stable_id to strategy records for cross-system identity
# HEXP-0105: Add direct program_id to initiatives (replace through: :portfolio join)
class AddStableIdsAndProgramJoinToStrategyRecords < ActiveRecord::Migration[7.1]
  def up
    # ── HEXP-0104: Stable IDs ────────────────────────────────────────
    add_column :cityos_strategy_plans, :stable_id, :string
    add_column :cityos_strategy_initiatives, :stable_id, :string
    add_column :cityos_strategy_objectives, :stable_id, :string

    add_index :cityos_strategy_plans, :stable_id, unique: true
    add_index :cityos_strategy_initiatives, :stable_id, unique: true
    add_index :cityos_strategy_objectives, :stable_id, unique: true

    # Backfill stable_id for existing records
    execute <<-SQL
      UPDATE cityos_strategy_plans
      SET stable_id = 'helm-plan-' || id::text
      WHERE stable_id IS NULL;

      UPDATE cityos_strategy_initiatives
      SET stable_id = 'helm-initiative-' || id::text
      WHERE stable_id IS NULL;

      UPDATE cityos_strategy_objectives
      SET stable_id = 'helm-objective-' || id::text
      WHERE stable_id IS NULL;
    SQL

    # ── HEXP-0105: Direct initiative → program join ───────────────────
    add_reference :cityos_strategy_initiatives, :program,
                  foreign_key: { to_table: :cityos_strategy_programs }

    # Migrate existing program relationships (via portfolio)
    execute <<-SQL
      UPDATE cityos_strategy_initiatives ini
      SET program_id = (
        SELECT prog.id
        FROM cityos_strategy_programs prog
        JOIN cityos_strategy_portfolios port ON port.id = prog.portfolio_id
        WHERE port.id = ini.portfolio_id
        LIMIT 1
      )
      WHERE ini.portfolio_id IS NOT NULL
        AND ini.program_id IS NULL;
    SQL
  end

  def down
    remove_column :cityos_strategy_plans, :stable_id
    remove_column :cityos_strategy_initiatives, :stable_id
    remove_column :cityos_strategy_objectives, :stable_id
    remove_reference :cityos_strategy_initiatives, :program
  end
end
