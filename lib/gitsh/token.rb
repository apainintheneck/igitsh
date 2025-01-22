# frozen_string_literal: true

module Gitsh
  module Token
    class Base
      # @return [String]
      attr_reader :content
      # @return [Integer]
      attr_reader :start_position
      # @return [Integer]
      attr_reader :end_position

      # @return content [String]
      # @return start_position [Integer]
      # @return end_position [Integer]
      def initialize(content:, start_position: 0, end_position: 0)
        @content = content
        @start_position = start_position
        @end_position = end_position
      end

      # @return [String]
      def location
        "#{start_position}:#{end_position}"
      end

      # @return [Boolean]
      def ==(other)
        self.class === other &&
          other.content == @content &&
          other.start_position == @start_position &&
          other.end_position == @end_position
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

    # @param token [Gitsh::Token::Base]
    # @return [Gitsh::Command::Base, nil]
    def self.to_action(token)
      case token
      when Token::And
        Command::And
      when Token::Or
        Command::Or
      when Token::End
        Command.end
      end
    end
  end
end
