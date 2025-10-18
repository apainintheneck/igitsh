# frozen_string_literal: true

module Igitsh
  module Executor
    module Result
      class Base
        attr_reader :exit_code

        def initialize(exit_code:)
          @exit_code = exit_code
        end

        # @return [Boolean]
        def ==(other)
          self.class == other.class &&
            exit_code == other.exit_code
        end
      end
      private_constant :Base

      # No major problems running commands.
      class Success < Base; end

      # Syntax or parsing errors before running commands.
      class Failure < Base; end

      # The user has decided to close the program.
      class Exit < Base; end
    end

    # Tokenize, parse and run the input line as a series of Git commands.
    #
    # @param line [String]
    # @param out [IO] (default STDOUT)
    # @param err [IO] (default STDIN)
    #
    # @return [Igitsh::Executor::Result::Base]
    def self.execute_line(line:, out: $stdout, err: $stderr)
      exit_code = 0

      # We skip to the next `end` action when a successful command is followed by the `or` action.
      # For example: `first || second || third && fourth; fifth`
      #
      # In this case, only the `first` and `fifth` commands would get run.
      # The rest of the commands would get skipped.
      skip_to_end = false

      Parser.parse(line).each do |group|
        case group
        when Parser::Group::And
          # Skip the command if the previous one failed.
          next unless exit_code.zero?
        when Parser::Group::Or
          # Skip to the end if the previous command succeeded.
          skip_to_end = true if exit_code.zero?
        when Parser::Group::End
          # Always run the command after the `end` action.
          skip_to_end = false
        end

        next if skip_to_end

        exit_code = Commander
          .from_name(group.first)
          .new(group, out: out, err: err)
          .run
      end

      Result::Success.new(exit_code: exit_code)
    rescue ParseError, SyntaxError => e
      err.puts e.message
      Result::Failure.new(exit_code: 127)
    end
  end
end
