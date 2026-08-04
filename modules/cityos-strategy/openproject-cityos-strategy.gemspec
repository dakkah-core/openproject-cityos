$LOAD_PATH.push File.expand_path("lib", __dir__)
require "open_project/cityos_strategy/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-strategy"
  spec.version     = OpenProject::CityOSStrategy::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Strategy — plans, objectives, KPIs, initiatives, scenarios, benefits, reviews"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib,app,db,config}/**/*"]
end
