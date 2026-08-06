# frozen_string_literal: true

namespace :menu do
  desc "Health check: verify every menu item has a resolvable controller/action"
  task health: :environment do
    require 'redmine/menu_manager'

    menus = %w[account_menu my_menu top_menu global_menu admin_menu project_menu]
    errors = []

    menus.each do |menu_name|
      begin
        items = ::Redmine::MenuManager.items(menu_name.to_sym)
      rescue => e
        errors << "[system] Cannot read #{menu_name}: #{e.message}"
        next
      end

      items.each do |item|
        controller = item.url[:controller] rescue nil
        action = (item.url[:action] || 'index').to_s

        next if controller.nil?

        begin
          controller_class = (controller.camelize + 'Controller').safe_constantize
        rescue => e
          next
        end

        if controller_class.nil?
          errors << "[#{menu_name}] #{item.name}: controller '#{controller}' not found"
          next
        end

        unless controller_class.action_methods.include?(action)
          errors << "[#{menu_name}] #{item.name}: action '#{action}' not found on #{controller}"
        end
      end
    end

    total = menus.sum { |m| (::Redmine::MenuManager.items(m.to_sym) rescue []).count }

    if errors.empty?
      puts "\n  Menu health check PASSED — #{total} items resolvable\n"
    else
      puts "\n  Menu health check FAILED — #{errors.count} unresolvable items:\n"
      errors.each { |e| puts "    #{e}" }
      exit 1
    end
  end

  desc "List all menu items with controller/action/label"
  task inventory: :environment do
    require 'redmine/menu_manager'

    %w[account_menu my_menu top_menu global_menu admin_menu project_menu].each do |menu_name|
      puts "\n=== #{menu_name} ==="
      items = ::Redmine::MenuManager.items(menu_name.to_sym) rescue []
      items.each do |item|
        cap = begin
          item.caption.is_a?(Symbol) ? I18n.t(item.caption, default: item.caption.to_s) : item.caption.to_s
        rescue
          item.caption.to_s
        end
        ctrl = item.url[:controller] rescue 'N/A'
        act = item.url[:action] rescue 'N/A'
        puts "  #{item.name} | #{ctrl}##{act} | #{cap}"
      end
    end
  end

  desc "Check translation coverage for all CityOS menu labels"
  task translations: :environment do
    require 'redmine/menu_manager'

    locales = %w[en ar]
    cityos_prefixes = %w[cityos.strategy cityos.portfolio cityos.foundation cityos.governance cityos.identity]
    missing = []

    %w[account_menu my_menu top_menu global_menu admin_menu project_menu].each do |menu_name|
      items = ::Redmine::MenuManager.items(menu_name.to_sym) rescue []
      items.each do |item|
        cap = item.caption
        next unless cap.is_a?(Symbol)
        next unless cityos_prefixes.any? { |p| cap.to_s.start_with?(p) }

        locales.each do |locale|
          ::I18n.with_locale(locale.to_sym) do
            translation = ::I18n.t(cap, default: nil)
            if translation.nil?
              missing << "[#{locale}] #{menu_name}/#{item.name}: #{cap}"
            end
          end
        end
      end
    end

    if missing.empty?
      puts "\n  Translation check PASSED — all CityOS menu labels covered in #{locales.join(', ')}\n"
    else
      puts "\n  Translation check FAILED — #{missing.count} missing translations:\n"
      missing.each { |m| puts "    #{m}" }
      exit 1
    end
  end

  desc "Run all menu checks (health + translations)"
  task check: %i[health translations]
end
