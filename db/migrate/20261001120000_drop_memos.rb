# frozen_string_literal: true

class DropMemos < ActiveRecord::Migration[8.1]
  def up
    say_with_time "deleting memo bullets and their recordings" do
      memo_ids = Bullet.where(bulletable_type: "Memo").pluck(:bulletable_id)
      ActiveStorage::Attachment.where(record_type: "Memo", record_id: memo_ids).find_each(&:purge)
      Bullet.where(bulletable_type: "Memo").find_each(&:destroy!)
    end

    drop_table :memos
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
