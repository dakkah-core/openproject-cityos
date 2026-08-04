# frozen_string_literal: true

module OpenProject
  module CityosStrategy
    class SnapshotService
      # Creates immutable snapshots of strategy state during review cycles.
      # Each snapshot stores a frozen JSONB copy + SHA256 hash.

      # Snapshot all active objectives for a review
      def snapshot_objectives(review)
        StrategicObjective.where(plan_id: review_plan_ids(review)).find_each do |obj|
          create_snapshot(review, :objective, obj)
        end
      end

      # Snapshot a single initiative
      def snapshot_initiative(review, initiative)
        create_snapshot(review, :initiative, initiative)
      end

      # Snapshot all active metrics for a review
      def snapshot_metrics(review)
        MetricDefinition.includes(:targets, :observations).find_each do |metric|
          create_snapshot(review, :metric, metric)
        end
      end

      # Full portfolio snapshot (objectives + initiatives + metrics + benefits)
      def snapshot_full_portfolio(review)
        snapshot_objectives(review)
        snapshot_metrics(review)

        StrategicInitiative.active.includes(:benefits).find_each do |initiative|
          create_snapshot(review, :initiative, initiative)
          initiative.benefits.find_each do |benefit|
            create_snapshot(review, :benefit, benefit)
          end
        end
      end

      # Verify snapshot integrity
      def verify(snapshot)
        computed = Digest::SHA256.hexdigest(snapshot.frozen_state.to_json)
        computed == snapshot.content_hash
      end

      private

      def create_snapshot(review, type, entity)
        frozen = entity.attributes.except("created_at", "updated_at")
        StrategySnapshot.create!(
          review: review,
          snapshot_type: type,
          entity_type: entity.class.name,
          entity_id: entity.id,
          frozen_state: frozen
        )
      end

      def review_plan_ids(review)
        # Reviews are scoped to the plans within the review period
        StrategicPlan.where(status: :active).pluck(:id)
      end
    end
  end
end
