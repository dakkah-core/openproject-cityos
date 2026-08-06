# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class ReleaseCandidate < ActiveRecord::Base
      self.table_name = "cityos_strategy_release_candidates"

      LIFECYCLE_STATES = %w[draft proposed evaluated approved promoted superseded].freeze

      validates :candidate_id, presence: true, uniqueness: true
      validates :version, presence: true
      validates :source_revision, presence: true
      validates :lifecycle_state, inclusion: { in: LIFECYCLE_STATES }

      before_validation :generate_candidate_id, on: :create

      scope :active, -> { where(lifecycle_state: %w[proposed evaluated approved]) }
      scope :promoted, -> { where(lifecycle_state: 'promoted') }

      def promoted?
        lifecycle_state == 'promoted'
      end

      def advance_state!(new_state)
        raise ArgumentError, "Invalid state: #{new_state}" unless LIFECYCLE_STATES.include?(new_state)
        update!(lifecycle_state: new_state)
      end

      private

      def generate_candidate_id
        self.candidate_id ||= "rel-#{SecureRandom.uuid}"
      end
    end
  end
end
