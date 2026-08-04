# frozen_string_literal: true

# Map hyphenated gem directory names to OpenProject module hierarchy.
# openproject_cityos_strategy → OpenProject::CityOSStrategy
Rails.autoloaders.main.inflector.inflect(
  "openproject_cityos_strategy" => "OpenProject::CityOSStrategy"
)
