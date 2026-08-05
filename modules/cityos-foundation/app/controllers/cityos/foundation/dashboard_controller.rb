# frozen_string_literal: true

module Cityos
  module Foundation
    class DashboardController < ApplicationController
      before_action :require_admin
      no_authorization_required! :index

      layout "admin"

      def index
        @manifest_path = "/app/config/cityos-helm-manifest.yml"
        @manifest_exists = File.exist?(@manifest_path)
        @plugins = Dir.glob("/app/modules/cityos-*/").map { |d| File.basename(d) }
        @ruby_version = RUBY_VERSION
        @rails_version = Rails.version
      end
    end
  end
end
