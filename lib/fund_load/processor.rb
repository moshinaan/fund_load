# frozen_string_literal: true

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

    def adjudicate(data)
      customer_id = data.fetch('customer_id')
      time = Time.parse(data.fetch('time')).utc
      day_key = time.to_date.iso8601
      week_key = [time.to_date.cwyear, time.to_date.cweek]

      amount_cents = parse_amount_cents(data.fetch('load_amount'))

      accepted = !(
        limit_attempt(customer_id, day_key) ||
        limit_over_daily_amount(customer_id, day_key, amount_cents) ||
        limit_over_weekly_amount(customer_id, week_key, amount_cents)
      )

      @daily_attempts[customer_id][day_key] += 1
      if accepted
        @daily_amounts[customer_id][day_key] += amount_cents
        @weekly_amounts[customer_id][week_key] += amount_cents
      end

      accepted
    end

    private

    def parse_amount_cents(amount)
      normalized = amount.delete('$')
      dollars, cents = normalized.split('.', 2)
      cents = cents.to_s.ljust(2, '0')[0, 2]

      (dollars.to_i * 100) + cents.to_i
    end

    def limit_attempt(customer_id, day_key)
      attempts_today = @daily_attempts[customer_id][day_key]
      attempts_today >= DAILY_ATTEMPT_LIMIT
    end

    def limit_over_daily_amount(customer_id, day_key, amount_cents)
      daily_total = @daily_amounts[customer_id][day_key]
      (daily_total + amount_cents) > DAILY_AMOUNT_LIMIT_CENTS
    end

    def limit_over_weekly_amount(customer_id, week_key, amount_cents)
      weekly_total = @weekly_amounts[customer_id][week_key]
      (weekly_total + amount_cents) > WEEKLY_AMOUNT_LIMIT_CENTS
    end
  end
end
