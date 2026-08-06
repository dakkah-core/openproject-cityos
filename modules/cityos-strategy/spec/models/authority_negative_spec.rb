# frozen_string_literal: true

require "spec_helper"

# HEXP-0108: Authority Negative Tests
# These tests PROVE that no HELM path can create/infer approval or bypass lifecycle policy.
RSpec.describe "HELM Authority Negative Tests", type: :model do

  let(:plan) do
    OpenProject::CityosStrategy::StrategicPlan.create!(
      title: "Test Plan",
      version: 1,
      plan_type: :strategic,
      status: :draft
    )
  end

  # ── P0-01: Self-approval impossible ──────────────────────────────

  describe "HEXP-0101: self-approval prevention" do
    it "does NOT allow direct approval_verified_at write" do
      expect(plan).not_to respond_to(:approval_verified_at)
      expect(plan).not_to respond_to(:approval_verified_at=)
    end

    it "does NOT change status on baseline request" do
      expect { plan.request_baseline!(actor: User.anonymous, correlation_id: "test") }
        .not_to change { plan.reload.status }
      # Draft stays draft — only DWOS can approve
      expect(plan.reload.status).to eq("draft")
    end

    it "sets baseline_status to pending on request" do
      plan.request_baseline!(actor: User.anonymous, correlation_id: "test-001")
      expect(plan.reload.baseline_status).to eq("pending")
      expect(plan.baseline_requested_at).to be_present
    end

    it "rejects approval projection with content hash mismatch" do
      bad_projection = {
        ref: "dwo-abc-123",
        subject_hash: "wrong-hash",
        version: plan.version,
        source_revision: "abc123",
        revoked: false,
        approved_by: "test-user"
      }
      expect { plan.apply_verified_baseline!(approval_projection: bad_projection, sync_identity: "test") }
        .to raise_error(ArgumentError, /content hash mismatch/)
    end

    it "rejects approval projection with version mismatch" do
      bad_projection = {
        ref: "dwo-abc-123",
        subject_hash: plan.send(:compute_content_hash),
        version: 999,
        source_revision: "abc123",
        revoked: false,
        approved_by: "test-user"
      }
      expect { plan.apply_verified_baseline!(approval_projection: bad_projection, sync_identity: "test") }
        .to raise_error(ArgumentError, /version mismatch/)
    end

    it "rejects revoked approval projection" do
      projection = {
        ref: "dwo-abc-123",
        subject_hash: plan.send(:compute_content_hash),
        version: plan.version,
        source_revision: "abc123",
        revoked: true,
        approved_by: "test-user"
      }
      expect { plan.apply_verified_baseline!(approval_projection: projection, sync_identity: "test") }
        .to raise_error(ArgumentError, /revoked/)
    end
  end

  # ── P0-06: Public access denied ──────────────────────────────────

  describe "HEXP-0106: public access prevention" do
    it "controller does NOT expose no_authorization_required for strategy views" do
      # Source audit: zero files should contain no_authorization_required!
      files = Dir.glob(Rails.root.join("modules/cityos-strategy/**/*_controller.rb"))
      violations = files.select do |f|
        content = File.read(f)
        content.include?("no_authorization_required!")
      end
      expect(violations).to be_empty,
        "Found #{violations.count} controller(s) with public strategy access: #{violations.join(', ')}"
    end
  end

  # ── P0-07: No patches remain ─────────────────────────────────────

  describe "HEXP-0107: patch removal verification" do
    it "governance patch directory does not exist" do
      patch_dir = Rails.root.join("patches", "004-helm-governance")
      expect(File.directory?(patch_dir)).to be false,
        "patches/004-helm-governance/ must not exist — fixes are in core model source"
    end
  end

  # ── P0-04: Stable IDs ────────────────────────────────────────────

  describe "HEXP-0104: stable IDs" do
    it "auto-generates stable_id on creation" do
      expect(plan.stable_id).to be_present
      expect(plan.stable_id).to match(/^helm-plan-/)
    end

    it "enforces stable_id uniqueness" do
      plan2 = OpenProject::CityosStrategy::StrategicPlan.new(
        title: "Duplicate Plan",
        version: 1,
        plan_type: :strategic,
        status: :draft,
        stable_id: plan.stable_id
      )
      expect(plan2).not_to be_valid
      expect(plan2.errors[:stable_id]).to be_present
    end
  end

  # ── P0-05: Direct KPI writes blocked ─────────────────────────────

  describe "HEXP-0105: initiative-program join" do
    it "StrategicProgram has direct has_many :initiatives" do
      program = OpenProject::CityosStrategy::StrategicProgram.new
      expect(program).to respond_to(:initiatives)
      # Verify it's NOT through: :portfolio (check the reflection)
      reflection = OpenProject::CityosStrategy::StrategicProgram.reflect_on_association(:initiatives)
      expect(reflection.options[:through]).to be_nil,
        "initiatives must be direct has_many, not through: :portfolio"
    end
  end
end
