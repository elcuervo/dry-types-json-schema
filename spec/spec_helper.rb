# frozen_string_literal: true

require "minitest/autorun"
require "dry/types"
require "dry/types/extensions"

Dry::Types.load_extensions(:json_schema)
