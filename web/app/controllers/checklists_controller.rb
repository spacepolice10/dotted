# frozen_string_literal: true

# Edits the optional checklist of an authorized bullet.
class ChecklistsController < ApplicationController
  before_action :set_bullet

  def new
    prepare_editor
  end

  def edit
    prepare_editor
    render :new
  end

  def create
    save_checklist
  end

  def update
    save_checklist
  end

  private

  def set_bullet
    @bullet = Current.user.bullets.find(params[:bullet_id])
  end

  def prepare_editor
    @checklist = @bullet.checklist || @bullet.build_checklist
    @checklist.items.build if @checklist.items.empty?
  end

  def save_checklist
    @checklist = @bullet.checklist || @bullet.build_checklist
    if @bullet.update_checklist(checklist_params, resurface: params[:resurface] == '1')
      respond_to do |format|
        format.turbo_stream { render :update }
        format.html { redirect_to bullet_path(@bullet), status: :see_other }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def checklist_params
    params.require(:checklist).permit(items_attributes: %i[id text position _destroy])
  end
end
