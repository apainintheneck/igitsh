# frozen_string_literal: true

require_relative "lib/gitsh/version"

Gem::Specification.new do |spec|
  spec.name = "gitsh"
  spec.version = Gitsh::VERSION
  spec.authors = ["Kevin Robell"]
  spec.email = ["apainintheneck@gmail.com"]

  spec.summary = "A simple shell for Git commands"
  spec.description = "A simple shell for Git commands with autocompletion and custom shortcuts."
  spec.homepage = "https://github.com/apainintheneck/gitsh/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = File.join(spec.homepage, "blob/main/CHANELOG.md")
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{lib,exe}/**/*"]
  spec.bindir = "exe"
  spec.executables = ["rfc-reader"]

  spec.add_dependency "tty-which", "~> 0.5"
  spec.add_dependency "rainbow", "~> 3.1.1"
  spec.add_dependency "reline", "~> 0.6.0"
  spec.add_dependency "xdg", "~> 6.0"
end
