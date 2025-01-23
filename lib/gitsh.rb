# frozen_string_literal: true

require_relative "gitsh/version"

module Gitsh
  class Error < StandardError; end

  class SyntaxError < Error; end

  class ParseError < Error; end

  autoload :Command, "gitsh/command"
  autoload :Git, "gitsh/git"
  autoload :Parser, "gitsh/parser"
  autoload :Token, "gitsh/token"
  autoload :Tokenizer, "gitsh/tokenizer"
end
