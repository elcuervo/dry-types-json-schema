# frozen_string_literal: true

require "spec_helper"

describe "primitives" do
  it_conforms_definition do
    let(:title) { "Title" }
    let(:type) { Types::String.meta(format: :email, title: title) }

    let(:definition) do
      { type: :string, format: :email, title: title }
    end
  end

  it_conforms_definition do
    let(:type) { Types::String.enum(*%w[a b]) }

    let(:definition) do
      { type: :string, enum: %w[a b] }
    end
  end

  it_conforms_definition do
    let(:type) { Types::Hash }

    let(:definition) do
      { type: :object }
    end
  end
end
