# frozen_string_literal: true

class DropBulletableTypes < ActiveRecord::Migration[8.1]
  def up
    say_with_time 'moving attachment blobs onto bullets' do
      Bullet.where(bulletable_type: 'Attachment').find_each do |bullet|
        blob_id = ActiveStorage::Attachment.where(record_type: 'Attachment', record_id: bullet.bulletable_id, name: 'file').pick(:blob_id)
        next if blob_id.nil?

        ActiveStorage::Attachment.create!(record_type: 'Bullet', record_id: bullet.id, name: 'file', blob_id: blob_id)
      end
    end

    say_with_time 'purging orphaned attachment rows' do
      ActiveStorage::Attachment.where(record_type: 'Attachment').delete_all
    end

    execute 'DELETE FROM texts'
    execute 'DELETE FROM attachments'
    drop_table :texts
    drop_table :attachments
    remove_column :bullets, :bulletable_id
    remove_column :bullets, :bulletable_type
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
