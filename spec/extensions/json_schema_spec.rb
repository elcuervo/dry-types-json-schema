# frozen_string_literal: true

require "spec_helper"

describe Dry::Types::JSONSchema do
  describe "simple types" do
    let(:type) do
      Dry::Types["hash"]
        .schema(
          name: Dry::Types["string"],
          age: Dry::Types["integer"],
          active: Dry::Types["bool"]
        )
    end

    let(:definition) do
      {
        type: :object,
        properties: {
          name: { type: :string },
          age: { type: :integer },
          active: { type: :boolean }
        }
      }
    end

    it do
      assert_equal type.json_schema, definition
    end
  end
end
