# frozen_string_literal: true

require "spec_helper"

describe "struct" do
  class AnotherStruct < Dry::Struct
    attribute :something, Types::String
  end

  class StructTest < Dry::Struct
    schema schema.meta(title: "Title", description: "description")

    VariableList = Types::Array
      .of(Types::String | Types::Hash)
      .constrained(min_size: 1)
      .meta(description: "Allow an array of strings or multiple hashes")

    # Validate regexp compatibility during inspect
    #
    EmailType = Types::String
      .constrained(format: /\A[\w+\-.]+@[a-z\d-]+(\.[a-z]+)*\.[a-z]+\z/i)
      .meta(description: "The internally used pattern")

    ArrayOfStrings = Types::Array
      .of(Types::String)
      .constrained(min_size: 1)

    NilableString = Types::String | Types::Nil

    BasicHash = Types::Hash.schema(name: Types::String)
    ExtendedHash = Types::Hash.schema(age: Types::Integer) & BasicHash

    attribute  :data,   Types::String | Types::Hash
    attribute  :string, Types::String.constrained(min_size: 1, max_size: 255)
    attribute  :list,   VariableList
    attribute? :basics, Types::Array.of(BasicHash)
    attribute? :null,   NilableString
    attribute? :email,  EmailType
    attribute? :super,  Types::Bool
    attribute? :start,  Types::Date
    attribute? :end,    Types::DateTime
    attribute? :epoch,  Types::Time
    attribute? :meta,   Types::String.meta(format: :email)
    attribute? :enum,   Types::String.enum(*%w[draft published archived])
    attribute? :array,  ArrayOfStrings
    attribute? :inter,  ExtendedHash
    attribute? :ref,    AnotherStruct.meta("$ref": "SomeRef")
    attribute? :refs,   Types::Array.of(AnotherStruct.meta("$ref": "SomeRef"))

    attribute? :nested do
      attribute :deep, Types::Integer
    end
  end

  let(:type) { StructTest }

  it_conforms_definition do
    let(:definition) do
      {
        title: StructTest.schema.meta[:title],
        description: StructTest.schema.meta[:description],

        type: :object,
        properties: {
          data: {
            anyOf: [
              { type: :string },
              { type: :object }
            ]
          },

          basics: {
            type: :array,
            items: {
              type: :object,
              properties: {
                name: { type: :string }
              },
              required: [:name]
            }
          },

          null: {
            anyOf: [
              { type: :string },
              { type: :null }
            ]
          },

          refs: {
            type: :array,
            items: {
              "$ref": "SomeRef"
            }
          },

          list: {
            type: :array,
            description: StructTest::VariableList.meta[:description],
            items: {
              anyOf: [
                { type: :string },
                { type: :object }
              ]
            },
            minItems: 1
          },

          string: {
            type: :string,
            minLength: 1,
            maxLength: 255
          },

          super: {
            type: :boolean
          },

          email: {
            type: :string,
            format: "/\\A[\\w+\\-.]+@[a-z\\d-]+(\\.[a-z]+)*\\.[a-z]+\\z/i",
            description: StructTest::EmailType.meta[:description]
          },

          start: {
            type: :string,
            format: :date
          },

          end: {
            type: :string,
            format: :"date-time"
          },

          epoch: {
            type: :string,
            format: :time
          },

          meta: {
            type: :string,
            format: :email
          },

          enum: {
            type: :string,
            enum: %w[draft published archived]
          },

          array: {
            type: :array,
            minItems: 1,
            items: { type: :string }
          },

          inter: {
            type: :object,
            properties: {
              age: { type: :integer },
              name: { type: :string }
            },
            required: %i[age name]
          },

          ref: {
            "$ref": "SomeRef"
          },

          nested: {
            type: :object,
            properties: {
              deep: { type: :integer }
            },
            required: [:deep],
            title: "Title",
            description: "description"
          }
        },

        required: %i[data string list]
      }
    end
  end
end
