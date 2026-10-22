# frozen_string_literal: true

class SwitchSearchRecordsFts5ToExternalContent < ActiveRecord::Migration[8.1]
  FTS5_TABLE = 'search_records_fts5'
  CONTENT_TABLE = 'search_records'

  def up
    execute 'DROP TRIGGER IF EXISTS search_records_ai'
    execute 'DROP TRIGGER IF EXISTS search_records_ad'
    execute 'DROP TRIGGER IF EXISTS search_records_au'
    execute "DROP TABLE IF EXISTS #{FTS5_TABLE}"

    create_virtual_table FTS5_TABLE, :fts5, [
      'search_name',
      'search_body',
      "content='#{CONTENT_TABLE}'",
      "content_rowid='id'",
      "tokenize='unicode61 remove_diacritics 2'",
      "prefix='2 3 4 5'"
    ]

    Search::Record.install_fts5_triggers!
    Search::Record.rebuild_fts5_index!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
