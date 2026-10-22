# frozen_string_literal: true

class MakeCollectionsBulletBuckets < ActiveRecord::Migration[8.1]
  def up
    add_reference :bullets, :collection, foreign_key: true

    execute <<~SQL.squish
      UPDATE bullets
      SET collection_id = (
        SELECT collection_id FROM bullet_collections
        WHERE bullet_collections.bullet_id = bullets.id
        ORDER BY bullet_collections.created_at DESC, bullet_collections.id DESC
        LIMIT 1
      )
    SQL

    add_index :bullets, %i[user_id collection_id pops_on], name: 'index_bullets_on_user_collection_pops_on'
    drop_table :bullet_collections
  end

  def down
    create_table :bullet_collections do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true
      t.timestamps
    end
    add_index :bullet_collections, %i[bullet_id collection_id], unique: true

    execute <<~SQL.squish
      INSERT INTO bullet_collections (bullet_id, collection_id, created_at, updated_at)
      SELECT id, collection_id, datetime('now'), datetime('now')
      FROM bullets
      WHERE collection_id IS NOT NULL
    SQL

    remove_index :bullets, name: 'index_bullets_on_user_collection_pops_on'
    remove_reference :bullets, :collection, foreign_key: true
  end
end
