# frozen_string_literal: true

# Patch: Enum predicate fixes for initiative and scenario lifecycle transitions.
# Expansion-pack-01 §3: Fix prefixed enum predicate defects.
#
# Problem: Some enum predicates use `has_status_` prefix inconsistently,
# or call `status_` methods without the standard Rails enum pattern.
# This causes lifecycle-transition guards to fail silently.
#
# Applied via: docker/entrypoint-cityos.sh
# Validated by: running initiative/scenario lifecycle transition tests

module CityOS
  module HelmGovernance
    module EnumPredicateFixes
      def self.included(base)
        base.class_eval do
          # Standardize enum accessors — strip any prefixed variants
          # that bypass the Rails enum :status definition.
          if respond_to?(:defined_enums) && defined_enums.key?("status")
            status_values = defined_enums["status"].keys

            status_values.each do |val|
              # Ensure standard predicate exists
              define_method("#{val}?") do
                self.status == val
              end unless method_defined?("#{val}?")

              # Remove any non-standard `has_status_#{val}?` variant
              bad_predicate = "has_status_#{val}?"
              if respond_to?(bad_predicate) && method(bad_predicate).owner != self.class
                # Method came from a concern or included module — override it
                define_method(bad_predicate) do
                  Rails.logger.warn(
                    "HELM Governance: deprecated predicate #{bad_predicate} called on #{self.class.name}##{id}. " \
                    "Use #{val}? instead."
                  )
                  self.status == val
                end
              end
            end
          end
        end
      end
    end

    # Lifecycle transition regression guard.
    # Wraps transition! to validate that source and target are both valid enum values.
    module LifecycleTransitionGuard
      def transition!(to_status, actor: nil, reason: nil)
        valid_statuses = self.class.defined_enums["status"]&.keys || []
        unless valid_statuses.include?(to_status.to_s)
          raise ArgumentError,
            "Invalid status transition to '#{to_status}' on #{self.class.name}##{id}. " \
            "Valid: #{valid_statuses.join(', ')}"
        end

        # Record transition for regression testing
        previous_status = status
        result = super(to_status)

        log_lifecycle_transition(previous_status, to_status, actor, reason) if respond_to?(:log_lifecycle_transition)

        result
      rescue NoMethodError => e
        if e.message.include?("transition!")
          raise NotImplementedError,
            "#{self.class.name} does not implement transition!. " \
            "Use update!(status: new_status) directly, or include LifecycleTransitionGuard."
        end
        raise
      end

      private

      def log_lifecycle_transition(from, to, actor, reason)
        Rails.logger.info(
          "HELM Lifecycle: #{self.class.name}##{id} #{from} → #{to} " \
          "by #{actor&.id || 'system'} #{reason ? "(#{reason})" : ''}"
        )
      end
    end
  end
end

# Apply the patches
Rails.application.config.after_initialize do
  %w[Initiative Scenario].each do |model_name|
    model = model_name.safe_constantize
    next unless model

    model.include(CityOS::HelmGovernance::EnumPredicateFixes) rescue nil
    model.include(CityOS::HelmGovernance::LifecycleTransitionGuard) rescue nil
  end
rescue StandardError => e
  Rails.logger.warn("HELM Governance: Enum predicate patch failed: #{e.message}")
end
