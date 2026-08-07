$LOAD_PATH.push File.expand_path("lib", __dir__)
require "open_project/cityos_strategy/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-strategy"
  spec.version     = OpenProject::CityosStrategy::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Strategy — plans, objectives, KPIs, initiatives, scenarios, benefits, reviews"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib,app,db,config}/**/*"]

  # Wave 3 W3-4 (2026-08-07): nats-pure is the pure-Ruby NATS client
  # used by EventOutboxService.publish_to_nats to publish to JetStream.
  # Bundled here as a soft dep — the outbox service degrades gracefully
  # if it's missing, but production runtime requires it installed.
  spec.add_dependency "nats-pure", "~> 2.4"
end
