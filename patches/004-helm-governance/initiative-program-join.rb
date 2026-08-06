# frozen_string_literal: true

# Patch: Replace StrategicProgram has_many :initiatives, through: :portfolio
# with an explicit initiative_programs join table.
# Expansion-pack-01 §3.
#
# The core OpenProject model uses:
#   class StrategicProgram < ApplicationRecord
#     has_many :initiatives, through: :portfolio
#   end
#
# This loses relationship semantics. The fix introduces an explicit join model
# InitiativeProgram that supports: primary, supporting, dependent, impacted.
#
# Applied via: docker/entrypoint-cityos.sh
# Migration: db/migrate/YYYYMMDDHHMMSS_create_initiative_programs.rb

module CityOS
  module HelmGovernance
    module InitiativeProgramJoinFix
      def self.included(base)
        base.class_eval do
          # Remove the implicit through: :portfolio association
          if reflect_on_association(:initiatives)&.options&.dig(:through) == :portfolio
            # Replace with explicit join
            has_many :initiative_programs, dependent: :destroy
            has_many :initiatives, through: :initiative_programs do
              def primary
                where(initiative_programs: { relationship_type: "primary" })
              end

              def supporting
                where(initiative_programs: { relationship_type: "supporting" })
              end

              def dependent
                where(initiative_programs: { relationship_type: "dependent" })
              end

              def impacted
                where(initiative_programs: { relationship_type: "impacted" })
              end
            end
          end
        end
      end
    end
  end
end

# Join model for initiative ↔ program relationships.
# Must be loaded before the program model patch.
class InitiativeProgram < ApplicationRecord
  self.table_name = "initiative_programs"

  belongs_to :initiative
  belongs_to :strategic_program

  RELATIONSHIP_TYPES = %w[primary supporting dependent impacted].freeze

  validates :relationship_type, presence: true, inclusion: { in: RELATIONSHIP_TYPES }
  validates :initiative_id, uniqueness: { scope: [:strategic_program_id, :relationship_type] }

  scope :primary, -> { where(relationship_type: "primary") }
  scope :supporting, -> { where(relationship_type: "supporting") }
  scope :dependent, -> { where(relationship_type: "dependent") }
  scope :impacted, -> { where(relationship_type: "impacted") }
end

# Apply the patch
Rails.application.config.after_initialize do
  if defined?(StrategicProgram)
    StrategicProgram.include(CityOS::HelmGovernance::InitiativeProgramJoinFix)
  end
rescue StandardError => e
  Rails.logger.warn("HELM Governance: InitiativeProgram join patch failed: #{e.message}")
end
