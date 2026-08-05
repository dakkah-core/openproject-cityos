# frozen_string_literal: true

# CityOS patch: guard connect-src assembly against malformed source entries
# such as "://" that can appear when host config is blank.
Rails.application.config.after_initialize do
  Rails.application.configure do
    config.content_security_policy do |policy|
      assets_src = ["'self'"]
      asset_host = OpenProject::Configuration.rails_asset_host
      assets_src << asset_host if asset_host.present?

      frame_src = []
      frame_src << OpenProject::Configuration[:security_badge_url] if OpenProject::Configuration[:security_badge_displayed]

      default_src = %w('self')
      default_src += OpenProject::Configuration.remote_storage_hosts

      chargebee_src = ["https://*.chargebee.com"]

      assets_src += chargebee_src
      frame_src += chargebee_src
      default_src += chargebee_src

      connect_src = default_src + [OpenProject::Configuration.enterprise_trial_creation_host]
      connect_src << asset_host if asset_host.present?

      media_src = default_src
      media_src << asset_host if asset_host.present?
      onboarding = Addressable::URI.parse(OpenProject::Static::Links.url_for(:onboarding_video_url))
      media_src << "#{onboarding.scheme}://#{onboarding.host}"
      enterprise_video = Addressable::URI.parse(OpenProject::Static::Links.url_for(:enterprise_welcome_video))
      media_src << "#{enterprise_video.scheme}://#{enterprise_video.host}"
      media_src.uniq!

      if OpenProject::Configuration.appsignal_frontend_key
        connect_src += ["https://appsignal-endpoint.net"]
      end

      if FrontendAssetHelper.assets_proxied?
        proxied = ["ws://#{Setting.host_name}", "http://#{Setting.host_name}",
                   FrontendAssetHelper.cli_proxy.sub("http", "ws"), FrontendAssetHelper.cli_proxy]
        connect_src += proxied
        assets_src += proxied
        media_src += proxied
      end

      # Remove malformed CSP sources such as "://" or "http://" with empty host.
      connect_src = Array(connect_src).compact.select do |source|
        value = source.to_s.strip
        next false if value.blank?
        next false if value == "://"

        if value.include?("://")
          begin
            uri = Addressable::URI.parse(value)
            next false if uri.scheme.blank? || uri.host.blank?
          rescue Addressable::URI::InvalidURIError
            next false
          end
        end

        true
      end.uniq

      script_src = assets_src + %w(js.chargebee.com)

      if Rails.env.development? && ENV.fetch("OPENPROJECT_RACK_PROFILER_ENABLED", false)
        script_src += %w('unsafe-eval')
      end

      if Rails.env.development?
        script_src += ["https://www.ssa.gov"]
        assets_src += ["https://www.ssa.gov"]
      end

      form_action = default_src

      if Rails.env.test?
        connect_src += ["test-bucket.s3.amazonaws.com"]
        form_action += ["test-bucket.s3.amazonaws.com"]
      end

      if OpenProject::Configuration.fog_directory.present?
        connect_src += [OpenProject::Configuration.fog_s3_upload_host]
        form_action += [OpenProject::Configuration.fog_s3_upload_host]
      end

      policy.default_src(*default_src)
      policy.base_uri("'self'")
      policy.font_src(*assets_src, "data:")
      policy.form_action(*form_action)
      policy.frame_src(*frame_src, "'self'")
      policy.frame_ancestors("'self'")
      img_src = %w('self') + Array(OpenProject::Configuration.csp_img_src)
      img_src << asset_host if asset_host.present?
      policy.img_src(*img_src.compact.uniq)
      policy.script_src(*script_src)
      policy.script_src_attr("'none'")
      policy.style_src(*assets_src, "'unsafe-inline'")
      policy.object_src(OpenProject::Configuration[:security_badge_url])
      policy.connect_src(*connect_src)
      policy.media_src(*media_src)
    end

    config.content_security_policy_nonce_generator = lambda do |request|
      if request.env["HTTP_TURBO_REFERRER"].present? && request.env["HTTP_X_TURBO_NONCE"].present?
        request.env["HTTP_X_TURBO_NONCE"]
      else
        SecureRandom.base64(16)
      end
    end

    config.content_security_policy_nonce_directives = %w(script-src)
  end
end
