# frozen_string_literal: true

module Dry
  module Types
    class JSONSchema
      EMPTY_HASH = {}.freeze
      IDENTITY = ->(v, _) { v }.freeze
      TO_INTEGER = ->(v, _) { v.to_i }.freeze

      PREDICATE_TO_TYPE = {
        String:     { type: :string },
        Integer:    { type: :integer },
        TrueClass:  { type: :boolean },
        FalseClass: { type: :boolean },
        NilClass:   { type: :null }
      }.freeze

      def initialize(root: false)
        @keys = EMPTY_HASH.dup
        @root = root
      end

      def root? = @root

      def call(ast)
        visit(ast)
      end

      def to_hash
        result = @keys.to_hash
        result[:$schema] = "http://json-schema.org/draft-06/schema#" if root?
        result
      end

      def visit(node, opts = EMPTY_HASH)
        name, rest = node
        public_send(:"visit_#{name}", rest, opts)
      end

      def visit_constrained(node, opts = EMPTY_HASH)
        node.each { |it| visit(it, opts) }
      end

      def visit_constructor(node, opts = EMPTY_HASH)
        type, _ = node

        visit(type, opts)
      end

      def visit_nominal(node, opts = EMPTY_HASH)
        type, _ = node
        type
      end

      def visit_predicate(node, opts = EMPTY_HASH)
        name, ((_, type), input) = node

        if name == :type?
          definition = PREDICATE_TO_TYPE[type.to_s.to_sym]

          return unless definition

          ctx = opts[:key]

          @keys[ctx] = definition
        end
      end

      def visit_sum(node, opts = EMPTY_HASH)
        *types, meta = node

        # FIXME
        result = types.map do |type|
          self.class.new
            .tap { |target| target.visit(type) }
            .to_hash
            .values
            .first
        end.uniq

        return @keys[opts[:key]] = result.first if result.count == 1

        @keys[opts[:key]] = { anyOf: result }
      end

      def visit_hash(node, opts = EMPTY_HASH)
        part, meta = node

        @keys[opts[:key]] = { type: :object }
      end

      def visit_schema(node, opts = EMPTY_HASH)
        keys, options, meta = node

        target = self.class.new

        keys.each { |fragment| target.visit(fragment, opts) }

        definition = { type: :object, properties: target.to_hash }

        @keys.merge!(definition)
      end

      def visit_key(node, opts = EMPTY_HASH)
        name, required, rest = node

        visit(rest, opts.merge(key: name))
      end
    end

    module Builder
      def json_schema(root: false)
        compiler = JSONSchema.new(root: root)
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
