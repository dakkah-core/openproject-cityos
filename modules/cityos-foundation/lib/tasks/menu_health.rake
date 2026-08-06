# frozen_string_literal: true

namespace :menu do
  desc "Health check: recursively verify every menu item has a resolvable controller/action"
  task health: :environment do
    require "redmine/menu_manager"

    menus = %w[account_menu my_menu top_menu global_menu admin_menu project_menu]
    errors = []
    total = 0

    def self.check_node(node, menu_name, errors, total_ref)
      mi = node.content rescue nil
      unless mi.nil?
        controller = mi.url[:controller] rescue nil
        action = (mi.url[:action] || "index").to_s rescue "index"

        unless controller.nil?
          total_ref[0] += 1

          controller_class = (controller.camelize + "Controller").safe_constantize
          if controller_class.nil?
            errors << "[#{menu_name}] #{node.name}: controller '#{controller}' not found"
          elsif !controller_class.action_methods.include?(action)
            errors << "[#{menu_name}] #{node.name}: action '#{action}' not found on #{controller}"
          end
        end
      end

      node.children.each { |child| check_node(child, menu_name, errors, total_ref) }
    rescue => e
      errors << "[#{menu_name}] #{node.name}: error #{e.message}"
    end

    menus.each do |menu_name|
      tree = ::Redmine::MenuManager.items(menu_name.to_sym) rescue nil
      next if tree.nil?

      total_ref = [0]
      # Skip root node, iterate children recursively
      tree.children.each { |child| check_node(child, menu_name, errors, total_ref) }
      total += total_ref[0]
    end

    if errors.empty?
      puts "\n  Menu health check PASSED - #{total} items resolvable\n"
    else
      puts "\n  Menu health check FAILED - #{errors.count} unresolvable items:\n"
      errors.each { |e| puts "    #{e}" }
      exit 1
    end
  end

  desc "List all menu items recursively"
  task inventory: :environment do
    require "redmine/menu_manager"

    def self.print_node(node, menu_name)
      mi = node.content rescue nil
      unless mi.nil?
        cap = begin
          mi.caption.is_a?(Symbol) ? I18n.t(mi.caption, default: mi.caption.to_s) : mi.caption.to_s
        rescue
          mi.caption.to_s
        end
        ctrl = mi.url[:controller] rescue "N/A"
        act = mi.url[:action] rescue "N/A"
        puts "  #{node.name} | #{ctrl}##{act} | #{cap}"
      end
      node.children.each { |child| print_node(child, menu_name) }
    end

    %w[account_menu my_menu top_menu global_menu admin_menu project_menu].each do |menu_name|
      puts "\n=== #{menu_name} ==="
      tree = ::Redmine::MenuManager.items(menu_name.to_sym) rescue nil
      next if tree.nil?
      tree.children.each { |child| print_node(child, menu_name) }
    end
  end

  desc "Run all menu checks"
  task check: %i[health]
end