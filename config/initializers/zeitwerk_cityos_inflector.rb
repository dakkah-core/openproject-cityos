# frozen_string_literal: true

# Shared Zeitwerk inflector: translates CityOS naming conventions.
#
# Module names CityosFoundation, CityosStrategy, etc. match directory names
# cityos_foundation/, cityos_strategy/ so NO inflection needed for those.
#
# Only these overrides remain:
#   sod_guard → SoDGuard (Zeitwerk default would be SodGuard)
#   cityos     → CityOS    (app/controllers/cityos/* uses module CityOS)

Rails.application.config.before_configuration do
  Rails.autoloaders.each do |loader|
    loader.inflector.inflect(
      "sod_guard" => "SoDGuard",
      "cityos"    => "CityOS"
    )
  end
end
