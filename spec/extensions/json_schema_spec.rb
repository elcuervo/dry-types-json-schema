# frozen_string_literal: true

require "spec_helper"

describe Dry::Types::JSONSchema do
  module Types
    include Dry.Types()
  end

  describe "basic" do
    it_conforms_definition do
      let(:title) { "Title" }
      let(:type) { Dry::Types["string"].meta(format: :email, title: title) }

      let(:definition) do
        { type: :string, format: :email, title: title }
      end
    end
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
          created_at: Dry::Types["time"]
        ).meta(title: "Hash title")
    end

    it_conforms_definition do
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
  end

  describe "struct" do
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

      attribute  :data,   Types::String | Types::Hash
      attribute  :string, Types::String.constrained(min_size: 1, max_size: 255)
      attribute  :list,   VariableList
      attribute? :email,  EmailType
      attribute? :super,  Types::Bool
      attribute? :start,  Types::Date
      attribute? :end,    Types::DateTime
      attribute? :epoch,  Types::Time
      attribute? :meta,   Types::String.meta(format: :email)
      attribute? :enum,   Types::String.enum(*%w[draft published archived])
      attribute? :array,  ArrayOfStrings
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
end
