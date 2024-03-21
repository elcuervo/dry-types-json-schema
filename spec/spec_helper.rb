# frozen_string_literal: true

require "minitest/autorun"
require "json_schemer"

require "dry/struct"
require "dry/types"
require "dry/types/extensions"

Dry::Types.load_extensions(:json_schema)

class Minitest::Spec
  class << self
    def it_conforms_definition(&block)
      instance_exec(&block) if block

      describe "conforms the schema definition" do
        it { assert_equal type.json_schema, definition }
        it { assert JSONSchemer.schema(type.json_schema.to_json).valid_schema? }
      end
    end
  end
end
