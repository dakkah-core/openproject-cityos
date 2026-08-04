module OpenProject
  module CityOSGovernance
    # Prevents non-sync identities from writing to governance tables.
    module WriteGuard
      def self.included(base)
        base.before_save :reject_non_sync_writes
      end

      private

      def reject_non_sync_writes
        sync_identity = ENV['CITYOS_HELM_SYNC_IDENTITY']
        current_user = User.current

        unless current_user && current_user.login == sync_identity
          errors.add(:base, 'Governance records are read-only for non-sync identities')
          throw(:abort)
        end
      end
    end
  end
end
