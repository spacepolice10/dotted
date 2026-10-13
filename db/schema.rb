# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_13_120000) do
  create_table "access_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.string "code_prefix", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["code_digest"], name: "index_access_codes_on_code_digest", unique: true
    t.index ["user_id"], name: "index_access_codes_on_user_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["subject_type", "subject_id", "created_at"], name: "index_activities_on_subject_type_and_subject_id_and_created_at"
    t.index ["user_id", "created_at"], name: "index_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "auth_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_auth_codes_on_user_id"
  end

  create_table "bullets", force: :cascade do |t|
    t.string "author_name"
    t.datetime "created_at", null: false
    t.datetime "done_at"
    t.date "pops_on", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "filename"
    t.string "client_id"
    t.integer "collection_id"
    t.datetime "last_postponed_at"
    t.integer "postponements_number", default: 0, null: false
    t.index ["collection_id"], name: "index_bullets_on_collection_id"
    t.index ["last_postponed_at"], name: "index_bullets_on_last_postponed_at"
    t.index ["user_id", "client_id"], name: "index_bullets_on_user_id_and_client_id", unique: true
    t.index ["user_id", "collection_id", "pops_on"], name: "index_bullets_on_user_collection_pops_on"
    t.index ["user_id"], name: "index_bullets_on_user_id"
  end

  create_table "collections", force: :cascade do |t|
    t.string "colour"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_collections_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_collections_on_user_id"
  end

  create_table "published_entities", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "publishable_id", null: false
    t.string "publishable_type", null: false
    t.datetime "published_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["code"], name: "index_published_entities_on_code", unique: true
    t.index ["publishable_type", "publishable_id"], name: "index_published_entities_on_publishable"
    t.index ["user_id", "publishable_type", "publishable_id"], name: "idx_published_on_user_and_publishable", unique: true
    t.index ["user_id"], name: "index_published_entities_on_user_id"
  end

  create_table "search_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "search_body"
    t.string "search_name"
    t.integer "searchable_id", null: false
    t.string "searchable_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "searchable_type", "searchable_id"], name: "index_search_records_on_user_and_searchable", unique: true
    t.index ["user_id"], name: "index_search_records_on_user_id"
  end

  create_table "search_selections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "searchable_id", null: false
    t.string "searchable_type", null: false
    t.datetime "selected_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_search_selections_on_searchable"
    t.index ["user_id", "searchable_type", "searchable_id"], name: "index_search_selections_on_user_and_searchable", unique: true
    t.index ["user_id", "selected_at"], name: "index_search_selections_on_user_id_and_selected_at"
    t.index ["user_id"], name: "index_search_selections_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.string "appearance", default: "default", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code_digest", null: false
    t.string "code_prefix", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["code_digest"], name: "index_webhooks_on_code_digest", unique: true
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  add_foreign_key "access_codes", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "auth_codes", "users"
  add_foreign_key "bullets", "collections"
  add_foreign_key "bullets", "users"
  add_foreign_key "collections", "users"
  add_foreign_key "published_entities", "users"
  add_foreign_key "search_records", "users"
  add_foreign_key "search_selections", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_settings", "users"
  add_foreign_key "webhooks", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "search_records_fts5", "fts5", ["search_name", "search_body", "content='search_records'", "content_rowid='id'", "tokenize='unicode61 remove_diacritics 2'", "prefix='2 3 4 5'"]
end
