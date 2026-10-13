# frozen_string_literal: true

# Lists and renders files that can be traced back to the current user.
class AttachmentsController < ApplicationController
  def index
    @attachments = user_attachments.attachments
  end

  def show
    @blob = user_attachments.find_blob!(params[:signed_id])
  end

  private

  def user_attachments
    @user_attachments ||= User::Attachments.new(Current.user)
  end
end
