# frozen_string_literal: true

# Lists and renders the current user's bullets with files.
class AttachmentsController < ApplicationController
  def index
    @bullets = Current.user.bullets.with_attachment.order(created_at: :desc).preload(note: :rich_text_content, file_attachment: :blob)
  end

  def show
    @bullet = Current.user.bullets.with_attachment.find(params[:id])
    @blob = @bullet.file.blob
  end
end
