# frozen_string_literal: true

module SearchIndexFailureHelper
  def with_search_index_failure(*events)
    events.each { |event| install_index_failure_trigger(event) }
    yield
  ensure
    events.each do |event|
      Search::Record.connection.execute("DROP TRIGGER IF EXISTS fail_search_index_#{event.downcase}")
    end
  end

  private

  def install_index_failure_trigger(event)
    Search::Record.connection.execute(<<~SQL)
      CREATE TEMP TRIGGER fail_search_index_#{event.downcase}
      BEFORE #{event} ON search_records
      BEGIN
        SELECT RAISE(ABORT, 'search index unavailable');
      END;
    SQL
  end
end
