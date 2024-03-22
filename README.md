# Dry::Types::JSONSchema

![](https://images.unsplash.com/photo-1642952469120-eed4b65104be?q=80&w=400&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D)

## Example

```ruby
  AnnotatedString = Dry::Types["string"].meta(format: :email, title: "Notes")

  AnnotatedString.json_schema
  #=> {:type=>:string, :title=>"Notes", :format=>:email}

  module Types
    include Dry.Types()
  end

  class StructTest < Dry::Struct
    schema schema.meta(title: "Title", description: "description")

    VariableList = Types::Array
     .of(Types::String | Types::Hash)
     .constrained(min_size: 1)
     .meta(description: "Allow an array of strings or multiple hashes")

    attribute  :data,   Types::String | Types::Hash
    attribute  :string, Types::String.constrained(min_size: 1, max_size: 255)
    attribute  :list,   VariableList
  end

  StructTest.json_schema
  # =>
  # {:type=>:object,
  #    :properties=>
  #     {:data=>{:anyOf=>[{:type=>:string}, {:type=>:object}]},
  #      :string=>{:type=>:string, :minLength=>1, :maxLength=>255},
  #      :list=>
  #       {:type=>:array,
  #        :items=>{:anyOf=>[{:type=>:string}, {:type=>:object}]},
  #        :description=>"Allow an array of strings or multiple hashes",
  #        :minItems=>1}},
  #    :required=>[:data, :string, :list],
  #    :title=>"Title",
  #    :description=>"description"}
```
