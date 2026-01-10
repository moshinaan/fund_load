# frozen_string_literal: true

require 'bigdecimal'
require 'date'
require 'time'

module FundLoad
  class Processor
    DAILY_AMOUNT_LIMIT_CENTS = 500_000
    WEEKLY_AMOUNT_LIMIT_CENTS = 2_000_000
    DAILY_ATTEMPT_LIMIT = 3

    def initialize
      @daily_amounts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @weekly_amounts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @daily_attempts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    end

    def adjudicate(load)
      customer_id = load.fetch('customer_id')
      time = Time.parse(load.fetch('time')).utc
      day_key = time.to_date.iso8601
      week_key = [time.to_date.cwyear, time.to_date.cweek]

      # Assumption: daily attempt limits count every load attempt, even if declined.
      attempts_today = @daily_attempts[customer_id][day_key]
      over_attempt_limit = attempts_today >= DAILY_ATTEMPT_LIMIT

      amount_cents = parse_amount_cents(load.fetch('load_amount'))

      # Assumption: daily/weekly amount limits track only accepted loads.
      daily_total = @daily_amounts[customer_id][day_key]
      weekly_total = @weekly_amounts[customer_id][week_key]

      over_daily_amount = (daily_total + amount_cents) > DAILY_AMOUNT_LIMIT_CENTS
      over_weekly_amount = (weekly_total + amount_cents) > WEEKLY_AMOUNT_LIMIT_CENTS

      accepted = !(over_attempt_limit || over_daily_amount || over_weekly_amount)

      @daily_attempts[customer_id][day_key] += 1
      if accepted
        @daily_amounts[customer_id][day_key] += amount_cents
        @weekly_amounts[customer_id][week_key] += amount_cents
      end

      accepted
    end

    private

    # Assumption: week boundaries follow ISO-8601 weeks (Monday start).
    def parse_amount_cents(amount)
      (BigDecimal(amount.delete('$')) * 100).to_i
    end
  end
end
