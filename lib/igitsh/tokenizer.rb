# frozen_string_literal: true

require "strscan"

module Igitsh
  module Tokenizer
    # @param line [String]
    #
    # @return [Igitsh::TokenZipper]
    def self.from_line(line)
      line = line.dup.freeze
      tokens = []
      scanner = StringScanner.new(line)

      until scanner.eos?
        start_position = scanner.charpos

        if scanner.skip(/\s+/) # whitespace
          next
        elsif scanner.skip("&&") # and (&&)
          tokens << Token::And.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip("||") # or (||)
          tokens << Token::Or.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip(";") # end (;)
          tokens << Token::End.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip(/[&|]/) # partial (&&) or (||)
          tokens << Token::PartialAction.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip("-- ") # end of command line options
          tokens << Token::EndOfOptions.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos - 1
          )
        elsif scanner.skip(/'(?:\\.|[^'])*/) # single-quoted string
          tokens << if scanner.skip("'")
            Token::String
          else
            Token::UnterminatedString
          end.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip(/"(?:\\.|[^"])*/) # double-quoted string
          tokens << if scanner.skip('"')
            Token::String
          else
            Token::UnterminatedString
          end.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.skip(/[^&|;'"\s]+/) # unquoted string identifier
          # Everything else that is not:
          # - an ampersand
          # - a pipe character
          # - a semicolon
          # - a single or double quote
          # - a whitespace character
          tokens << Token::String.new(
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        else
          raise UnreachableError, "#{start_position}: Unknown string parsing error"
        end
      end

      TokenZipper.new(source: line, tokens: tokens.freeze)
    end
  end
end
