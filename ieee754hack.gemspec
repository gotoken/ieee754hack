# frozen_string_literal: true

require_relative "lib/ieee754hack/version"

Gem::Specification.new do |spec|
  spec.name = "ieee754hack"
  spec.version = Ieee754hack::VERSION
  spec.authors = ["Kentaro Goto"]
  spec.email = ["gotoken@gmail.com"]

  spec.summary = "Utilities to peek Float internals on IEEE 754 platform."
  spec.description = "ieee754hack adds instance methods to the Float class to display and create representations of floating point numbers based on the IEEE754 format. "
  spec.homepage = "https://github.com/gotoken/ieee754hack"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
