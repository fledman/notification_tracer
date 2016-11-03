require "notification_tracer/version"
require "active_support/notifications"
require "active_support/backtrace_cleaner"
require "notification_tracer/subscriber"
require "notification_tracer/rails_sql"
require "notification_tracer/sql_formatter"

module NotificationTracer
  extend self

  def rails_sql(matcher:, logger:, prefix: nil, **pass)
    RailsSql.new(
      formatter: SqlFormatter.new(prefix: prefix),
        matcher: matcher, logger: logger, **pass)
  end

end
