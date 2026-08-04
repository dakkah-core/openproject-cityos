module OpenProject
  module CityOSGovernance
    # GovernanceProjection — read-only projection of UCL lifecycle state,
    # maturity (D/R/P), approval status, and gate position.
    #
    # Written only by the governed sync identity.
    # "Done ≠ approved" — the projection is advisory; authority is DWOS.
    class GovernanceProjection < ::ActiveRecord::Base
      include WriteGuard

      self.table_name = 'cityos_governance_projections'

      belongs_to :work_package, class_name: 'WorkPackage', foreign_key: 'work_package_id'

      validates :work_package_id, presence: true, uniqueness: true
      validates :ucl_status, presence: true
      validates :projection_hash, presence: true

      scope :by_gate, ->(gate_id) { where(gate_id: gate_id) }
      scope :by_owner_lane, ->(lane) { where(owner_lane: lane) }
      scope :blocked, -> { where(approval_state: %w[rejected]) }
      scope :stale, ->(threshold) { where('projected_at < ?', threshold) }
    end
  end
end
