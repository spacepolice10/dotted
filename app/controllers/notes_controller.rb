# frozen_string_literal: true

# Edits the note belonging to an authorized owner.
class NotesController < ApplicationController
  before_action :set_notable

  def edit
    @note = @notable.note || @notable.build_note
  end

  def update
    @note = @notable.note || @notable.build_note
    if @notable.update_note(params.require(:note).permit(:content))
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to bullet_path(@notable), status: :see_other }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_notable
    @notable = Current.user.bullets.find(params[:bullet_id])
  end
end
