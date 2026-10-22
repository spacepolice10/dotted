# frozen_string_literal: true

# Presents an account-scoped queue and advances only after a successful decision.
class ReviewsController < ApplicationController
  include FilterScoped, PrepareBullets

  before_action :set_filter, :set_timeline, :set_review

  def show; end

  def update
    raise ActiveRecord::RecordNotFound unless @bullet

    apply_decision
    redirect_to review_path(bullet_ids: @remaining_ids.drop(1).join(',')), status: :see_other
  rescue ActiveRecord::RecordInvalid, ArgumentError, ActionController::ParameterMissing => e
    @error = if e.is_a?(ActiveRecord::RecordInvalid)
               e.record.errors.full_messages.to_sentence
             else
               'Choose a valid date or collection.'
             end
    render :show, status: :unprocessable_entity
  end

  private

  def apply_decision
    case params[:decision]
    when 'complete' then @bullet.complete!
    when 'postpone' then @bullet.postpone!(pops_on: Date.iso8601(params.require(:pops_on).to_s))
    when 'collect' then collect_bullet
    else raise ActionController::BadRequest, 'Choose a review action'
    end
  end

  def collect_bullet
    @bullet.transaction do
      @bullet.collect!(collection_id: params.require(:collection_id))
      @bullet.resurface!
    end
  end

  def review_ids
    return prepare_bullet_list_from(params[:bullet_ids]) if params.key?(:bullet_ids)

    @timeline.filtered.not_done.reorder(pops_on: :asc, id: :asc).pluck(:id)
  end

  def set_review
    ids = review_ids
    # Resolve every ID through the account, including IDs submitted with actions.
    bullets = Current.user.bullets.where(id: ids).index_by(&:id)
    raise ActiveRecord::RecordNotFound if bullets.size != ids.size

    @remaining_ids = ids.reject { |id| bullets.fetch(id).done? }
    @bullet = bullets[@remaining_ids.first]
  end

end
