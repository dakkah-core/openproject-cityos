# frozen_string_literal: true

module Cityos
  module Strategy
    class ReviewsController < ApplicationController
  before_action :find_optional_project

      before_action :find_review, only: %i[show edit update destroy snapshot]

      def index
        @reviews = OpenProject::CityosStrategy::StrategyReview.includes(:facilitator).order(period_start: :desc)
      end

      def show
        @snapshots = @review.snapshots.group_by(&:snapshot_type)
        @snapshot_counts = StrategySnapshot::snapshot_types.keys.index_with { |t| (@snapshots[t] || []).size }
      end

      def new
        @review = OpenProject::CityosStrategy::StrategyReview.new(status: :scheduled)
      end

      def create
        @review = OpenProject::CityosStrategy::StrategyReview.new(review_params)
        if @review.save
          redirect_to review_path(@review), notice: t(:notice_successful_create)
        else
          render :new
        end
      end

      def edit; end

      def update
        if @review.update(review_params)
          redirect_to review_path(@review), notice: t(:notice_successful_update)
        else
          render :edit
        end
      end

      # Create full portfolio snapshot for this review
      def snapshot
        snapshotter = SnapshotService.new
        snapshotter.snapshot_full_portfolio(@review)
        @review.update!(status: :completed)
        redirect_to review_path(@review),
                    notice: "Review completed with #{@review.snapshots.count} snapshots"
      end

      def destroy
        @review.update!(status: :cancelled)
        redirect_to reviews_path, notice: t(:notice_successful_delete)
      end

      private

      def find_review
        @review = OpenProject::CityosStrategy::StrategyReview.find(params[:id])
      end

      def review_params
        params.require(:strategy_review).permit(
          :review_type, :period_start, :period_end, :status, :facilitator_id
        )
      end
    end
  end
end
