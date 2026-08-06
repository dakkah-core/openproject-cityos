# frozen_string_literal: true

require 'spec_helper'

describe 'CityOS Menu Contract', type: :feature do

  let(:project) { Project.find_by(identifier: 'dakkah-cityos') }

  def cityos_menu_items
    items = []
    %w[top_menu global_menu admin_menu].each do |menu_name|
      Redmine::MenuManager.items(menu_name.to_sym).each do |item|
        ctrl = item.url[:controller]
        next if ctrl.nil? || !ctrl.include?('cityos')
        items << [menu_name, item.name, ctrl, item.url[:action] || 'index']
      end
    end
    items
  end

  describe 'all CityOS menu items resolve' do
    cityos_menu_items.each do |menu_name, item_name, controller, action|
      it "[#{menu_name}] #{item_name} routes to #{controller}##{action}" do
        controller_class = (controller.camelize + 'Controller').safe_constantize
        expect(controller_class).not_to be_nil,
          "Controller '#{controller}' not found for menu '#{item_name}' in '#{menu_name}'"

        if controller_class
          expect(controller_class.action_methods).to include(action.to_s),
            "Action '#{action}' not found on #{controller} for menu '#{item_name}'"
        end
      end
    end
  end

  describe 'no broken admin menu items' do
    it 'all resolve to existing controllers' do
      items = Redmine::MenuManager.items(:admin_menu)
      errors = []

      items.each do |item|
        ctrl = item.url[:controller]
        next if ctrl.nil?
        klass = (ctrl.camelize + 'Controller').safe_constantize
        errors << item.name.to_s if klass.nil?
      end

      expect(errors).to be_empty,
        "Broken admin menu items: #{errors.join(', ')}"
    end
  end

  describe 'enterprise replacement menu contract' do
    it 'portfolios in top_menu points to cityos portfolio' do
      items = Redmine::MenuManager.items(:top_menu)
      portfolios = items.find { |i| i.name == :portfolios }
      expect(portfolios).to be_present
      expect(portfolios.url[:controller]).to eq('/cityos/portfolio/portfolio')
    end

    it 'team_planners in global_menu points to cityos team planner' do
      items = Redmine::MenuManager.items(:global_menu)
      tp = items.find { |i| i.name == :team_planners }
      expect(tp).to be_present
      expect(tp.url[:controller]).to eq('/cityos/portfolio/portfolio')
      expect(tp.url[:action]).to eq(:team_planner)
    end

    it 'team_planner_view in project_menu points to cityos' do
      items = Redmine::MenuManager.items(:project_menu, project.identifier)
      tpv = items.find { |i| i.name == :team_planner_view }
      expect(tpv).to be_present
      expect(tpv.url[:controller]).to eq('/cityos/portfolio/portfolio')
    end
  end

  describe 'no translation missing for cityos labels' do
    it 'all cityos strategy labels are defined in en' do
      I18n.with_locale(:en) do
        strategy_labels = %w[
          cityos.strategy.label_strategy cityos.strategy.label_dashboard
          cityos.strategy.label_objectives cityos.strategy.label_initiatives
          cityos.strategy.label_scenarios cityos.strategy.label_metrics
          cityos.strategy.label_reviews cityos.strategy.label_plans
        ]
        strategy_labels.each do |label|
          expect(I18n.t(label, default: nil)).not_to be_nil,
            "Translation missing: #{label}"
        end
      end
    end

    it 'all cityos portfolio labels are defined in en' do
      I18n.with_locale(:en) do
        labels = %w[
          cityos.portfolio.label_portfolio cityos.portfolio.label_team_planner
          cityos.portfolio.label_systems cityos.portfolio.label_rollups
          cityos.portfolio.label_metrics
        ]
        labels.each do |label|
          expect(I18n.t(label, default: nil)).not_to be_nil,
            "Translation missing: #{label}"
        end
      end
    end

    it 'arabic translations exist for strategy labels' do
      I18n.with_locale(:ar) do
        labels = %w[
          cityos.strategy.label_strategy cityos.strategy.label_dashboard
          cityos.strategy.label_objectives
        ]
        labels.each do |label|
          t = I18n.t(label, default: nil)
          expect(t).not_to be_nil, "Arabic translation missing: #{label}"
          expect(t).not_to eq(label.to_s), "Arabic translation is key fallback: #{label}"
        end
      end
    end
  end
end
