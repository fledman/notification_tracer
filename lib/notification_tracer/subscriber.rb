module NotificationTracer
  class Subscriber
    attr_reader :pattern, :cleaner

    def initialize(pattern:, callback:, cleaner: nil)
      @pattern  = pattern.freeze
      @callback = callback
      @cleaner  = setup_cleaner(cleaner)
    end

    def subscribed?
      !!real_subscriber && listening?
    end

    def subscribe(silent: false)
      @real_subscriber = nil if real_subscriber && !listening?
      @real_subscriber ||= notifier.subscribe(pattern) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        trace(event: event, stack: caller)
      end
      subscription_error('subscribe') if !silent && !subscribed?
      self
    end

    def unsubscribe(silent: false)
      if real_subscriber
        notifier.unsubscribe(real_subscriber)
        if listening?
          subscription_error('unsubscribe') if !silent
        else
          @real_subscriber = nil
        end
      end
      self
    end

    private

    attr_reader :real_subscriber, :callback

    def notifier
      ActiveSupport::Notifications
    end

    def subscription_error(type)
      raise SubscriptionError, "#{type} failed for #{pattern}"
    end

    def setup_cleaner(input)
      if input.nil?
        ActiveSupport::BacktraceCleaner.new
      elsif input.respond_to?(:clean)
        input
      else
        raise ArgumentError, "cleaner must respond to clean: #{input.inspect}"
      end
    end

    def listening?
      name = pattern.is_a?(Regexp) ? pattern.source : pattern
      notifier.notifier.listeners_for(name).include?(real_subscriber)
    end

    def trace(event:, stack:)
      callback.call(
             stack: cleaner.clean(stack),
           payload: event.payload,
          duration: event.duration,
          event_id: event.transaction_id,
        event_name: event.name
      )
    end

  end
end
