# frozen_string_literal: true

require "dry/types"

Dry::Types.register_extension(:json_schema) do
  require "dry/types/extensions/json_schema"
end
