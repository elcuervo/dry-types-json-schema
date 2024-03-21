# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name              = "dry-types-json-schema"
  s.version           = "0.0.1"
  s.summary           = ""
  s.authors           = ["elcuervo"]
  s.licenses          = %w[MIT]
  s.email             = ["elcuervo@elcuervo.net"]
  s.homepage          = "http://github.com/elcuervo/dry-types-json-schema"
  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files test`.split("\n")

  s.add_dependency("dry-types", "~> 1.7.2")

  s.add_development_dependency("dry-struct", "~> 1.6.0")
  s.add_development_dependency("minitest", "~> 5.22.3")
  s.add_development_dependency("pry", "~> 0.14.2")
  s.add_development_dependency("json_schemer", "~> 2.2.1")
end
