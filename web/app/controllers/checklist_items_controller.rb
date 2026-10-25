# frozen_string_literal: true

# Checks an item without changing the bullet's timeline date.
class ChecklistItemsController < ApplicationController
  before_action :set_item

  def update
    @item.set_completed!(completed: completed_param)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to bullet_path(@bullet), status: :see_other }
    end
  end

  private

  def set_item
    @bullet = Current.user.bullets.find(params[:bullet_id])
    @checklist = @bullet.checklist || raise(ActiveRecord::RecordNotFound)
    @item = @checklist.items.find(params[:id])
  end

  def completed_param
    completed = params.require(:checklist_item).require(:completed).to_s
    raise ActionController::BadRequest unless completed.in?(%w[0 1])

    completed == '1'
  end
end
