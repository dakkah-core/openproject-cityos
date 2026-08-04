module OpenProject
  module CityOSGovernance
    # EvidenceLink — links a work package to external evidence artifacts
    # (tests, audits, runtime proof, screenshots) with content hashing
    # and freshness tracking.
    class EvidenceLink < ::ActiveRecord::Base
      self.table_name = 'cityos_evidence_links'

      belongs_to :work_package, class_name: 'WorkPackage', foreign_key: 'work_package_id'

      validates :work_package_id, :evidence_id, :evidence_uri, :evidence_hash, presence: true
      validates :proof_level, inclusion: {
        in: %w[none design-only source-local tested integration-proven target-runtime production-proven]
      }

      scope :by_proof_level, ->(level) { where(proof_level: level) }
      scope :expired, -> { where('expires_at < ?', Time.current) }
      scope :by_environment, ->(env) { where(environment: env) }
    end
  end
end
