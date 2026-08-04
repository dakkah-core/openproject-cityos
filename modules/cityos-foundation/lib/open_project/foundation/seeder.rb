module OpenProject
  module CityOSFoundation
    class Seeder
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
        seed_workflows!

        Rails.logger.info("[CityOS HELM Seeder] Seed complete.")
      end

      private

      # ── WP Types ──────────────────────────────────────────
      def seed_types!
        (@manifest['types'] || []).each do |type_def|
          existing = ::Type.find_by(name: type_def['name'])
          if existing
            Rails.logger.debug("  Type already exists: #{type_def['name']}")
            # Update color/position if changed (non-destructive)
            existing.update!(
              color: ::Type::DEFAULT_COLORS.key(type_def['color']) || existing.color_id,
              position: type_def['position'],
              is_default: type_def.fetch('is_default', false),
              is_milestone: type_def.fetch('is_milestone', false)
            )
          else
            Rails.logger.info("  Creating type: #{type_def['name']}")
            ::Type.create!(
              name: type_def['name'],
              color: ::Type::DEFAULT_COLORS.key(type_def['color']) || :blue,
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
              position: status_def.fetch('position', existing.position)
            )
          else
            Rails.logger.info("  Creating status: #{status_def['name']}")
            ::Status.create!(
              name: status_def['name'],
              is_closed: status_def.fetch('is_closed', false),
              is_default: status_def.fetch('is_default', false),
              color: status_def.fetch('color', '#95A5A6')
            )
          end
        end
      end

      # ── Roles ─────────────────────────────────────────────
      def seed_roles!
        (@manifest['roles'] || []).each do |role_name|
          existing = ::Role.find_by(name: role_name)
          unless existing
            Rails.logger.info("  Creating role: #{role_name}")
            ::Role.create!(name: role_name, assignable: true)
          end
        end
      end

      # ── Workflows (type + status + role combinations) ────
      def seed_workflows!
        return unless @manifest['workflows'] && @manifest['workflows']['type_defaults']

        rules = @manifest['workflows']['type_defaults']
        ::Type.all.each do |type|
          ::Status.all.each do |status|
            allowed = rules[status.name] || []
            allowed_status_ids = allowed.map { |s| ::Status.find_by(name: s)&.id }.compact

            ::Role.where(assignable: true).each do |role|
              existing_wf = ::Workflow.find_by(
                type_id: type.id,
                old_status_id: status.id,
                role_id: role.id
              )
              unless existing_wf
                ::Workflow.create!(
                  type_id: type.id,
                  old_status_id: status.id,
                  role_id: role.id,
                  new_status_ids: allowed_status_ids
                )
              end
            end
          end
        end
      end
    end
  end
end
