require 'spec_helper'

describe NotificationTracer do
  it 'has a version number' do
    expect(NotificationTracer::VERSION).not_to be nil
  end

  describe '.rails_sql' do
    it 'builds a RailsSql with a SqlFormatter' do
      formatter = instance_double(NotificationTracer::SqlFormatter)
      options = {
        matcher: ->(sql){ !sql.empty? },
        logger: ->(msg){ puts msg },
        lines: 10, silence_rails_code: false
      }
      expect(NotificationTracer::SqlFormatter).to receive(:new
            ).with(prefix: 'PRE').and_return(formatter)
      expect(NotificationTracer::RailsSql).to receive(:new
            ).with(formatter: formatter, **options).and_call_original
      expect(NotificationTracer.rails_sql(prefix: 'PRE', **options)
            ).to be_a NotificationTracer::RailsSql
    end
  end
end
