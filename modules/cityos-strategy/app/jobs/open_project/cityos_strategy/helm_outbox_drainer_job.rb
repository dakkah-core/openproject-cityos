# frozen_string_literal: true

# Wave 3 W3-4 (2026-08-07): HELM outbox drainer job.
#
# Reads pending rows from strategy_event_outbox and publishes each to
# NATS JetStream via EventOutboxService.publish_to_nats. Runs on the
# GoodJob adapter (already provisioned by OpenProject's helm-worker
# container) with a 5-second cadence.
#
# Scheduling (GoodJob cron in config/initializers or the engine
# initializer block):
#   OpenProject::CityosStrategy::HelmOutboxDrainerJob.set(wait: 5.seconds).perform_later
#
# Or via GoodJob's config:
#   config.good_job.cron = {
#     helm_outbox_drain: {
#       cron: "* * * * * *",       # every second (GoodJob supports 6-field)
#       class: "OpenProject::CityosStrategy::HelmOutboxDrainerJob",
#       description: "Drain HELM strategy outbox to NATS JetStream"
#     }
#   }
#
# Design notes:
#   * Batch size is bounded (50 rows) so a huge backlog can't monopolize
#     the worker slot. The next tick picks up the next batch.
#   * DLQ transition (5+ attempts → :dlq) is handled by
#     EventOutboxService.move_to_dlq!. This job does not decide DLQ
#     policy — it only invokes drain_outbox! and reports totals.
#   * Failures inside a single record's publish are already caught and
#     recorded on the row by EventOutboxService.drain_outbox!.
module OpenProject
  module CityosStrategy
    class HelmOutboxDrainerJob < ApplicationJob
      queue_as :default

      def perform(batch_size: 50)
        pending_before = StrategyEventOutbox.where(publish_status: :pending).count
        return if pending_before.zero?

        EventOutboxService.drain_outbox!(batch_size: batch_size)

        # DLQ sweep: any record past its retry limit gets moved to
        # :dlq so it stops being retried in the hot loop.
        StrategyEventOutbox
          .where(publish_status: :failed)
          .where("publish_attempts >= ?", 5)
          .find_each do |record|
            EventOutboxService.move_to_dlq!(record)
          end

        pending_after = StrategyEventOutbox.where(publish_status: :pending).count
        published = pending_before - pending_after
        Rails.logger.info(
          "[helm-outbox-drainer] drained batch: pending_before=#{pending_before} " \
          "published=#{published} pending_after=#{pending_after}"
        )
      end
    end
  end
end
