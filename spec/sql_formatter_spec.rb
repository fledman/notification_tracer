require 'spec_helper'

describe NotificationTracer::SqlFormatter do

  describe '.initialize' do
    it 'accepts a nil prefix' do
      inst = described_class.new(prefix: nil)
      expect(inst.prefix).to be_nil
    end

    it 'accepts a string prefix' do
      inst = described_class.new(prefix: 'PREFIX')
      expect(inst.prefix).to eql 'PREFIX'
    end

    it 'freezes a string prefix' do
      inst = described_class.new(prefix: 'PREFIX')
      expect(inst.prefix).to be_frozen
    end

    it 'raises when prefix is an empty string' do
      expect {
        described_class.new(prefix: '')
      }.to raise_error ArgumentError, /prefix should not be empty/
    end

    it 'raises when prefix is some other object' do
      expect {
        described_class.new(prefix: 555)
      }.to raise_error ArgumentError, "expected a String prefix, got: 555"
    end
  end

  describe '.call' do
    it 'returns a correctly formatted message' do
      expect(described_class.new.call(
        stack: ["line 1", "line 2", "line 3"],
        sql: "SELECT * FROM users WHERE first_name = 'David'",
        duration: 246,
        uuid: "a914b320e9"
      )).to eql(
        <<-MSG.gsub(/^\s{10}/,'').chomp
          Matching Query | 246 ms | #a914b320e9
           ** SQL: SELECT * FROM users WHERE first_name = 'David'
            >>> line 1
            >>> line 2
            >>> line 3
        MSG
      )
    end

    it 'replaces newlines in the sql statement' do
      sql = <<-SQL.gsub(/^\s+/,'').chomp
        SELECT id, amount, created_at
        FROM payments
        WHERE customer_id = 12345
      SQL
      expect(described_class.new.call(
        stack: ["abc", "123"],
        sql: sql,
        duration: 691,
        uuid: "b830edf12c"
      )).to eql(
        <<-MSG.gsub(/^\s{10}/,'').chomp
          Matching Query | 691 ms | #b830edf12c
           ** SQL: SELECT id, amount, created_at\\nFROM payments\\nWHERE customer_id = 12345
            >>> abc
            >>> 123
        MSG
      )
    end

    it 'prepends the prefix if present' do
      expect(described_class.new(prefix: 'DEBUG 54321').call(
        stack: ["code is here"],
        sql: "SELECT * FROM users WHERE first_name = 'David'",
        duration: 2048,
        uuid: "ba25c431fa"
      )).to eql(
        <<-MSG.gsub(/^\s{10}/,'').chomp
          DEBUG 54321 | Matching Query | 2048 ms | #ba25c431fa
           ** SQL: SELECT * FROM users WHERE first_name = 'David'
            >>> code is here
        MSG
      )
    end

    it 'still returns a message if the stack trace is empty' do
      expect(described_class.new.call(
        stack: [],
        sql: "SELECT * FROM events",
        duration: 123456,
        uuid: "c02948fab4"
      )).to eql(
        <<-MSG.gsub(/^\s{10}/,'').chomp
          Matching Query | 123456 ms | #c02948fab4
           ** SQL: SELECT * FROM events
        MSG
      )
    end
  end

end
