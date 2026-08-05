# frozen_string_literal: true

require 'minitest/autorun'
require 'yaml'

class HelmMenuContractTest < Minitest::Test
  FOUNDATION_ENGINE = File.expand_path('../../lib/open_project/cityos_foundation/engine.rb', __dir__)
  PORTFOLIO_ENGINE = File.expand_path('../../lib/open_project/cityos_portfolio/engine.rb', __dir__)
  STRATEGY_ENGINE = File.expand_path('../../lib/open_project/cityos_strategy/engine.rb', __dir__)

  FOUNDATION_LOCALES = File.expand_path('../../config/locales/en.yml', __dir__)
  STRATEGY_LOCALES = File.expand_path('../../cityos-strategy/config/locales/en.yml', __dir__)
  PORTFOLIO_LOCALES = File.expand_path('../../cityos-portfolio/config/locales/en.yml', __dir__)

  def test_foundation_admin_items_route_to_cityos_foundation_controller
    source = File.read(FOUNDATION_ENGINE)

    assert_match(/menu :admin_menu,\s*:cityos_foundation,\s*\{\s*controller: '\/cityos\/foundation',\s*action: :index\s*\}/, source)
    assert_match(/menu :admin_menu,\s*:custom_style,\s*\{\s*controller: '\/cityos\/foundation',\s*action: :style\s*\}/, source)
    assert_match(/menu :account_menu,\s*:revit_add_in,\s*\{\s*controller: '\/cityos\/foundation',\s*action: :revit_add_in\s*\}/, source)
  end

  def test_portfolio_replaces_portfolio_and_team_planner_targets
    source = File.read(PORTFOLIO_ENGINE)

    assert_match(/menu :top_menu,\s*:cityos_portfolio,\s*\{\s*controller: '\/cityos\/portfolio\/portfolio',\s*action: :index\s*\}/, source)
    assert_match(/menu :top_menu,\s*:portfolios,\s*\{\s*controller: '\/cityos\/portfolio\/portfolio',\s*action: :index\s*\}/, source)
    assert_match(/menu :global_menu,\s*:portfolios,\s*\{\s*controller: '\/cityos\/portfolio\/portfolio',\s*action: :index\s*\}/, source)
    assert_match(/menu :top_menu,\s*:team_planners,\s*\{\s*controller: '\/cityos\/portfolio\/portfolio',\s*action: :team_planner\s*\}/, source)
    assert_match(/menu :project_menu,\s*:team_planner_view,\s*\{\s*controller: '\/cityos\/portfolio\/portfolio',\s*action: :team_planner\s*\}/, source)
  end

  def test_strategy_admin_is_defined_and_localized
    source = File.read(STRATEGY_ENGINE)
    locales = YAML.load_file(STRATEGY_LOCALES)

    assert_match(%r{get "/cityos/strategy/admin"\s+to: "cityos/strategy/admin#index"}, source)
    assert_equal "Strategy Administration", locales.dig('en', 'cityos', 'strategy', 'label_administration')
  end

  def test_foundation_locales_include_revit_style_labels
    locales = YAML.load_file(FOUNDATION_LOCALES)

    assert_equal "Revit Add-in", locales.dig('en', 'cityos', 'foundation', 'label_revit_add_in')
    assert_equal "CityOS Style", locales.dig('en', 'cityos', 'foundation', 'label_style')
  end

  def test_portfolio_locales_include_team_planner_label
    locales = YAML.load_file(PORTFOLIO_LOCALES)

    assert_equal "Team Planner", locales.dig('en', 'cityos', 'portfolio', 'label_team_planner')
  end
end
