# frozen_string_literal: true

class CreateBulletCollections < ActiveRecord::Migration[8.1]
  def up
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

    remove_foreign_key :bullets, :collections
    remove_index :bullets, name: 'index_bullets_on_user_collection_pops_on'
    remove_index :bullets, :collection_id
    remove_column :bullets, :collection_id
  end

  def down
    add_reference :bullets, :collection, foreign_key: true
    add_index :bullets, %i[user_id collection_id pops_on], name: 'index_bullets_on_user_collection_pops_on'

    execute <<~SQL.squish
      UPDATE bullets
      SET collection_id = (
        SELECT collection_id FROM bullet_collections
        WHERE bullet_collections.bullet_id = bullets.id
        ORDER BY bullet_collections.id ASC
        LIMIT 1
      )
    SQL

    drop_table :bullet_collections
  end
end
