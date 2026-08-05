module OpenProject
  module CityosFoundation
    class Seeder
      CITYOS_FOUNDATION_PERMISSIONS = [
        "view_cityos_foundation"
      ].freeze

      CITYOS_GOVERNANCE_PERMISSIONS = [
        "view_cityos_governance",
        "manage_cityos_governance"
      ].freeze

      CITYOS_PORTFOLIO_PERMISSIONS = [
        "view_cityos_portfolio",
        "manage_cityos_portfolio"
      ].freeze

      STRATEGY_VIEW_PERMISSIONS = [
        "view_strategy_dashboard",
        "view_strategic_plans",
        "view_objectives",
        "view_initiatives",
        "view_scenarios",
        "view_metrics",
        "view_reviews",
        "view_benefits",
        "view_risks",
        "view_dependencies",
        "view_allocations",
        "view_decisions"
      ].freeze

      STRATEGY_MANAGE_PERMISSIONS = [
        "manage_strategic_plans",
        "manage_objectives",
        "manage_initiatives",
        "manage_scenarios",
        "manage_metrics",
        "manage_reviews",
        "manage_benefits",
        "manage_risks",
        "manage_dependencies",
        "manage_allocations",
        "manage_decisions"
      ].freeze

      CITYOS_BASE_PERMISSIONS = (
        CITYOS_FOUNDATION_PERMISSIONS +
        CITYOS_GOVERNANCE_PERMISSIONS +
        CITYOS_PORTFOLIO_PERMISSIONS +
        STRATEGY_VIEW_PERMISSIONS
      ).freeze

      ROLE_CITYOS_PERMISSIONS = {
        "program-planner" => (CITYOS_BASE_PERMISSIONS + STRATEGY_MANAGE_PERMISSIONS + ["access_strategy_api"]).freeze,
        "owner-recorder" => (CITYOS_BASE_PERMISSIONS + ["manage_metrics"]).freeze,
        "auditor" => CITYOS_BASE_PERMISSIONS,
        "builder-agent" => CITYOS_BASE_PERMISSIONS,
        "reviewer-agent" => CITYOS_BASE_PERMISSIONS,
        "tester-agent" => CITYOS_BASE_PERMISSIONS,
        "security-agent" => CITYOS_BASE_PERMISSIONS,
        "devops-agent" => CITYOS_BASE_PERMISSIONS
      }.freeze

      PROJECT_ADMIN_PERMISSIONS = (CITYOS_BASE_PERMISSIONS + STRATEGY_MANAGE_PERMISSIONS + ["access_strategy_api"]).freeze

      def self.apply(manifest_path)
        manifest = YAML.safe_load(File.read(manifest_path))
        new(manifest).apply!
      end

      def initialize(manifest)
        @manifest = manifest
      end

      def apply!
        Rails.logger.info("[CityOS HELM Seeder] Starting idempotent seed...")

        seed_types!
        seed_statuses!
        seed_roles!
        seed_role_permissions!
        seed_workflows!
        seed_project_admin_permissions!

        Rails.logger.info("[CityOS HELM Seeder] Seed complete.")
      end

      private

      # ── WP Types ──────────────────────────────────────────
      def seed_types!
        (@manifest['types'] || []).each do |type_def|
          existing = ::Type.find_by(name: type_def['name'])
          if existing
            Rails.logger.debug("  Type already exists: #{type_def['name']}")
            existing.update!(
              color_id: type_color_id(type_def['color']),
              position: type_def['position'],
              is_default: type_def.fetch('is_default', false),
              is_milestone: type_def.fetch('is_milestone', false)
            )
          else
            Rails.logger.info("  Creating type: #{type_def['name']}")
            ::Type.create!(
              name: type_def['name'],
              color_id: type_color_id(type_def['color']),
              position: type_def['position'],
              is_default: type_def.fetch('is_default', false),
              is_milestone: type_def.fetch('is_milestone', false),
              is_in_roadmap: true
            )
          end
        end
      end

      # ── Statuses ──────────────────────────────────────────
      def seed_statuses!
        (@manifest['statuses'] || []).each do |status_def|
          existing = ::Status.find_by(name: status_def['name'])
          if existing
            Rails.logger.debug("  Status already exists: #{status_def['name']}")
            existing.update!(
              is_closed: status_def.fetch('is_closed', false),
              is_default: status_def.fetch('is_default', false),
              position: status_def.fetch('position', existing.position),
              color_id: status_color_id(status_def['color'])
            )
          else
            Rails.logger.info("  Creating status: #{status_def['name']}")
            ::Status.create!(
              name: status_def['name'],
              is_closed: status_def.fetch('is_closed', false),
              is_default: status_def.fetch('is_default', false),
              position: status_def.fetch('position', nil),
              color_id: status_color_id(status_def['color'])
            )
          end
        end
      end

      # ── Roles ─────────────────────────────────────────────
      def seed_roles!
        (@manifest['roles'] || []).each do |role_name|
          existing = ::Role.find_by(name: role_name)
          if existing
            Rails.logger.debug("  Role already exists: #{role_name}")
            existing.update!(
              type: "ProjectRole",
              builtin: 0
            )
          else
            Rails.logger.info("  Creating role: #{role_name}")
            ::Role.create!(name: role_name, type: "ProjectRole", builtin: 0)
          end
        end
      end

      def seed_role_permissions!
        (@manifest['roles'] || []).each do |role_name|
          role = ::Role.find_by(name: role_name)
          next unless role

          desired_permissions = ROLE_CITYOS_PERMISSIONS[role_name]
          next unless desired_permissions

          add_missing_permissions!(role, desired_permissions)
        end
      end

      def seed_project_admin_permissions!
        role = ::Role.find_by(name: "Project admin")
        return unless role

        add_missing_permissions!(role, PROJECT_ADMIN_PERMISSIONS)
      end

      # ── Workflows (type + status + role combinations) ────
      def seed_workflows!
        return unless @manifest['workflows'] && @manifest['workflows']['type_defaults']

        rules = @manifest['workflows']['type_defaults']['allowed_transitions'] || {}
        ::Type.all.each do |type|
          ::Status.all.each do |status|
            allowed = rules[status.name] || []
            allowed_status_ids = allowed.map { |s| ::Status.find_by(name: s)&.id }.compact

            ::Role.where(type: "ProjectRole").each do |role|
              allowed_status_ids.each do |new_status_id|
                existing_wf = ::Workflow.find_by(
                  type_id: type.id,
                  old_status_id: status.id,
                  role_id: role.id,
                  new_status_id: new_status_id
                )
                next if existing_wf

                ::Workflow.create!(
                  type_id: type.id,
                  old_status_id: status.id,
                  role_id: role.id,
                  new_status_id: new_status_id
                )
              end
            end
          end
        end
      end

      # ── Helpers ──────────────────────────────────────────
      def add_missing_permissions!(role, permissions)
        current_permissions = Array(role.permissions).map(&:to_s).uniq
        desired_permissions = permissions.map(&:to_s).uniq
        missing_permissions = desired_permissions - current_permissions

        return if missing_permissions.empty?

        Rails.logger.info("  Granting CityOS permissions to role #{role.name}: #{missing_permissions.join(", ")}")
        role.permissions = current_permissions + missing_permissions
        role.save!
      end

      def type_color_id(color_hex)
        return if color_hex.blank?

        ::Color.find_by(hexcode: color_hex)&.id
      end

      def status_color_id(color_hex)
        return if color_hex.blank?

        ::Color.find_by(hexcode: color_hex)&.id
      end
    end
  end
end
