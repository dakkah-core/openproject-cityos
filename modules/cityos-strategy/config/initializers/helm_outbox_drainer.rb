# frozen_string_literal: true

# Wave 3 W3-4 (2026-08-07): register the HELM outbox drainer on
# GoodJob's cron schedule. Runs every 5 seconds when GoodJob is
# available (helm-worker container has it enabled).
#
# We register conditionally so bootstrap doesn't fail when GoodJob is
# absent (e.g. running the web dyno without an attached worker in
# dev). Ops can override the cadence with the HELM_OUTBOX_DRAINER_CRON
# env var — the default `*/5 * * * * *` fires every 5 seconds.

Rails.application.config.after_initialize do
  next unless defined?(GoodJob)
  next unless Rails.application.config.respond_to?(:good_job)

  cadence = ENV.fetch("HELM_OUTBOX_DRAINER_CRON", "*/5 * * * * *")

  begin
    Rails.application.config.good_job.cron ||= {}
    Rails.application.config.good_job.cron[:helm_outbox_drain] = {
      cron: cadence,
      class: "OpenProject::CityosStrategy::HelmOutboxDrainerJob",
      description: "Drain HELM strategy outbox to NATS JetStream (Wave 3 W3-4)"
    }
    Rails.logger.info("[helm-outbox-drainer] scheduled with cron=#{cadence}")
  rescue => e
    Rails.logger.warn("[helm-outbox-drainer] failed to register cron: #{e.class}: #{e.message}")
  end
end
