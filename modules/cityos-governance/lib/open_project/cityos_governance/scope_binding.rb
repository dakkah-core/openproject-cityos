module OpenProject
  module CityosGovernance
    # ScopeBindings — immutable linkage between an OpenProject work package
    # and a canonical WDR scope identity.
    #
    # Written only by the governed sync identity (cityos-helm-sync).
    # Read-only for all other users and API consumers.
    class ScopeBinding < ::ActiveRecord::Base
      include WriteGuard

      self.table_name = 'cityos_scope_bindings'

      belongs_to :work_package, class_name: 'WorkPackage', foreign_key: 'work_package_id'

      validates :work_package_id, presence: true, uniqueness: true
      validates :external_id, presence: true
      validates :source_revision, presence: true

      scope :by_system, ->(system_id) { where(system_id: system_id) }
      scope :by_capability, ->(capability_id) { where(capability_id: capability_id) }
      scope :stale, ->(threshold) { where('synced_at < ?', threshold) }
    end
  end
end
