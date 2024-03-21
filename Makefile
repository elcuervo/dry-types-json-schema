.PHONY: *

default: test

build:
	rm -f *.gem
	gem build dry-types-json-schema.gemspec

publish: build
	gem push *.gem

console:
	irb -Ilib -rdry/types/extensions

test:
	ruby -Ilib:spec -rpry spec/**/*_spec.rb
