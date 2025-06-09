# frozen_string_literal: true

require "strscan"

module Igitsh
  module Tokenizer
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'
    BACKSLASH = "\\"
    private_constant :SINGLE_QUOTE, :DOUBLE_QUOTE, :BACKSLASH

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
        else # quoted or unquoted string
          tokens << scan_string_token(
            line: line,
            start_position: start_position,
            scanner: scanner
          )
        end
      end

      TokenZipper.new(source: line, tokens: tokens.freeze)
    end

    # @param line [String]
    # @param start_position [Integer]
    # @param scanner [StringScanner]
    #
    # @return [String]
    def self.scan_string_token(line:, start_position:, scanner:)
      terminated = true
      matched = nil

      # Everything else that is not:
      # - an ampersand
      # - a pipe character
      # - a semicolon
      # - a single or double quote
      # - a whitespace character
      matched = true if scanner.skip(/[^&|;'"\s]+/)

      # a single-quoted string
      matched ||= if scanner.skip(SINGLE_QUOTE)
        until scanner.skip(SINGLE_QUOTE)
          if scanner.eos?
            terminated = false
            break
          elsif scanner.skip(BACKSLASH)
            scanner.getch
          else
            scanner.skip(/[^\\']+/)
          end
        end

        true
      end

      # a double-quoted string
      matched ||= if scanner.skip(DOUBLE_QUOTE)
        until scanner.skip(DOUBLE_QUOTE)
          if scanner.eos?
            terminated = false
            break
          elsif scanner.skip(BACKSLASH)
            scanner.getch
          else
            scanner.skip(/[^\\"]+/)
          end
        end

        true
      end

      if matched
        token_class = if terminated
          Token::String
        else
          Token::UnterminatedString
        end

        return token_class.new(
          source: line,
          start_position: start_position,
          end_position: scanner.charpos
        )
      end

      raise UnreachableError, "#{start_position}: Unknown string parsing error"
    end
    private_class_method :scan_string_token
  end
end
