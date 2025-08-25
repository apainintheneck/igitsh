# frozen_string_literal: true

require_relative "lib/igitsh/version"

Gem::Specification.new do |spec|
  spec.name = "igitsh"
  spec.version = Igitsh::VERSION
  spec.authors = ["Kevin Robell"]
  spec.email = ["apainintheneck@gmail.com"]

  spec.summary = "An interactive shell for Git commands"
  spec.description = "An interactive shell for Git commands with autocompletion and custom shortcuts."
  spec.homepage = "https://github.com/apainintheneck/igitsh/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = File.join(spec.homepage, "blob/main/CHANELOG.md")
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{lib,exe}/**/*"]
  spec.bindir = "exe"
  spec.executables = ["igitsh"]

  spec.add_dependency "rainbow", "~> 3.1.1"
  spec.add_dependency "reline", "~> 0.6.0"
  spec.add_dependency "tty-pager", "~> 0.14"
  spec.add_dependency "tty-which", "~> 0.5"
  spec.add_dependency "xdg", "~> 6.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standard", "~> 1.3"
  spec.add_development_dependency "rspec-snapshot", "~> 2.0.3"
  spec.add_development_dependency "prop_check", "~> 1.0.0"
end
