# frozen_string_literal: true

module OpenProject
  module CityosIdentity
    class Hooks < OpenProject::Hook::ViewListener
      render_on :view_account_login_auth_provider,
                partial: "hooks/login/cityos_oidc_provider"
    end
  end
end
