require 'spec_helper'

describe NotificationTracer::Subscriber do

  def notify(event,payload)
    ActiveSupport::Notifications.instrument(event, payload)
  end

  after do
    klass = ActiveSupport::Notifications
    klass.notifier = klass.notifier.class.new
  end

  describe '.initialize' do
    it 'sets the pattern' do
      regexp = /foobar/
      inst = described_class.new(pattern: regexp, callback: nil)
      expect(inst.pattern).to equal regexp
    end

    it 'freezes the pattern' do
      inst = described_class.new(pattern: "foo", callback: nil)
      expect(inst.pattern).to be_frozen
    end

    it 'defaults the cleaner to a new ActiveSupport::BacktraceCleaner' do
      inst = described_class.new(pattern: "", callback: nil)
      expect(inst.cleaner).to be_a ActiveSupport::BacktraceCleaner
    end

    it 'sets the cleaner if passed' do
      cleaner = instance_double(ActiveSupport::BacktraceCleaner, clean: [])
      inst = described_class.new(pattern: "", callback: nil, cleaner: cleaner)
      expect(inst.cleaner).to equal cleaner
    end

    it 'raises if the cleaner is invalid' do
      expect { described_class.new(pattern: "", callback: nil, cleaner: Object.new)
             }.to raise_error(ArgumentError, /cleaner must respond to clean/)
    end
  end

  describe '.subscribed?' do
    let(:inst) { described_class.new(pattern: 'foo.bar', callback: nil) }

    it 'defaults to false' do
      expect(inst.subscribed?).to eql false
    end

    it 'is true after calling .subscribe' do
      inst.subscribe
      expect(inst.subscribed?).to eql true
    end

    it 'is false after calling .unsubscribe' do
      inst.subscribe
      inst.unsubscribe
      expect(inst.subscribed?).to eql false
    end

    it 'is false if the internal subscriber is removed' do
      inst.subscribe
      ActiveSupport::Notifications.unsubscribe('foo.bar')
      expect(inst.subscribed?).to eql false
    end
  end

  describe '.subscribe' do
    let(:inst) { described_class.new(pattern: @pattern, callback: fn) }
    let(:fn)   { instance_double(Proc) }

    context 'exact matching' do
      before{ @pattern = 'foo.bar' }

      it 'forwards matching events to the callback' do
        expect(fn).to receive(:call).with(hash_including(payload: {is: 1}))
        inst.subscribe
        notify('foo.bar', {is: 1})
      end

      it 'does not forward non-matching events to the callback' do
        expect(fn).not_to receive(:call)
        inst.subscribe
        notify('bar.foo', {is: 1})
      end

      it 'handles many events' do
        expect(fn).to receive(:call).with(hash_including(payload: {is: 3}))
        inst.subscribe
        notify('bar.foo', {is: 1})
        notify('abc.123', {is: 2})
        notify('foo.bar', {is: 3})
        notify('123.abc', {is: 4})
        notify('embargo', {is: 5})
      end
    end

    context 'pattern matching' do
      before{ @pattern = /bar/ }

      it 'forwards matching events to the callback' do
        expect(fn).to receive(:call).with(hash_including(payload: {is: 1}))
        inst.subscribe
        notify('foo.bar', {is: 1})
      end

      it 'does not forward non-matching events to the callback' do
        expect(fn).not_to receive(:call)
        inst.subscribe
        notify('abc.123', {is: 1})
      end

      it 'handles many events' do
        expect(fn).to receive(:call).with(hash_including(payload: {is: 1}))
        expect(fn).to receive(:call).with(hash_including(payload: {is: 3}))
        expect(fn).to receive(:call).with(hash_including(payload: {is: 5}))
        inst.subscribe
        notify('bar.foo', {is: 1})
        notify('abc.123', {is: 2})
        notify('foo.bar', {is: 3})
        notify('123.abc', {is: 4})
        notify('embargo', {is: 5})
      end
    end

    it 'can resubscribe if the internal subscriber is removed' do
      expect(fn).to receive(:call).with(hash_including(payload: {is: 2}))
      @pattern = 'foo.bar'
      inst.subscribe
      ActiveSupport::Notifications.unsubscribe('foo.bar')
      notify('foo.bar', {is: 1})
      inst.subscribe
      notify('foo.bar', {is: 2})
    end

    it 'passes the correct options to the callback' do
      expect(fn).to receive(:call).with(
        stack: instance_of(Array),
        payload: {is: 1},
        duration: instance_of(Float),
        event_id: instance_of(String),
        event_name: 'foo.bar'
      )
      @pattern = /foo/
      inst.subscribe
      notify('foo.bar', {is: 1})
    end

    it 'can be called many times without adverse effects' do
      expect(fn).to receive(:call).once
      @pattern = /foo/
      inst.subscribe.subscribe.subscribe.subscribe.subscribe
      notify('foo.bar', {is: 1})
    end

    context 'subscription process fails' do
      before do
        @pattern = /foo/
        expect(ActiveSupport::Notifications).to receive(:subscribe)
      end

      it 'raises by default' do
        expect { inst.subscribe }.to raise_error(
          NotificationTracer::SubscriptionError, /^subscribe failed/)
      end

      it 'does not raise if silent is true' do
        inst.subscribe(silent: true)
      end
    end
  end

  describe '.unsubscribe' do
    let(:inst) { described_class.new(pattern: /foo/, callback: fn) }
    let(:fn)   { instance_double(Proc) }

    it 'stops consuming notification events' do
      expect(fn).to receive(:call).with(hash_including(payload: {is: 1}))
      inst.subscribe
      notify('foo.bar', {is: 1})
      inst.unsubscribe
      notify('foo.bar', {is: 2})
    end

    it 'can be called many times without adverse effects' do
      expect(fn).not_to receive(:call)
      inst.subscribe
      inst.unsubscribe.unsubscribe.unsubscribe.unsubscribe
      notify('foo.bar', {is: 1})
    end

    context 'subscription removal fails' do
      before do
        inst.subscribe
        expect(ActiveSupport::Notifications).to receive(:unsubscribe)
      end

      it 'raises by default' do
        expect { inst.unsubscribe }.to raise_error(
          NotificationTracer::SubscriptionError, /^unsubscribe failed/)
      end

      it 'does not raise if silent is true' do
        inst.unsubscribe(silent: true)
      end
    end
  end

  context 'stack trace cleaning' do
    let(:fn)   { instance_double(Proc) }

    it 'is the equivalent of the identity transformation by default' do
      inst = described_class.new(pattern: /foo/, callback: fn)
      stack = ['qwe','rty','uio']
      expect(inst).to receive(:caller).and_return(stack)
      expect(fn).to receive(:call).with(hash_including(stack: stack))
      inst.subscribe
      notify('foo.bar', {})
    end

    it 'transforms the call stack using cleaner.clean' do
      expect(cleaner = double).to receive(:clean).and_return(%w{ a b c })
      inst = described_class.new(pattern: /foo/, callback: fn, cleaner: cleaner)
      expect(inst).to receive(:caller).and_return(['qwe','rty','uio'])
      expect(fn).to receive(:call).with(hash_including(stack: %w{ a b c }))
      inst.subscribe
      notify('foo.bar', {})
    end
  end

end
