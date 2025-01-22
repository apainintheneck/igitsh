# frozen_string_literal

module Gitsh
  # Represents a single shell command and action pair.
  # - Action: The logical action between the previous command and this one.
  # - Command: The shell command to run as an array of strings.
  #
  # There are three possible actions:
  # 1. '&&' - Requires the previous command to exit successfully.
  #   Ex. `Gitsh::Command::And.new(arguments: %w[diff])`
  # 2. '||' - Requires the previous command to fail.
  #   Ex. `Gitsh::Command::Or.new(arguments: %w[commit -m "WIP"])`
  # 3. ';'  - Runs no matter what happened with the previous command.
  #   Ex. `Gitsh::Command::End.new(arguments: %w[add --all])`
  module Command
    class Base
      # @return [Array<String>]
      attr_reader :arguments

      # @return [Array<String>]
      def initialize(arguments:)
        @arguments = arguments.freeze
      end
    end
    private_constant :Base

    # Run this command if the previous one succeeded.
    class And < Base; end

    # Run this command if the previous one failed.
    class Or < Base; end

    # Run this command regardless of the previous command.
    class End < Base; end
  end
end
