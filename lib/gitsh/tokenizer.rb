# frozen_string_literal: true

require "strscan"

module Gitsh
  module Tokenizer
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'
    BACKSLASH = "\\"

    # @param line [String]
    # @return [Array<Gitsh::Token::Base>]
    def self.tokenize(line)
      line = line.dup.freeze
      tokens = []
      scanner = StringScanner.new(line)

      until scanner.eos?
        start_position = scanner.charpos

        if scanner.skip(/\s+/) # whitespace
          next
        elsif scanner.scan("&&") # and (&&)
          tokens << Token::And.new(
            content: "&&",
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.scan("||") # or (||)
          tokens << Token::Or.new(
            content: "||",
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif scanner.scan(";") # end (;)
          tokens << Token::End.new(
            content: ";",
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        elsif (content = scanner.scan(/[&|]/)) # partial (&&) or (||)
          tokens << Token::PartialAction.new(
            content: content,
            source: line,
            start_position: start_position,
            end_position: scanner.charpos
          )
        else # quoted or unquoted string
          tokens << scan_string_token(
            line: line,
            start_position: start_position,
            scanner: scanner
          )
        end
      end

      tokens
    end

    # @param line [String]
    # @param start_position [Integer]
    # @param scanner [StringScanner]
    #
    # @return [String]
    def self.scan_string_token(line:, start_position:, scanner:)
      terminated = true

      # Everything else that is not:
      # - an ampersand
      # - a pipe character
      # - a semicolon
      # - a single or double quote
      # - a whitespace character
      str ||= scanner.scan(/[^&|;'"\s]+/)

      # a single-quoted string
      str ||= if scanner.skip(SINGLE_QUOTE)
        substr = +""

        until scanner.skip(SINGLE_QUOTE)
          if scanner.eos?
            terminated = false
            break
          elsif scanner.skip(BACKSLASH)
            case (char = scanner.getch)
            when BACKSLASH
              substr << BACKSLASH
            when SINGLE_QUOTE
              substr << SINGLE_QUOTE
            when nil
              next
            else
              substr << BACKSLASH << char
            end
          else
            substr << scanner.scan(/[^\\']+/)
          end
        end

        substr
      end

      # a double-quoted string
      str ||= if scanner.skip(DOUBLE_QUOTE)
        substr = +""

        until scanner.skip(DOUBLE_QUOTE)
          if scanner.eos?
            terminated = false
            break
          elsif scanner.skip(BACKSLASH)
            case (char = scanner.getch)
            when BACKSLASH
              substr << BACKSLASH
            when DOUBLE_QUOTE
              substr << DOUBLE_QUOTE
            when nil
              next
            else
              substr << BACKSLASH << char
            end
          else
            substr << scanner.scan(/[^\\"]+/)
          end
        end

        substr
      end

      if str
        token_class = if terminated
          Token::String
        else
          Token::UnterminatedString
        end

        return token_class.new(
          content: str,
          source: line,
          start_position: start_position,
          end_position: scanner.charpos
        )
      end

      # This should be unreachable but we provide a sensible error message anyway.
      raise SyntaxError, "#{start_position}: Unknown string parsing error"
    end
    private_class_method :scan_string_token
  end
end
