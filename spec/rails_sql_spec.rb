require 'spec_helper'

describe NotificationTracer::RailsSql do
  let(:matcher)   { instance_double(Proc) }
  let(:logger)    { instance_double(Proc) }
  let(:formatter) { instance_double(Proc) }

  def make(**opts)
    procs = { matcher: matcher, logger: logger, formatter: formatter }
    described_class.new(**procs.merge(opts))
  end

  after do
    klass = ActiveSupport::Notifications
    klass.notifier = klass.notifier.class.new
  end

  describe '.initialize' do
    it 'is disabled by default' do
      expect(make.enabled).to eql false
    end

    it 'sets lines to nil by default' do
      expect(make.lines).to be_nil
    end

    it 'accepts integer values for lines' do
      expect(make(lines: 12).lines).to eql 12
    end

    it 'accepts integer-strings for lines' do
      expect(make(lines: '5').lines).to eql 5
    end

    it 'raises for non-integral values' do
      expect { make(lines: 'ab') }.to raise_error(
        ArgumentError, /invalid value for Integer/)
    end

    context 'Subscriber object' do
      it 'gets created' do
        expect(make.send(:subscriber)).to be_a NotificationTracer::Subscriber
      end

      it 'has the correct pattern' do
        expect(make.send(:subscriber).pattern).to eql 'sql.active_record'
      end

      it 'has a Rails::BacktraceCleaner' do
        expect(make.send(:subscriber).cleaner).to be_a Rails::BacktraceCleaner
      end

      it 'silences framework code by default' do
        mock = instance_double(Rails::BacktraceCleaner, clean: [])
        expect(Rails::BacktraceCleaner).to receive(:new).and_return(mock)
        expect(mock).not_to receive(:remove_silencers!)
        expect(make.send(:subscriber).cleaner).to equal mock
      end

      it 'does not silence framework code if silence_rails_code is false' do
        mock = instance_double(Rails::BacktraceCleaner, clean: [])
        expect(Rails::BacktraceCleaner).to receive(:new).and_return(mock)
        expect(mock).to receive(:remove_silencers!)
        expect(make(silence_rails_code: false).send(:subscriber).cleaner).to equal mock
      end
    end
  end

  describe '.start' do
    let(:inst) { make }

    it 'sets enabled to true' do
      expect(inst.enabled).to eql false
      inst.start
      expect(inst.enabled).to eql true
    end

    it 'calls subscriber.subscribe' do
      expect(inst.send(:subscriber)).to receive(:subscribe)
      inst.start
    end
  end

  describe '.stop' do
    let(:inst) { make.start }

    it 'sets enabled to false' do
      expect(inst.enabled).to eql true
      inst.stop
      expect(inst.enabled).to eql false
    end

    it 'calls subscriber.unsubscribe' do
      expect(inst.send(:subscriber)).to receive(:unsubscribe)
      inst.stop
    end
  end

  describe '.pause' do
    let(:inst) { make.start }

    it 'sets enabled to false' do
      expect(inst.enabled).to eql true
      inst.pause
      expect(inst.enabled).to eql false
    end

    it 'does not call any subscriber methods' do
      expect(inst.send(:subscriber)).not_to receive(:subscribe)
      expect(inst.send(:subscriber)).not_to receive(:unsubscribe)
      inst.pause
    end
  end

  describe '.call' do
    let(:common) do
      { duration: 100, event_id: 'fedcba9876', event_name: 'sql.active_record' }
    end

    it 'returns if disabled' do
      expect(make.call(stack: [], payload: {}, **common)).to be_nil
    end

    let(:inst) { make.start }

    it 'does not match on SCHEMA queries' do
      schema = { name: 'SCHEMA' }
      expect(inst.call(stack: [], payload: schema, **common)).to be_nil
    end

    it 'does not match on CACHE queries' do
      cache = { name: 'CACHE' }
      expect(inst.call(stack: [], payload: cache, **common)).to be_nil
    end

    let(:sql) { 'select * from users' }

    let(:payload) { { name: 'OTHER', sql: sql } }

    it 'calls the matcher with the sql' do
      expect(matcher).to receive(:call).with(sql).and_return(false)
      expect(inst.call(stack: [], payload: payload, **common)).to be_nil
    end

    it 'returns if the stack is empty' do
      expect(matcher).to receive(:call).with(sql).and_return(true)
      stack = []
      expect(inst.call(stack: stack, payload: payload, **common)).to be_nil
    end

    it 'returns if the stack is all blank' do
      expect(matcher).to receive(:call).with(sql).and_return(true)
      stack = [nil, '', false]
      expect(inst.call(stack: stack, payload: payload, **common)).to be_nil
    end

    it 'calls the formatter with the data' do
      expect(matcher).to receive(:call).with(sql).and_return(true)
      expect(formatter).to receive(:call).with(
        sql: sql, stack: ['line 1', 'line 2', 'line 3'],
        duration: common[:duration], uuid: common[:event_id])
      stack = ['line 1', nil, 'line 2', '', 'line 3']
      expect(inst.call(stack: stack, payload: payload, **common)).to be_nil
    end

    it 'limits the number of stack frames if lines is set' do
      expect(matcher).to receive(:call).with(sql).and_return(true)
      expect(formatter).to receive(:call).with(
        sql: sql, stack: ['line 1'],
        duration: common[:duration], uuid: common[:event_id])
      expect(make(lines: 2).start.call(
          stack: ['line 1', nil, 'line 2', '', 'line 3'],
        payload: payload, **common)).to be_nil
    end

    it 'calls the logger with the output of the formatter' do
      expect(matcher).to receive(:call).with(sql).and_return(true)
      expect(formatter).to receive(:call).with(
        sql: sql, stack: ['line 1', 'line 2', 'line 3'],
        duration: common[:duration], uuid: common[:event_id]
      ).and_return("this is the formatted message")
      expect(logger).to receive(:call).with(
        "this is the formatted message").and_return(29)
      stack = ['line 1', nil, 'line 2', '', 'line 3']
      expect(inst.call(stack: stack, payload: payload, **common)).to eql 29
    end
  end

  context 'responding to events' do
    def notify(payload)
      ActiveSupport::Notifications.instrument(
        'sql.active_record', payload){ yield if block_given? }
    end

    let(:data){ {name: 'LOAD', sql: 'select * from users'} }

    context 'not started' do
      let(:inst) { make }

      it 'is not called for sql.active_record events' do
        expect(inst).not_to receive(:call)
        notify(data)
      end
    end

    context 'started' do
      let(:inst) { make.start }

      it 'is called for sql.active_record events' do
        expect(inst).to receive(:call).with({
          payload: data,
          event_name: 'sql.active_record',
          stack: instance_of(Array),
          duration: instance_of(Float),
          event_id: instance_of(String)
        })
        notify(data)
      end

      it 'gives the duration in milliseconds' do
        params = {}
        expect(inst).to receive(:call){ |**opts| params.merge!(opts) }
        notify(data){ sleep 0.1 }
        expect(params[:duration]).to be_within(5).of(100)
      end
    end
  end
end
