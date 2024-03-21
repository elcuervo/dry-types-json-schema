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
          age: Dry::Types["integer"].constrained(gt: 0, lteq: 99),
          active: Dry::Types["bool"],
          migrated: Dry::Types["nil"],
          views: Dry::Types["decimal"].constrained(gteq: 0, lt: 99_999),
        )
    end

    it_conforms_definition do
      let(:definition) do
        {
          type: :object,
          properties: {
            name: { type: :string },
            age: { type: :integer, exclusiveMinimum: 0, maximum: 99 },
            active: { type: :boolean },
            migrated: { type: :null },
            views: { type: :number, minimum: 0, exclusiveMaximum: 99_999 }
          }
        }
      end
    end
  end

  describe "struct" do
    class StructTest < Dry::Struct
      VariableList = Types::Array
        .of(Types::String | Types::Hash)
        .constrained(min_size: 1)

      attribute :data,   Types::String | Types::Hash
      attribute :string, Types::String.constrained(min_size: 1, max_size: 255)
      attribute :list,   VariableList
    end

    let(:type) { StructTest.schema }


    it_conforms_definition do
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
              },
              minLength: 1
            },
            string: {
              type: :string,
              minLength: 1,
              maxLength: 255
            }
          }
        }
      end
    end
  end
end
