# frozen_string_literal: true

# Shared `prepare_bullets_from` handler for Rails `bullet_ids` parameter.
# It helps to provide bulk set of bullets to the controller action.
module PrepareBullets
  extend ActiveSupport::Concern

  MAX_BULK_BULLET_IDS = 200

  private

  def prepare_bullet_list_from(bullet_id_parameter)
    bullet_id_parameter.to_s.split(',').map(&:strip).grep(/\A\d+\z/).map(&:to_i).uniq
  end

  def prepare_bullets_from(bullet_id_parameter)
    bullet_ids = prepare_bullet_list_from(bullet_id_parameter)
    raise ActiveRecord::RecordNotFound if bullet_ids.empty? || bullet_ids.size > MAX_BULK_BULLET_IDS

    bullets = Current.user.bullets.where(id: bullet_ids).preload(:collection).order(:id)
    raise ActiveRecord::RecordNotFound if bullets.count != bullet_ids.size

    bullets
  end

  def prepare_bullets
    @bullets = prepare_bullets_from(params[:bullet_ids])
  end

  def preload_bullet_collections
    ActiveRecord::Associations::Preloader.new(records: @bullets, associations: :collection).call
  end

  def respond_with_failed_bullet(error, template: action_name)
    @failed_bullet = error.record
    respond_to do |format|
      format.turbo_stream { render template, status: :unprocessable_entity }
      format.html do
        redirect_back fallback_location: bullets_path,
                      alert: error.record.errors.full_messages.to_sentence
      end
      format.json { render json: error.record.errors.to_hash, status: :unprocessable_entity }
    end
  end
end
