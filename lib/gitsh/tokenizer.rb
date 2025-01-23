# frozen_string_literal: true

require "strscan"

module Gitsh
  module Tokenizer
    # @param line [String]
    # @return [Array<Gitsh::Token::Base>]
    def self.tokenize(line)
      tokens = []
      scanner = StringScanner.new(line)

      until scanner.eos?
        start_position = scanner.charpos

        if scanner.skip(/\s+/) # whitespace
          next
        elsif scanner.scan("&&") # and (&&)
          tokens << Token::And.new(
            content: "&&",
            start_position: start_position,
            end_position: scanner.charpos - 1
          )
        elsif scanner.scan("||") # or (||)
          tokens << Token::Or.new(
            content: "||",
            start_position: start_position,
            end_position: scanner.charpos - 1
          )
        elsif scanner.scan(";") # end (;)
          tokens << Token::End.new(
            content: ";",
            start_position: start_position,
            end_position: scanner.charpos - 1
          )
        else # quoted or unquoted string
          tokens << Token::String.new(
            content: scan_string_token(scanner),
            start_position: start_position,
            end_position: scanner.charpos - 1
          )
        end
      end

      tokens
    end

    # @param scanner [StringScanner]
    # @return [String]
    def self.scan_string_token(scanner)
      builder = StringIO.new

      while !scanner.eos? && !scanner.check(/&{2}|[|]{2}|;|\s/)
        # a single ampersand or pipe character
        str = scanner.scan(/[&|]/)

        # TODO: Handle exempting quotes with the backslash character in strings.

        # a single-quoted string (without the quotes)
        str ||= if scanner.scan(/'([^']*)'/)
          scanner[1]
        end

        # a double-quoted string (without the quotes)
        str ||= if scanner.scan(/"([^"]*)"/)
          scanner[1]
        end

        # everything else that is not:
        # - an ampersand
        # - a pipe character
        # - a semicolon
        # - a single or double quote
        # - a whitespace character
        str ||= scanner.scan(/[^&|;'"\s]+/)

        if str
          builder << str
        else
          case scanner.peek(1)
          when "'"
            raise SyntaxError, "#{scanner.charpos}: Missing matching single-quote to close string"
          when "\""
            raise SyntaxError, "#{scanner.charpos}: Missing matching double-quote to close string"
          else
            # This should be unreachable but we provide a sensible error message anyway.
            raise SyntaxError, "#{scanner.charpos}: Unknown syntax error"
          end
        end
      end

      builder.string
    end
    private_class_method :scan_string_token
  end
end
