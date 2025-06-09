# frozen_string_literal: true

require "rainbow/refinement"

module Igitsh
  # Each token represents the offsets in the source string of the parsed value.
  module Token
    class Base
      # @return [String]
      attr_reader :source
      # @return [Integer]
      attr_reader :start_position
      # @return [Integer]
      attr_reader :end_position

      # @param start_position [Integer]
      # @param end_position [Integer]
      # @param source [String] must be frozen
      def initialize(start_position:, end_position:, source:)
        raise ArgumentError, ":source must be frozen" unless source.frozen?

        @source = source
        @start_position = start_position
        @end_position = end_position
      end

      # @return [String]
      def start_char
        @start_char ||= source[start_position]
      end

      # @return [String]
      def raw_content
        @raw_content ||= source[start_position...end_position]
      end
      alias_method :content, :raw_content

      # @param message [String]
      #
      # @return [Igitsh::SyntaxError]
      def syntax_error(message)
        SyntaxError.new(pretty_error_message(message: message))
      end

      # @param message [String]
      #
      # @return [Igitsh::ParseError]
      def parse_error(message)
        ParseError.new(pretty_error_message(message: message))
      end

      # @param message [String]
      #
      # @return [Igitsh::UnreachableError]
      def unreachable_error(message)
        UnreachableError.new(pretty_error_message(message: message))
      end

      private

      using Rainbow

      # @param message [String]
      #
      # @return [String]
      def pretty_error_message(message:)
        error_title = USE_COLOR ? "error>".color(:blue).bold : "error>"
        pre_error = source[0...start_position]
        error = raw_content
        post_error = source[end_position..]

        <<~ERROR
          | #{error_title} #{message}
          |
          | #{pre_error}#{error}#{post_error}
          | #{" " * pre_error.length}#{"^" * error.length}
        ERROR
      end
    end
    private_constant :Base

    # Ex. `"string"`
    class String < Base
      # @return [Boolean]
      def quoted?
        %('").include?(start_char)
      end

      # @return [String]
      def content
        @content ||= if quoted?
          source[(start_position + 1)...(end_position - 1)]
        else
          super
        end
      end
    end

    # Ex. `&&`
    class And < Base; end

    # Ex. `||`
    class Or < Base; end

    # Ex. `;`
    class End < Base; end

    # When the closing quote is missing.
    # Ex. `"string`
    class UnterminatedString < Base
      # @return [String]
      def content
        @content ||= source[(start_position + 1)...end_position]
      end
    end

    # When there is a single (&) or (|)
    class PartialAction < Base; end

    # Indicates the end of command line option parsing.
    # Ex. `--`
    class EndOfOptions < String; end
  end
end
