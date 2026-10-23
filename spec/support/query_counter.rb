##
# Counts the SQL statements issued inside a block, grouped by verb,
# so specs can assert that a chunk is persisted in bulk.
##
module QueryCounter
  IGNORED = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|ROLLBACK TO)/i
  # Statements on the Import record itself are bookkeeping, not row persistence
  IMPORTS_TABLE = /["`]imports["`]/

  def count_queries
    counts = Hash.new(0)
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == 'SCHEMA' || sql =~ IGNORED || sql =~ IMPORTS_TABLE
      counts[sql[/\A\s*(\w+)/, 1].to_s.upcase] += 1
    end
    yield
    counts
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
