# frozen_string_literal: true

class AddFilenameToBullets < ActiveRecord::Migration[8.1]
  def up
    add_column :bullets, :filename, :string
    say_with_time 'backfilling bullet filenames from attachment blobs' do
      Bullet.where(bulletable_type: 'Attachment').find_each do |bullet|
        name = bullet.bulletable&.file&.filename&.to_s
        bullet.update_columns(filename: name) if name.present?
      end
    end
  end

  def down
    remove_column :bullets, :filename
  end
end
