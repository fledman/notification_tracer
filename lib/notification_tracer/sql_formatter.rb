module NotificationTracer
  class SqlFormatter
    attr_reader :prefix

    def initialize(prefix: nil)
      @prefix = ensure_non_empty_string(prefix) if prefix
    end

    def call(stack:, sql:, duration:, uuid:)
      message  = "Matching Query"
      message  = "#{prefix} | #{message}" if prefix
      message += " | #{duration} ms | ##{uuid}"
      message += "\n ** SQL: " + sql.gsub("\n",'\n')
      ([message] + stack).join("\n  >>> ")
    end

    private

    def ensure_non_empty_string(string)
      if string.is_a?(String)
        return string.freeze unless string.empty?
        raise ArgumentError, "prefix should not be empty, use nil instead"
      end
      raise ArgumentError, "expected a String prefix, got: #{string.inspect}"
    end

  end
end
