# frozen_string_literal: true

module Cityos
  module Strategy
    class BenefitsController < ApplicationController
  before_action :find_optional_project
  before_action :authorize_global  # HEXP-0106: Strategy data is sensitive - require auth

      before_action :find_benefit, only: %i[show edit update]

      def index
        @benefits = OpenProject::CityosStrategy::StrategicBenefit.includes(:initiative, :benefit_owner)
                                    .order(:status, realization_date: :desc)
        @by_type = @benefits.group_by(&:benefit_type)
        @by_status = @benefits.group_by(&:status)

        # Aggregate totals
        @total_target = @benefits.where(benefit_type: :financial).sum(&:target)
        @total_realized = @benefits.where(benefit_type: :financial)
                                   .where(status: %i[realized sustained])
                                   .sum(&:current_value)
      end

      def show; end

      def edit; end

      def update
        if @benefit.update(benefit_params)
          redirect_to benefits_path, notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      private

      def find_benefit
        @benefit = OpenProject::CityosStrategy::StrategicBenefit.find(params[:id])
      end

      def benefit_params
        params.require(:strategic_benefit).permit(
          :benefit_type, :description, :baseline, :target, :current_value,
          :realization_date, :measurement_method, :sustainability_period,
          :status, :benefit_owner_id, :beneficiary
        )
      end
    end
  end
end
