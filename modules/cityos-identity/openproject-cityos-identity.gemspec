$LOAD_PATH.push File.expand_path("lib", __dir__)
require "openproject-cityos-identity/version"

Gem::Specification.new do |spec|
  spec.name        = "openproject-cityos-identity"
  spec.version     = OpenProject::CityOSIdentity::VERSION
  spec.authors     = ["Dakkah CityOS"]
  spec.summary     = "CityOS Identity — ZITADEL OIDC SSO, JIT provisioning, agent attribution"
  spec.license     = "GPL-3.0-or-later"
  spec.files       = Dir["{lib}/**/*"]
end
