# frozen_string_literal: true

require "rainbow/refinement"

module Gitsh
  module Token
    class Base
      # @return [String]
      attr_reader :source
      # @return [String]
      attr_reader :content
      # @return [Integer]
      attr_reader :start_position
      # @return [Integer]
      attr_reader :end_position

      # @param content [String] the content of the parsed token
      # @param source [String] the source string that the token was parsed from
      # @param start_position [Integer]
      # @param end_position [Integer]
      def initialize(content:, source: "", start_position: 0, end_position: 0)
        @content = content
        @source = source
        @start_position = start_position
        @end_position = end_position
      end

      # @return [Gitsh::SyntaxError]
      def syntax_error(message)
        SyntaxError.new(pretty_error_message(message))
      end

      # @return [Gitsh::ParseError]
      def parse_error(message)
        ParseError.new(pretty_error_message(message))
      end

      # @return [Boolean]
      def ==(other)
        self.class === other &&
          other.content == @content &&
          other.start_position == @start_position &&
          other.end_position == @end_position
      end

      private

      using Rainbow

      # @param message [String]
      #
      # @return [String]
      def pretty_error_message(message)
        pre_error = @source[0...start_position]
        error = @source[start_position...end_position]
        post_error = @source[end_position..]

        <<~ERROR
          | #{"error>".color(:blue).bold} #{message}
          |
          | #{pre_error}#{error}#{post_error}
          | #{" " * pre_error.length}#{"^" * error.length}
        ERROR
      end
    end
    private_constant :Base

    # Ex. `"string"`
    class String < Base; end

    # Ex. `&&`
    class And < Base; end

    # Ex. `||`
    class Or < Base; end

    # Ex. `;`
    class End < Base; end

    # When the closing quote is missing.
    # Ex. `"string`
    class UnterminatedString < Base; end

    # When there is a single (&) or (|)
    class PartialAction < Base; end

    # @param token [Gitsh::Token::And, Gitsh::Token::Or, Gitsh::Token::End]
    # @return [Gitsh::Command::Base]
    def self.to_action_command(token)
      case token
      when Token::And
        Command::And.new
      when Token::Or
        Command::Or.new
      when Token::End
        Command::End.new
      else
        raise Error, "Expected action token instead of: #{token}"
      end
    end
  end
end
