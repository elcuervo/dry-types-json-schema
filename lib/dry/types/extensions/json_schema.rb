# frozen_string_literal: true

module Dry
  module Types
    class JSONSchema
      EMPTY_HASH = {}.freeze

      def call(ast)
        visit(ast)
      end

      def visit(node, opts = EMPTY_HASH)
        name, rest = node
        public_send(:"visit_#{name}", rest, opts)
      end

      def to_hash
        {}
      end
    end

    module Builder
      def json_schema
        compiler = JSONSchema.new
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
