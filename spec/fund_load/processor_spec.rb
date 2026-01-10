# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FundLoad::Processor do
  subject(:processor) { described_class.new }

  def build_load(id:, customer_id:, amount:, time:)
    {
      'id' => id,
      'customer_id' => customer_id,
      'load_amount' => amount,
      'time' => time
    }
  end

  it 'accepts loads within daily and weekly limits' do
    load = build_load(
      id: '1',
      customer_id: 'A',
      amount: '$100.00',
      time: '2023-01-01T00:00:00Z'
    )

    expect(processor.adjudicate(load)).to be(true)
  end

  it 'declines loads that exceed the daily amount limit' do
    first = build_load(
      id: '1',
      customer_id: 'A',
      amount: '$5000.00',
      time: '2023-01-01T00:00:00Z'
    )
    second = build_load(
      id: '2',
      customer_id: 'A',
      amount: '$0.01',
      time: '2023-01-01T01:00:00Z'
    )

    expect(processor.adjudicate(first)).to be(true)
    expect(processor.adjudicate(second)).to be(false)
  end

  it 'declines loads that exceed the weekly amount limit' do
    loads = [
      build_load(id: '1', customer_id: 'A', amount: '$10000.00', time: '2023-01-02T00:00:00Z'),
      build_load(id: '2', customer_id: 'A', amount: '$10000.00', time: '2023-01-03T00:00:00Z'),
      build_load(id: '3', customer_id: 'A', amount: '$0.01', time: '2023-01-04T00:00:00Z')
    ]

    expect(processor.adjudicate(loads[0])).to be(true)
    expect(processor.adjudicate(loads[1])).to be(true)
    expect(processor.adjudicate(loads[2])).to be(false)
  end

  it 'declines the fourth attempt in a single day' do
    loads = [
      build_load(id: '1', customer_id: 'A', amount: '$1.00', time: '2023-01-01T00:00:00Z'),
      build_load(id: '2', customer_id: 'A', amount: '$1.00', time: '2023-01-01T01:00:00Z'),
      build_load(id: '3', customer_id: 'A', amount: '$1.00', time: '2023-01-01T02:00:00Z'),
      build_load(id: '4', customer_id: 'A', amount: '$1.00', time: '2023-01-01T03:00:00Z')
    ]

    expect(processor.adjudicate(loads[0])).to be(true)
    expect(processor.adjudicate(loads[1])).to be(true)
    expect(processor.adjudicate(loads[2])).to be(true)
    expect(processor.adjudicate(loads[3])).to be(false)
  end

  it 'counts declined attempts toward the daily attempt limit' do
    first = build_load(
      id: '1',
      customer_id: 'A',
      amount: '$5000.00',
      time: '2023-01-01T00:00:00Z'
    )
    second = build_load(
      id: '2',
      customer_id: 'A',
      amount: '$0.01',
      time: '2023-01-01T01:00:00Z'
    )
    third = build_load(
      id: '3',
      customer_id: 'A',
      amount: '$0.01',
      time: '2023-01-01T02:00:00Z'
    )
    fourth = build_load(
      id: '4',
      customer_id: 'A',
      amount: '$0.01',
      time: '2023-01-01T03:00:00Z'
    )

    expect(processor.adjudicate(first)).to be(true)
    expect(processor.adjudicate(second)).to be(false)
    expect(processor.adjudicate(third)).to be(false)
    expect(processor.adjudicate(fourth)).to be(false)
  end
end
