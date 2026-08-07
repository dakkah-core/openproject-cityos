# frozen_string_literal: true

# Wave 1 W1-4 (2026-08-07): new ActiveRecord model wrapping the
# cityos_strategy_machine_identities table (created by migration
# 20260806000036_create_release_evidence_and_operations_models.rb HEXP-0704).
#
# The table existed but no model wrapped it, so token verification had no
# ORM-shaped surface to sit behind. This model is the anchor for the new
# Cityos::Strategy::ApiAuthorization concern.
#
# Trust model:
#   * Tokens are stored as SHA-256 hashes (`token_hash`). Never store the raw
#     token; issue it once at rotation and expect the caller to keep it.
#   * `status = "active"` and `(expires_at IS NULL OR expires_at > now())` is
#     the sole "usable now" predicate.
#   * `scopes` is an array of dotted-namespace strings (e.g. "strategy.coverage",
#     "strategy.authorize"). Route-level access requires the scope declared
#     via `requires_api_scope` in the controller.
#   * `last_used_at` is stamped on every successful auth. Not a security
#     mechanism — an operability signal for rotation policy.
module OpenProject
  module CityosStrategy
    class MachineIdentity < ApplicationRecord
      self.table_name = "cityos_strategy_machine_identities"

      validates :stable_id, presence: true, uniqueness: true
      validates :name, presence: true
      validates :token_hash, presence: true
      validates :status, presence: true

      scope :active_now, -> {
        where(status: "active").where("expires_at IS NULL OR expires_at > ?", Time.current)
      }

      # Currently usable: status active AND (no expiry OR expiry in the future).
      def active?
        status == "active" && (expires_at.nil? || expires_at > Time.current)
      end

      # Fail-safe scope check. `scopes` is an array column; treats nil as empty.
      def has_scope?(scope)
        Array(scopes).include?(scope.to_s)
      end

      # Compute the storage form of a raw token (SHA-256 hex).
      def self.hash_token(raw_token)
        return nil if raw_token.blank?
        Digest::SHA256.hexdigest(raw_token)
      end

      # Look up an active identity by raw token. Returns nil for missing,
      # unknown, expired, or non-active tokens. Never raises for missing input.
      def self.authenticate_token(raw_token)
        hashed = hash_token(raw_token)
        return nil if hashed.nil?
        identity = find_by(token_hash: hashed)
        identity && identity.active? ? identity : nil
      end
    end
  end
end
