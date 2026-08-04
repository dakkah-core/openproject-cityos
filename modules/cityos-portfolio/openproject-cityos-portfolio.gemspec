$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject-cityos-portfolio/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-portfolio"
  spec.version     = OpenProject::CityOSPortfolio::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Portfolio — rollups, dashboards, dependency views, PEDD enrichment"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib,app}/**/*"]
end
