# frozen_string_literal: true

# SQLite FTS5 backing for Search::Record. The virtual table is an external-content
# index (`content='search_records'`); INSERT/UPDATE/DELETE triggers keep it in sync.
class Search::Record::Sqlite
  FTS5_TABLES_NAME = 'search_records_fts5'
  CONTENT_TABLES_NAME = 'search_records'

  class << self
    def matching(expression)
      ensure_fts5_triggers!
      table_name = Search::Record.table_name
      Search::Record.joins("INNER JOIN #{FTS5_TABLES_NAME} ON #{FTS5_TABLES_NAME}.rowid = #{table_name}.id")
                    .where("#{FTS5_TABLES_NAME} MATCH ?", expression)
    end

    def search(user:, search_term:, limits:)
      expression = Search::TermBuilder.build(search_term)
      search_expression(user:, expression:, limits:)
    end

    def search_expression(user:, expression:, limits:)
      ensure_fts5_triggers!
      return Search::Record.none if expression.blank?

      table_name = Search::Record.table_name
      matching(expression)
        .where(user_id: user.id)
        .select("#{table_name}.*", "bm25(#{FTS5_TABLES_NAME}, 10.0, 1.0) AS fts5_rank")
        .order(Arel.sql('fts5_rank'))
        .limit(limits)
    end

    # Idempotent: safe after schema:load (schema.rb does not dump triggers).
    def ensure_fts5_triggers!
      return unless connection.adapter_name.match?(/sqlite/i)
      return unless connection.data_source_exists?(CONTENT_TABLES_NAME)
      return if fts5_trigger_installed?

      connection.transaction do
        install_fts5_triggers!
        rebuild_fts5_index!
      end
    end

    def install_fts5_triggers!
      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_ai AFTER INSERT ON #{CONTENT_TABLES_NAME} BEGIN
          INSERT INTO #{FTS5_TABLES_NAME}(rowid, search_name, search_body)
          VALUES (new.id, new.search_name, new.search_body);
        END;
      SQL

      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_ad AFTER DELETE ON #{CONTENT_TABLES_NAME} BEGIN
          INSERT INTO #{FTS5_TABLES_NAME}(#{FTS5_TABLES_NAME}, rowid, search_name, search_body)
          VALUES ('delete', old.id, old.search_name, old.search_body);
        END;
      SQL

      connection.execute(<<~SQL)
        CREATE TRIGGER IF NOT EXISTS search_records_au AFTER UPDATE ON #{CONTENT_TABLES_NAME} BEGIN
          INSERT INTO #{FTS5_TABLES_NAME}(#{FTS5_TABLES_NAME}, rowid, search_name, search_body)
          VALUES ('delete', old.id, old.search_name, old.search_body);
          INSERT INTO #{FTS5_TABLES_NAME}(rowid, search_name, search_body)
          VALUES (new.id, new.search_name, new.search_body);
        END;
      SQL
    end

    def rebuild_fts5_index!
      connection.execute("INSERT INTO #{FTS5_TABLES_NAME}(#{FTS5_TABLES_NAME}) VALUES('rebuild')")
    end

    def fts5_trigger_installed?
      connection.select_value(<<~SQL).to_i == 3
        SELECT COUNT(*) FROM sqlite_master
        WHERE type = 'trigger'
          AND name IN ('search_records_ai', 'search_records_ad', 'search_records_au')
      SQL
    end

    private

    def connection
      Search::Record.connection
    end
  end
end
