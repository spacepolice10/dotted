# frozen_string_literal: true

# SQLite FTS5 backing for Search::Record. The virtual table is an external-content
# index (`content='search_records'`); INSERT/UPDATE/DELETE triggers keep it in sync.
module Search::Record::Sqlite
  extend ActiveSupport::Concern

  FTS5_TABLE = 'search_records_fts5'
  CONTENT_TABLE = 'search_records'

  included do
    scope :matching, lambda { |query|
      joins("INNER JOIN #{FTS5_TABLE} ON #{FTS5_TABLE}.rowid = #{table_name}.id")
        .where("#{FTS5_TABLE} MATCH ?", query)
    }
  end

  class_methods do
    def search(user:, query:, limit: 50)
      ensure_fts5_triggers!
      fts5_query = Search::TermBuilder.build(query)
      return none if fts5_query.blank?

      matching(fts5_query)
        .where(user_id: user.id)
        .select(
          "#{table_name}.*",
          "bm25(#{FTS5_TABLE}, 10.0, 1.0) AS fts5_rank"
        )
        .order(Arel.sql('fts5_rank'))
        .limit(limit)
    end

    # Idempotent: safe after schema:load (schema.rb does not dump triggers).
    def ensure_fts5_triggers!
      return if @fts5_triggers_ready
      return unless connection.adapter_name.match?(/sqlite/i)
      return unless connection.data_source_exists?(CONTENT_TABLE)

      unless fts5_trigger_installed?
        install_fts5_triggers!
        rebuild_fts5_index!
      end

      @fts5_triggers_ready = true
    end

    def install_fts5_triggers!
      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_ai AFTER INSERT ON #{CONTENT_TABLE} BEGIN
          INSERT INTO #{FTS5_TABLE}(rowid, search_name, search_body)
          VALUES (new.id, new.search_name, new.search_body);
        END;
      SQL

      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_ad AFTER DELETE ON #{CONTENT_TABLE} BEGIN
          INSERT INTO #{FTS5_TABLE}(#{FTS5_TABLE}, rowid, search_name, search_body)
          VALUES ('delete', old.id, old.search_name, old.search_body);
        END;
      SQL

      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_au AFTER UPDATE ON #{CONTENT_TABLE} BEGIN
          INSERT INTO #{FTS5_TABLE}(#{FTS5_TABLE}, rowid, search_name, search_body)
          VALUES ('delete', old.id, old.search_name, old.search_body);
          INSERT INTO #{FTS5_TABLE}(rowid, search_name, search_body)
          VALUES (new.id, new.search_name, new.search_body);
        END;
      SQL
    end

    def rebuild_fts5_index!
      connection.execute("INSERT INTO #{FTS5_TABLE}(#{FTS5_TABLE}) VALUES('rebuild')")
    end

    def fts5_trigger_installed?
      connection.select_value(<<~SQL).present?
        SELECT 1 FROM sqlite_master
        WHERE type = 'trigger' AND name = 'search_records_ai'
      SQL
    end
  end
end
