# NotificationTracer

A convenient way to process ActiveSupport notifications together with the call stack.

## Installation

Add `gem 'notification_tracer'` to your Gemfile.

## Usage

The `ActiveSupport::Notifications` API allows a consumer to subscribe to specific notification events that match a provided pattern. The `NotificationTracer::Subscriber` wraps and streamlines this process, passing matching event data to a callback: 

```ruby
subscriber = NotificationTracer::Subscriber.new(
   pattern: 'matches.notification',
  callback: ->(**opts){ puts opts.inspect }
)
```
**:pattern** can be either a `String` (exact matching) or a `Regexp` (pattern matching).

**:callback** must respond to `.call` with the following options:
 - **:stack** ==> the cleaned Ruby callstack 
 - **:payload** ==> an event-specific data hash
 - **:duration** ==> how long the event took
 - **:event_id** ==> a unique id for this event
 - **:event_name** ==> the full name of the event

`Subscriber` initialization also takes an optional parameter, **:cleaner**, for scrubbing the callstack. It is recommended to use an instance of `ActiveSupport::BacktraceCleaner` but any object with a `clean :: Array -> Array` method is acceptable.

You must explicitly call `.subscribe` on the `Subscriber` in order to start receiving events:
```ruby
:005 > subscriber.subscribed?
=> false 
:006 > subscriber.subscribe
=> #<NotificationTracer::Subscriber:0x007fb03b8b8628 @pattern="matches.notification", @callback=#<Proc:0x007fb03b8b8740@(irb):3 (lambda)>, @real_subscriber=#<ActiveSupport::Notifications::Fanout::Subscribers::Timed:0x007fb03b8836a8 ...> 
:007 > subscriber.subscribed?
=> true 
:008 > 10.times.each{ subscriber.subscribe } # no harm to recall subscribe
=> 10 
:009 > subscriber.subscribed?
=> true 
:010 > subscriber.unsubscribe
=> #<NotificationTracer::Subscriber:0x007fb03b8b8628 @pattern="matches.notification", @callback=#<Proc:0x007fb03b8b8740@(irb):3 (lambda)>, @real_subscriber=nil, ...> 
:011 > subscriber.subscribed?
=> false 
```

### Rails Specific

`NotificationTracer::RailsSql` provides out-of-the-box logging of `sql.active_record` events:
```ruby
tracer = NotificationTracer::RailsSql.new(
  matcher: <a callable that takes a sql string and returns true or false>,
  formatter: <a callable that merges :stack, :sql, :duration, and :uuid into a single output>,
  logger: <a callable that records the output of the formatter>,
  lines: <limits the stack trace to the first N lines, or nil for no limit>,
  silence_rails_code: <true or false, includes framework code in the stack trace>
)
tracer.start # subscribes & enables logging
tracer.pause # disables logging
tracer.stop  # unsubscribes & disables logging
```
An example **:formatter** can be found in `NotificationTracer::SqlFormatter`. This implementation converts the SQL event data into a String suitable for a text logger. It takes an optional parameter, **:prefix**, which prepends a given String to all messages.

For convenience, `NotificationTracer.rails_sql` creates a `RailsSql` instance with a `SqlFormatter` formatter:
```ruby
log_users_sql = NotificationTracer.rails_sql(
  prefix: 'DEBUG 2847428',
  logger: ->(msg){ Rails.logger.debug(msg) },
  matcher: ->(sql){ sql =~ /users/ }
); log_users_sql.start
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fledman/notification_tracer.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

