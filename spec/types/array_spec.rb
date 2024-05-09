# frozen_string_literal: true

require "spec_helper"

describe "array" do
  it_conforms_definition do
    let(:type) do
      Types::Array
        .of(Types::Integer)
        .constrained(min_size: 1, max_size: 100)
    end

    let(:definition) do
      {
        type: :array,
        minItems: 1,
        maxItems: 100,
        items: { type: :integer }
      }
    end
  end

  it_conforms_definition do
    let(:ref)    { "#/some/path/Schema" }
    let(:schema) { Types::Hash.schema(age: Types::Integer) }
    let(:type)   { Types::Array.of(schema.meta("$ref": ref)) }

    let(:definition) do
      {
        type: :array,
        items: {
          "$ref": ref
        }
      }
    end
  end

  it_conforms_definition do
    let(:object) do
      Types::Hash
        .schema(id: Types::Integer)
    end

    let(:type) do
      Types::Array
        .of(object)
        .constrained(min_size: 1, max_size: 100)
    end

    let(:definition) do
      {
        type: :array,
        minItems: 1,
        maxItems: 100,
        items: {
          type: :object,
          properties: {
            id: { type: :integer }
          },
          required: [:id]
        }
      }
    end
  end
end

