# frozen_string_literal: true

module CityOS
  module Strategy
    class ExecutionLinksController < ApplicationController
      before_action :find_initiative, only: %i[index create destroy]

      # List all WP links for an initiative
      def index
        @links = @initiative.execution_links.includes(:work_package)
      end

      # Link a work package to an initiative
      def create
        wp = WorkPackage.find(params[:work_package_id])
        link = @initiative.execution_links.build(
          work_package: wp,
          link_type: params[:link_type] || :delivers,
          contribution_weight: params[:contribution_weight] || 1.0
        )

        if link.save
          redirect_to initiative_path(@initiative), notice: "Linked to WP ##{wp.id}"
        else
          redirect_to initiative_path(@initiative), alert: link.errors.full_messages.to_sentence
        end
      end

      # Unlink a work package
      def destroy
        link = @initiative.execution_links.find(params[:id])
        link.destroy!
        redirect_to initiative_path(@initiative), notice: "Unlinked WP ##{link.work_package_id}"
      end

      private

      def find_initiative
        @initiative = StrategicInitiative.find(params[:initiative_id])
      end
    end
  end
end
