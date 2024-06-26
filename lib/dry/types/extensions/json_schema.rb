# frozen_string_literal: true

module Dry
  module Types
    # The `JSONSchema` class is responsible for converting dry-types type definitions into JSON Schema definitions.
    # This class enables the transformation of complex type constraints into a standardized JSON Schema format,
    # facilitating interoperability with systems that utilize JSON Schema for validation.
    #
    class JSONSchema
      # Error raised when an unknown predicate is encountered during schema generation.
      #
      UnknownPredicateError = Class.new(StandardError)

      # Constant definitions for various lambdas and mappings used throughout the JSON schema conversion process.
      #
      EMPTY_HASH = {}.freeze
      IDENTITY = ->(v, _) { v }.freeze
      INSPECT = ->(v, _) { v.inspect }.freeze
      TO_INTEGER = ->(v, _) { v.to_i }.freeze
      TO_ARRAY = ->(v, _) { Array(v) }.freeze
      TO_TYPE = ->(v, _) { CLASS_TO_TYPE.fetch(v.to_s.to_sym) }.freeze

      # Metadata annotations and allowed types overrides for schema generation.
      #
      ANNOTATIONS = %i[title description].freeze
      ALLOWED_TYPES_META_OVERRIDES = ANNOTATIONS.dup.concat([:format]).freeze

      # Mapping for array predicate overrides.
      #
      ARRAY_PREDICATE_OVERRIDE = {
        min_size?: :min_items?,
        max_size?: :max_items?
      }.freeze

      # Mapping of Ruby classes to their corresponding JSON Schema types.
      #
      CLASS_TO_TYPE = {
        String:     :string,
        Integer:    :integer,
        TrueClass:  :boolean,
        FalseClass: :boolean,
        NilClass:   :null,
        BigDecimal: :number,
        Float:      :number,
        Hash:       :object,
        Array:      :array,
        Date:       :string,
        DateTime:   :string,
        Time:       :string
      }.freeze

      # Additional properties for specific types, such as formatting options.
      #
      EXTRA_PROPS_FOR_TYPE = {
        Date:     { format: :date },
        Time:     { format: :time },
        DateTime: { format: :"date-time" }
      }.freeze

      # Mapping of predicate methods to their corresponding JSON Schema expressions.
      #
      PREDICATE_TO_TYPE = {
        type?:        { type: TO_TYPE },
        min_size?:    { minLength: TO_INTEGER },
        min_items?:   { minItems: TO_INTEGER },
        max_size?:    { maxLength: TO_INTEGER },
        max_items?:   { maxItems: TO_INTEGER },
        min?:         { maxLength: TO_INTEGER },
        gt?:          { exclusiveMinimum: IDENTITY },
        gteq?:        { minimum: IDENTITY },
        lt?:          { exclusiveMaximum: IDENTITY },
        lteq?:        { maximum: IDENTITY },
        format?:      { format: INSPECT },
        included_in?: { enum: TO_ARRAY }
      }.freeze

      # @return [Set] the set of required keys for the JSON Schema.
      #
      attr_reader :required, :keys

      # Initializes a new instance of the JSONSchema class.
      # @param root [Boolean] whether this schema is the root schema.
      # @param loose [Boolean] whether to ignore unknown predicates.
      #
      def initialize(root: false, loose: false)
        @keys = ::Hash.new { |h, k| h[k] = {} }
        @required = Set.new

        @root = root
        @loose = loose
      end

      # Checks if the schema is the root schema.
      # @return [Boolean] true if this is the root schema; otherwise, false.
      #
      def root?  = @root

      # Checks if unknown predicates are ignored.
      # @return [Boolean] true if ignoring unknown predicates; otherwise, false.
      #
      def loose? = @loose

      # Processes the abstract syntax tree (AST) and generates the JSON Schema.
      # @param ast [Array] the abstract syntax tree representing type definitions.
      # @return [void]
      #
      def call(ast)
        visit(ast)
      end

      # Converts the internal schema representation into a hash.
      # @return [Hash] the JSON Schema as a hash.
      #
      def to_hash
        result = keys.to_hash
        result[:$schema] = "http://json-schema.org/draft-06/schema#" if root?
        result
      end

      # Visits a node in the abstract syntax tree and processes it according to its type.
      # @param node [Array] the node to process.
      # @param opts [Hash] optional parameters for node processing.
      # @return [void]
      #
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
        type, meta = node

        return visit_nominal_with_key(node, opts) if opts.key?(:key)

        update meta.slice(*ALLOWED_TYPES_META_OVERRIDES) if meta.any?

        return update(items: { type: CLASS_TO_TYPE[type.to_s.to_sym] }) if opts.key?(:array)

        update(type: CLASS_TO_TYPE[type.to_s.to_sym])
      end

      def visit_predicate(node, opts = EMPTY_HASH)
        head, ((_, type),) = node
        ctx = opts[:key]

        head = ARRAY_PREDICATE_OVERRIDE.fetch(head) if opts[:left_type] == ::Array

        definition = PREDICATE_TO_TYPE.fetch(head) do
          raise UnknownPredicateError, head unless loose?

          EMPTY_HASH
        end.dup

        definition.transform_values! { |v| v.call(type, ctx) }

        return unless definition.any?

        if (extra = EXTRA_PROPS_FOR_TYPE[type.to_s.to_sym])
          definition = definition.merge(extra)
        end

        return update(definition) if ctx.nil?

        keys[ctx].update(definition)
      end

      def visit_intersection(node, opts = EMPTY_HASH)
        *types, _ = node

        result = types.map { |type| compile_type(type) }

        update(opts[:key] => deep_merge_items(result))
      end

      def visit_sum_with_key(node, opts = EMPTY_HASH)
        *types, _ = node

        result = types
          .map { |type| compile_value(type, { sum: true }.merge(opts)) }
          .uniq

        return update(opts[:key] => result.first) if result.count == 1

        return update(opts[:key] => { anyOf: result }) unless opts[:array]

        update(opts[:key] => { type: :array, items: { anyOf: result } })
      end

      def visit_sum(node, opts = EMPTY_HASH)
        return visit_sum_with_key(node, opts) if opts.key?(:key)

        *types, _ = node

        result = types
          .map { |type| compile_type(type, { sum: true }.merge(opts)) }
          .uniq

        null, sans_null = result.partition { |element| element[:type] == :null }

        return set sans_null.first.update(nullable: true) if sans_null.count == 1 && null

        return set result.first if result.count == 1

        return set({ anyOf: result }) unless opts[:array]

        set({ type: :array, items: { anyOf: result } })
      end

      def visit_and(node, opts = EMPTY_HASH)
        left, right = node
        (_, (_, ((_, left_type),))) = left

        visit(left, opts)
        visit(right, { left_type: left_type }.merge(opts))
      end

      def visit_hash(node, opts = EMPTY_HASH) = nil

      def visit_struct(node, opts = EMPTY_HASH)
        _, schema = node

        return visit(schema, opts) unless opts.key?(:key)

        result = opts.key?(:array) ? { items: compile_type(schema) } : compile_type(schema)

        update(opts[:key] => result)
      end

      def visit_array(node, opts = EMPTY_HASH)
        type, meta = node

        visit(type, { array: true }.merge(opts))

        keys[opts[:key]].update(meta.slice(*ANNOTATIONS)) if meta.any?
      end

      def visit_schema_with_ref(node, opts = EMPTY_HASH)
        _, _, meta = node

        return update(items: { "$ref": meta[:"$ref"] }) if opts.key?(:array)

        update("$ref": meta[:"$ref"])
      end

      def visit_schema(node, opts = EMPTY_HASH)
        keys, _, meta = node

        return visit_schema_with_ref(node, opts) if meta.key?(:"$ref")

        target = self.class.new

        keys.each { |fragment| target.visit(fragment) }

        definition = { type: :object, properties: target.to_hash }

        definition[:required] = target.required.to_a if target.required.any?
        definition.merge!(meta.slice(*ANNOTATIONS))  if meta.any?

        ctx = opts.key?(:key) ? @keys[opts[:key]] : @keys

        return ctx.update(items: definition.to_h) if opts.key?(:array)

        ctx.update(definition)
      end

      def visit_enum(node, opts = EMPTY_HASH)
        enum, _ = node
        visit(enum, opts)
      end

      def visit_key(node, opts = EMPTY_HASH)
        name, required, rest = node

        @required << name if required

        visit(rest, { key: name }.merge(opts))
      end

      def visit_nominal_with_key(node, opts = EMPTY_HASH)
        type, meta = node

        update(opts[:key] => meta.slice(*ALLOWED_TYPES_META_OVERRIDES)) if meta.any?

        if opts.key?(:array) && !opts.key?(:sum)
          return update(opts[:key] => { items: { "$ref": meta[:"$ref"] } }) if meta.key?(:"$ref")

          update(opts[:key] => { items: { type: CLASS_TO_TYPE[type.to_s.to_sym] } })
        end
      end

      private

      def set(value) = @keys = value

      def update(object) = @keys.update(object)

      def deep_merge_items(items)
        items.reduce({}) do |current, target|
          current.merge(target) do |_, from, to|
            case [from.class, to.class]
            when [::Hash, ::Hash]
              deep_merge_items([from, to])
            when [::Array, ::Array]
              from | to
            else
              to
            end
          end
        end
      end

      def compile_type(type, opts = EMPTY_HASH)
        self.class.new
          .tap { |target| target.visit(type, opts) }
          .to_hash
      end

      def compile_value(type, opts = EMPTY_HASH)
        compile_type(type, opts)
          .values
          .first
      end
    end

    # The `Builder` module provides a method to generate a JSON Schema hash from dry-types definitions.
    #
    module Builder
      # @overload json_schema(options = {})
      #   @param options [Hash] Initialization options passed to `JSONSchema.new`
      #   @return [Hash] The generated JSON Schema as a hash.
      #
      def json_schema(root: false, loose: false)
        compiler = JSONSchema.new(root: root, loose: loose)
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
