$LOAD_PATH.push File.expand_path("lib", __dir__)
require "open_project/cityos_governance/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-governance"
  spec.version     = OpenProject::CityosGovernance::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Governance — scope bindings, projections, evidence links, write guards"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib,db}/**/*"]
end
