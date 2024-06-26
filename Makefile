.PHONY: *

default: test

build:
	rm -f *.gem
	gem build dry-types-json-schema.gemspec

publish: build
	gem push *.gem

console:
	irb -Ilib:spec -rspec_helper.rb

test:
	bundle exec rake
