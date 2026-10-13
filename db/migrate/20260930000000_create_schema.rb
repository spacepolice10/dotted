# frozen_string_literal: true

class CreateSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.timestamps
      t.index :email_address, unique: true
    end

    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :appearance, default: 'default', null: false
      t.timestamps
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :auth_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    create_table :access_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :code_prefix, null: false
      t.string :description
      t.timestamps
      t.index :code_digest, unique: true
    end

    create_table :webhooks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code_digest, null: false
      t.string :code_prefix, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
      t.index :code_digest, unique: true
    end

    create_table :collections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :colour
      t.string :icon
      t.text :description
      t.timestamps
      t.index %i[user_id name], unique: true
    end

    create_table :bullets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :collection, foreign_key: true
      t.string :bulletable_type, null: false
      t.integer :bulletable_id, null: false
      t.date :pops_on, null: false
      t.datetime :done_at
      t.string :author_name
      t.timestamps
      t.index %i[bulletable_type bulletable_id], name: 'index_bullets_on_bulletable'
      t.index %i[user_id collection_id pops_on], name: 'index_bullets_on_user_collection_pops_on'
    end

    create_table :texts

    create_table :memos do |t|
      t.integer :duration_seconds
      t.timestamps
    end

    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :colour
      t.timestamps
      t.index %i[user_id name], unique: true
    end

    create_table :bullet_projects do |t|
      t.references :bullet, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.timestamps
      t.index %i[bullet_id project_id], unique: true
    end

    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.string :action, null: false
      t.json :metadata, default: {}, null: false
      t.timestamps
      t.index %i[subject_type subject_id created_at]
      t.index %i[user_id created_at]
    end

    create_table :archives do |t|
      t.references :user, foreign_key: true
      t.string :archivable_type, null: false
      t.integer :archivable_id, null: false
      t.timestamps
      t.index %i[archivable_type archivable_id], unique: true
    end

    create_table :published_entities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :publishable_type, null: false
      t.integer :publishable_id, null: false
      t.string :code, null: false
      t.datetime :published_at, null: false
      t.timestamps
      t.index :code, unique: true
      t.index %i[publishable_type publishable_id], name: 'index_published_entities_on_publishable'
      t.index %i[user_id publishable_type publishable_id], unique: true, name: 'idx_published_on_user_and_publishable'
    end

    create_table :search_records do |t|
      t.references :user, null: false, foreign_key: true
      t.string :searchable_type, null: false
      t.integer :searchable_id, null: false
      t.string :search_name
      t.text :search_body
      t.timestamps
      t.index %i[user_id searchable_type searchable_id], unique: true, name: 'index_search_records_on_user_and_searchable'
    end

    create_virtual_table :search_records_fts5, :fts5, [
      'search_name',
      'search_body',
      "content='search_records'",
      "content_rowid='id'",
      "tokenize='unicode61 remove_diacritics 2'",
      "prefix='2 3 4 5'"
    ]

    execute <<~SQL
      CREATE TRIGGER search_records_ai AFTER INSERT ON search_records BEGIN
        INSERT INTO search_records_fts5(rowid, search_name, search_body)
        VALUES (new.id, new.search_name, new.search_body);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER search_records_ad AFTER DELETE ON search_records BEGIN
        INSERT INTO search_records_fts5(search_records_fts5, rowid, search_name, search_body)
        VALUES ('delete', old.id, old.search_name, old.search_body);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER search_records_au AFTER UPDATE ON search_records BEGIN
        INSERT INTO search_records_fts5(search_records_fts5, rowid, search_name, search_body)
        VALUES ('delete', old.id, old.search_name, old.search_body);
        INSERT INTO search_records_fts5(rowid, search_name, search_body)
        VALUES (new.id, new.search_name, new.search_body);
      END;
    SQL

    create_table :search_selections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :searchable_type, null: false
      t.integer :searchable_id, null: false
      t.string :query
      t.datetime :selected_at, null: false
      t.timestamps
      t.index %i[searchable_type searchable_id], name: 'index_search_selections_on_searchable'
      t.index %i[user_id searchable_type searchable_id], unique: true, name: 'index_search_selections_on_user_and_searchable'
      t.index %i[user_id selected_at]
    end

    create_table :action_text_rich_texts do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
      t.index %i[record_type record_id name], name: 'index_action_text_rich_texts_uniqueness', unique: true
    end

    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, null: false
      t.index :key, unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }
      t.datetime :created_at, null: false
      t.index %i[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness', unique: true
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false, foreign_key: { to_table: :active_storage_blobs }
      t.string :variation_digest, null: false
      t.index %i[blob_id variation_digest], name: 'index_active_storage_variant_records_uniqueness', unique: true
    end
  end
end
