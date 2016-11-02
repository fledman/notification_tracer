module NotificationTracer
  class Subscriber
    attr_reader :event

    def initialize(event:)
      @event = event.freeze
    end

    def subscribed?
      !!real_subscriber
    end

    def subscribe(silent: false)
      @real_subscriber ||= notifier.subscribe(event)
      subscription_error('subscribe') if !silent && !subscribed?
      self
    end

    def unsubscribe(silent: false)
      notifier.unsubscribe(real_subscriber) if real_subscriber
      subscription_error('unsubscribe') if !silent && subscribed?
      self
    end

    private

    attr_reader :real_subscriber

    def notifier
      ActiveSupport::Notifications
    end

    def subscription_error(type)
      raise SubscriptionError, "#{type} failed for #{event}"
    end

  end
end

#   ActiveSupport::Notifications.subscribe('render') do |name, start, finish, id, payload|
#     name    # => String, name of the event (such as 'render' from above)
#     start   # => Time, when the instrumented block started execution
#     finish  # => Time, when the instrumented block ended execution
#     id      # => String, unique ID for this notification
#     payload # => Hash, the payload
#   end
