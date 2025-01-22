# frozen_string_literal: true

require_relative "gitsh/version"

module Gitsh
  class Error < StandardError; end

  autoload :Command, "gitsh/command"
  autoload :Git, "gitsh/git"
end
