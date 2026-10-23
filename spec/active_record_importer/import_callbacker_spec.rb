require 'spec_helper'

RSpec.describe ActiveRecordImporter::ImportCallbacker do
  let(:object) { User.new(first_name: 'Ann') }

  it 'calls a symbol method on the object' do
    expect(object).to receive(:activate)
    described_class.new(object, :activate).call
  end

  it 'calls a proc with the object' do
    received = nil
    described_class.new(object, proc { |o| received = o }).call

    expect(received).to be(object)
  end

  it 'runs every callback of an array' do
    received = []
    expect(object).to receive(:archive)
    described_class.new(object, [:archive, proc { |o| received << o }]).call

    expect(received).to eq([object])
  end
end
