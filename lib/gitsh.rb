# frozen_string_literal: true

require_relative "gitsh/version"

module Gitsh
  class Error < StandardError; end

  autoload :Git, "gitsh/git"
end
