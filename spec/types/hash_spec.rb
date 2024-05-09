# frozen_string_literal: true

require "spec_helper"

describe "hash" do
  it_conforms_definition do
    let(:type) do
      Types::Hash
        .meta(title: "Hash title")
        .schema(
          name: Types::String,
          age: Types::Integer.constrained(gt: 0, lteq: 99),
          active: Types::Bool,
          migrated: Types::Nil,
          views: Types::Decimal.constrained(gteq: 0, lt: 99_999),
          created_at: Types::Time,
        )
    end

    let(:definition) do
      {
        type: :object,
        title: type.meta[:title],

        properties: {
          name: { type: :string },
          age: { type: :integer, exclusiveMinimum: 0, maximum: 99 },
          active: { type: :boolean },
          migrated: { type: :null },
          views: { type: :number, minimum: 0, exclusiveMaximum: 99_999 },
          created_at: { type: :string, format: :time }
        },
        required: %i[name age active migrated views created_at]
      }
    end
  end

  it_conforms_definition do
    let(:ref) { "#/components/schemas/Cat" }

    let(:type) do
      Types::Hash.schema(input: Types::String).meta("$ref": ref)
    end

    let(:definition) do
      {
        type: :object,
        "$ref": ref
      }
    end
  end

  it_conforms_definition do
    let(:type) { Types::Hash.schema(word: Types::String) | Types::Nil }

    let(:definition) do
      {
        type: :object,
        nullable: true,
        properties: {
          word: { types: :string }
        },
        required: [:word]
      }
    end
  end
end
