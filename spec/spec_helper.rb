# frozen_string_literal: true

require "simplecov"

SimpleCov.start

require "minitest/autorun"
require "json_schemer"
require "super_diff"

require "dry/struct"
require "dry/types"
require "dry/types/extensions"

Dry::Types.load_extensions(:json_schema)

module Types
  include Dry.Types()
end

module Minitest::Assertions
  def assert_equal_diff(expected, actual, msg = nil)
    assert_equal(expected, actual, msg)
  rescue Minitest::Assertion => e
    puts SuperDiff::Differs::Main.call(expected, actual)
    raise e
  end
end

class Minitest::Spec
  class << self
    def it_conforms_definition(&block)
      instance_exec(&block) if block

      describe "conforms the schema definition" do
        it { assert_equal_diff type.json_schema, definition }
        it { assert JSONSchemer.schema(type.json_schema.to_json).valid_schema? }
      end
    end
  end
end
