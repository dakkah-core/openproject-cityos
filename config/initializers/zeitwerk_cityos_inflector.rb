# frozen_string_literal: true

# Shared Zeitwerk inflector: maps hyphenated/openproject-style directory names
# to CityOS module hierarchy with camelCase rules.
#
# Without this:
#   cityos_strategy/engine.rb   → CityosStrategy::Engine   (wrong case)
#   cityos/strategy/plans_controller.rb → Cityos::Strategy::PlansController
#
# With this:
#   cityos_strategy/engine.rb   → CityOSStrategy::Engine   (correct)
#   cityos/strategy/plans_controller.rb → CityOS::Strategy::PlansController

Rails.application.config.before_configuration do
  Rails.autoloaders.each do |loader|
    loader.inflector.inflect(
      "cityos_strategy"   => "CityOSStrategy",
      "cityos_foundation" => "CityOSFoundation",
      "cityos_governance" => "CityOSGovernance",
      "cityos_identity"   => "CityOSIdentity",
      "cityos_portfolio"  => "CityOSPortfolio",
      "cityos"            => "CityOS",
      "sod_guard"         => "SoDGuard"
    )
  end
end
