# frozen_string_literal: true

require "spec_helper"

describe Dry::Types::JSONSchema do
  module Types
    include Dry.Types()
  end

  describe "hash" do
    let(:type) do
      Dry::Types["hash"]
        .schema(
          name: Dry::Types["string"],
          age: Dry::Types["integer"],
          active: Dry::Types["bool"],
          migrated: Dry::Types["nil"]
        )
    end

    let(:definition) do
      {
        type: :object,
        properties: {
          name: { type: :string },
          age: { type: :integer },
          active: { type: :boolean },
          migrated: { type: :null }
        }
      }
    end

    it { assert_equal type.json_schema, definition }
  end

  describe "struct" do
    class StructTest < Dry::Struct
      attribute :data, Types::String | Types::Hash
      attribute :list, Types::Array.of(Types::String | Types::Hash)
    end

    let(:type) { StructTest.schema }

    let(:definition) do
      {
        type: :object,
        properties: {
          data: {
            anyOf: [
              { type: :string },
              { type: :object }
            ]
          },
          list: {
            type: :array,
            items: {
              anyOf: [
                { type: :string },
                { type: :object }
              ]
            }
          }
        }
      }
    end

    it { assert_equal type.json_schema, definition }
  end
end
