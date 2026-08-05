# frozen_string_literal: true

module OpenProject
  module CityosIdentity
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_account_login_auth_provider,
                partial: "hooks/login/cityos_oidc_provider"

      render_on :view_account_login_top,
                partial: "hooks/login/cityos_login_branding"
    end
  end
end
