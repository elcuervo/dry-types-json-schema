# frozen_string_literal: true

require "spec_helper"

describe Dry::Types::JSONSchema do
  let(:type) { Dry::Types["strict.string"] }

  it do
    type.json_schema
  end
end
