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

      def revit_add_in
        @revit_status = "not_available"
      end

      def style
        @status = "not_available"
      end
    end
  end
end
