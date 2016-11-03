module NotificationTracer
  class RailsSql
    attr_reader :enabled, :lines

    def initialize(matcher:, logger:, formatter:,
                   lines: nil, silence_rails_code: true)
      @enabled    = false
      @lines      = Integer(lines) if lines
      @matcher    = matcher
      @logger     = logger
      @formatter  = formatter
      @subscriber = make_subscriber(silence_rails_code: silence_rails_code)
    end

    def start
      @enabled = true
      subscriber.subscribe
      self
    end

    def pause
      @enabled = false
      self
    end

    def stop
      @enabled = false
      subscriber.unsubscribe
      self
    end

    def call(stack:, payload:, duration:, event_id:, event_name:)
      return unless enabled
      return unless matches?(payload)
      stack = stack[0..(lines-1)] if lines
      stack = stack.select{ |l| l && !l.empty? }
      return if stack.empty?
      data = formatter.call(stack: stack, sql: payload[:sql],
                            duration: duration, uuid: event_id)
      logger.call(data) if data
    end

    private

    attr_reader :matcher, :logger, :subscriber, :formatter

    def pattern
      'sql.active_record'
    end

    def make_subscriber(silence_rails_code:)
      cleaner = make_cleaner(silence_rails_code: silence_rails_code)
      Subscriber.new(pattern: pattern, callback: self, cleaner: cleaner)
    end

    def make_cleaner(silence_rails_code:)
      Rails::BacktraceCleaner.new.tap do |rbc|
        rbc.remove_silencers! unless silence_rails_code
      end
    end

    def matches?(payload)
      return false if payload[:name] == 'SCHEMA'
      return false if payload[:name] == 'CACHE'
      matcher.call(payload[:sql])
    end

  end
end
