# frozen_string_literal: true

require "spec_helper"

describe Dry::Types::JSONSchema do
  describe "simple types" do
    let(:type) { Dry::Types["hash"].schema(name: Dry::Types["string"]) }

    let(:definition) do
      {
        type: :object,
        properties: {
          name: {
            type: "string"
          }
        }
      }
    end

    it do
      assert_equal type.json_schema, definition
    end
  end
end
