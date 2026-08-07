# frozen_string_literal: true

# Wave 4 W4-2 (2026-08-07): rake tasks for the strategy pack importer.
#
# Usage:
#   bin/rails cityos_strategy:import[fixtures/strategy-pack.yaml,dry-run]
#   bin/rails cityos_strategy:import[fixtures/strategy-pack.yaml,apply-draft]
#   bin/rails cityos_strategy:import[fixtures/strategy-pack.yaml,verify]
#   bin/rails cityos_strategy:import[/dev/null,export]     # export doesn't read path
#
# Never invokes apply-baseline — baseline authority is DWOS-only.

namespace :cityos_strategy do
  desc "Import a strategy pack via Cityos::Strategy::Importer (mode: dry-run|apply-draft|verify|export)"
  task :import, %i[path mode] => :environment do |_t, args|
    path = args[:path] || raise("path is required (bin/rails cityos_strategy:import[path,mode])")
    mode = args[:mode] || "dry-run"

    puts "[cityos_strategy:import] path=#{path} mode=#{mode}"
    payload = mode == "export" ? { records: [] } : path

    receipt = Cityos::Strategy::Importer.run(
      payload: payload,
      mode: mode,
      actor: nil,             # CLI invocation = system actor
      actor_scope: "rake",
      source_path: path
    )

    puts "[cityos_strategy:import] receipt=#{receipt.import_id} status=#{receipt.status} dry_run=#{receipt.dry_run}"
    puts "  source_hash=#{receipt.source_hash}"
    puts "  record_deltas=#{receipt.record_deltas.to_json}"
    if receipt.status == "failed"
      abort "[cityos_strategy:import] FAILED: #{receipt.error_message}"
    end
  end

  desc "Show the last N strategy import receipts"
  task :import_history, [:limit] => :environment do |_t, args|
    limit = (args[:limit] || 10).to_i
    OpenProject::CityosStrategy::StrategyImportReceipt
      .order(created_at: :desc)
      .limit(limit)
      .each do |r|
        printf("%-38s %-12s %-10s %s\n",
               r.import_id, r.mode, r.status, r.created_at.iso8601)
      end
  end
end
