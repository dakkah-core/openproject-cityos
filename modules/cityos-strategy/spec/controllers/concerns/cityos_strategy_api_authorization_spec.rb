# frozen_string_literal: true

# Wave 1 W1-4 regression spec.
#
# Run in the submodule Rails env:
#   cd submodules/cityos-helm && bundle exec rspec modules/cityos-strategy/spec/controllers/concerns/cityos_strategy_api_authorization_spec.rb
#
# These specs guard the specific defects the 14-agent workflow confirmed as
# P0.2 (all 6 controllers returned literal `true`) — if the concern gets
# unwired or the token check falls through to a pass-through, one of these
# fails immediately.

require "rails_helper"

RSpec.describe Cityos::Strategy::ApiAuthorization, type: :controller do
  # Tiny anonymous controller to exercise the concern in isolation.
  controller(ApplicationController) do
    include Cityos::Strategy::ApiAuthorization
    skip_before_action :verify_authenticity_token
    requires_api_scope "strategy.coverage"

    def index
      render json: { ok: true, actor: current_machine_identity&.name }
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  let(:raw_token) { "raw-token-#{SecureRandom.hex(16)}" }
  let(:token_hash) { Digest::SHA256.hexdigest(raw_token) }
  let!(:identity) {
    OpenProject::CityosStrategy::MachineIdentity.create!(
      stable_id: "mi-test-#{SecureRandom.hex(4)}",
      name: "test-machine",
      token_hash: token_hash,
      scopes: %w[strategy.coverage],
      status: "active"
    )
  }

  describe "REGRESSION guards against P0.2 (literal-`true` auth bypass)" do
    it "rejects requests with no auth header at all" do
      get :index
      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["detail"]).to match(/missing strategy API token/i)
    end

    it "rejects a bogus token" do
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = "not-a-real-token"
      get :index
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["detail"]).to match(/invalid, expired, or revoked/i)
    end

    it "rejects a token whose identity is status=revoked" do
      identity.update!(status: "revoked")
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = raw_token
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a token whose identity has expired" do
      identity.update!(expires_at: 1.hour.ago)
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = raw_token
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a token that authenticates but lacks the required scope" do
      identity.update!(scopes: %w[strategy.read])
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = raw_token
      get :index
      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["required_scope"]).to eq("strategy.coverage")
    end
  end

  describe "positive path" do
    it "allows a token that is active and holds the required scope" do
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = raw_token
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("ok" => true, "actor" => "test-machine")
    end

    it "accepts a token via Authorization: Bearer as a fallback" do
      request.env["HTTP_AUTHORIZATION"] = "Bearer #{raw_token}"
      get :index
      expect(response).to have_http_status(:ok)
    end

    it "stamps last_used_at on success" do
      identity.update!(last_used_at: nil)
      request.env["HTTP_X_CITYOS_STRATEGY_TOKEN"] = raw_token
      get :index
      expect(response).to have_http_status(:ok)
      expect(identity.reload.last_used_at).to be_present
    end
  end
end

RSpec.describe OpenProject::CityosStrategy::MachineIdentity, type: :model do
  describe ".authenticate_token" do
    it "returns nil for blank input" do
      expect(described_class.authenticate_token(nil)).to be_nil
      expect(described_class.authenticate_token("")).to be_nil
    end

    it "returns nil for an unknown token" do
      expect(described_class.authenticate_token("nope")).to be_nil
    end

    it "returns nil for a known token whose identity is revoked" do
      raw = "test-raw-token"
      described_class.create!(
        stable_id: "mi-rev",
        name: "revoked",
        token_hash: Digest::SHA256.hexdigest(raw),
        status: "revoked"
      )
      expect(described_class.authenticate_token(raw)).to be_nil
    end

    it "returns the identity for a valid active token" do
      raw = "another-raw-token"
      identity = described_class.create!(
        stable_id: "mi-ok",
        name: "ok",
        token_hash: Digest::SHA256.hexdigest(raw),
        status: "active"
      )
      expect(described_class.authenticate_token(raw)).to eq(identity)
    end
  end

  describe "#has_scope?" do
    let(:identity) {
      described_class.new(
        stable_id: "mi-scope",
        name: "scope",
        token_hash: "x",
        status: "active",
        scopes: %w[strategy.read strategy.coverage]
      )
    }

    it "returns true for a held scope" do
      expect(identity.has_scope?("strategy.coverage")).to be true
    end

    it "returns false for a scope not held" do
      expect(identity.has_scope?("strategy.authorize")).to be false
    end

    it "handles nil scopes gracefully" do
      identity.scopes = nil
      expect(identity.has_scope?("anything")).to be false
    end
  end
end
