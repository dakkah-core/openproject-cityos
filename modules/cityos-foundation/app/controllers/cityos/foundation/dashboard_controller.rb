# frozen_string_literal: true

module Cityos
  module Foundation
    class DashboardController < ApplicationController
      before_action :require_admin
      no_authorization_required! :index, :enterprise

      layout "admin"

      def index
        @manifest_path = "/app/config/cityos-helm-manifest.yml"
        @manifest_exists = File.exist?(@manifest_path)
        @plugins = Dir.glob("/app/modules/cityos-*/").map { |d| File.basename(d) }
        @ruby_version = RUBY_VERSION
        @rails_version = Rails.version
        @replacement_surfaces = replacement_surfaces
      end

      def enterprise
        @replacement_surfaces = replacement_surfaces
        @enterprise_gaps = [
          "SSO provider administration remains dependent on OpenID Connect and SAML plugin surfaces.",
          "LDAP group synchronization is still provided by the upstream LDAP groups surface.",
          "SCIM, external storage, and other enterprise integrations remain upstream-managed."
        ]
      end

      def revit_add_in
        @revit_status = "cityos_workspace_ready"
        @revit_capabilities = [
          "Administrative landing page for CityOS BIM and Revit rollout coordination.",
          "Known deployment status exposed directly in HELM without an enterprise dependency.",
          "Clear next-step path for packaging, installer distribution, and support workflow."
        ]
      end

      def style
        @status = "cityos_workspace_ready"
        @style_controls = [
          "CityOS-branded replacement surface for visual governance and theme rollout.",
          "Single admin landing page for current style status, replacement scope, and follow-up work.",
          "No dependency on upstream enterprise style configuration."
        ]
      end

      private

      def replacement_surfaces
        [
          {
            name: "Portfolio",
            status: "implemented",
            route: "/cityos/portfolio",
            notes: "Replaces portfolio navigation in global and top menus."
          },
          {
            name: "Team Planner",
            status: "implemented",
            route: "/cityos/portfolio/team_planner",
            notes: "Replaces team planner navigation in global and project menus."
          },
          {
            name: "Strategy Admin",
            status: "implemented",
            route: "/cityos/strategy/admin",
            notes: "Provides CityOS strategy administration instead of a missing controller."
          },
          {
            name: "Style Workspace",
            status: "custom replacement",
            route: "/cityos/foundation/style",
            notes: "Replaces enterprise custom style menu access with a CityOS-owned admin surface."
          },
          {
            name: "Revit Add-in Workspace",
            status: "custom replacement",
            route: "/cityos/foundation/revit_add_in",
            notes: "Replaces blank account-menu entry with a functional CityOS landing page."
          }
        ]
      end
    end
  end
end
