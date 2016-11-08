$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'notification_tracer'
require 'pry'

unless defined?(Rails)
  module Rails
    class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    end
  end
end
