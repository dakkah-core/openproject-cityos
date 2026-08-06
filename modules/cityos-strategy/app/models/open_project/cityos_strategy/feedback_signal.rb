# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class FeedbackSignal < ActiveRecord::Base
      self.table_name = "cityos_strategy_feedback_signals"

      SOURCES = %w[analytics semantic-universe assurance operations].freeze
      DISPOSITIONS = %w[pending acknowledged actioned dismissed].freeze

      belongs_to :dispositioned_by, class_name: "User", optional: true

      validates :signal_id, presence: true, uniqueness: true
      validates :source, presence: true, inclusion: { in: SOURCES }
      validates :observation_time, presence: true
      validates :human_disposition, inclusion: { in: DISPOSITIONS }

      before_validation :generate_signal_id, on: :create

      scope :pending, -> { where(human_disposition: 'pending') }
      scope :actioned, -> { where(human_disposition: 'actioned') }

      def action!(user)
        update!(human_disposition: 'actioned', dispositioned_by: user, dispositioned_at: Time.current)
      end

      def dismiss!(user)
        update!(human_disposition: 'dismissed', dispositioned_by: user, dispositioned_at: Time.current)
      end

      private

      def generate_signal_id
        self.signal_id ||= "sig-#{SecureRandom.uuid}"
      end
    end
  end
end
