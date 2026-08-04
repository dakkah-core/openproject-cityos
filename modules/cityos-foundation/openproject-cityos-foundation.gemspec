$LOAD_PATH.push File.expand_path("lib", __dir__)
require "open_project/foundation/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-foundation"
  spec.version     = OpenProject::CityOSFoundation::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Foundation — seeder, SoD guards, command dispatch"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib}/**/*"]
end
