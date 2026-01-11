# frozen_string_literal: true

require 'rspec'
require_relative '../lib/fund_load/processor'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
end
