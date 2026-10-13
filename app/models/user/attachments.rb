# frozen_string_literal: true

class User
  # Resolves Active Storage files attached directly to the user's bullets.
  class Attachments
    def initialize(user)
      @user = user
    end

    def attachments
      ActiveStorage::Attachment
        .where(record_type: 'Bullet', name: 'file', record_id: user.bullets.select(:id))
        .includes(:blob)
        .order(created_at: :desc)
    end

    def find_blob!(signed_id)
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      raise ActiveRecord::RecordNotFound unless attachments.where(blob_id: blob.id).exists?

      blob
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ActiveRecord::RecordNotFound
    end

    private

    attr_reader :user
  end
end
