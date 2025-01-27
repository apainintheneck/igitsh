# frozen_string_literal: true

require "strscan"

module Gitsh
  module Tokenizer
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'
    private_constant :SINGLE_QUOTE, :DOUBLE_QUOTE

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
      builder = []

      until scanner.eos? || scanner.match?(/&{2}|[|]{2}|;|\s/)
        # a single ampersand or pipe character
        str = scanner.scan(/[&|]/)

        # everything else that is not:
        # - an ampersand
        # - a pipe character
        # - a semicolon
        # - a single or double quote
        # - a whitespace character
        str ||= scanner.scan(/[^&|;'"\s]+/)

        # a single-quoted string
        str ||= if scanner.skip(SINGLE_QUOTE)
          charpos = scanner.charpos - 1
          substr = +""

          until scanner.skip(SINGLE_QUOTE)
            if scanner.eos?
              raise SyntaxError, "#{charpos}: Missing matching single-quote to close string"
            elsif scanner.skip("\\")
              case (char = scanner.getch)
              when "\\"
                substr << "\\"
              when SINGLE_QUOTE
                substr << SINGLE_QUOTE
              when nil
                next
              else
                substr << "\\" << char
              end
            else
              substr << scanner.scan(/[^\\']+/)
            end
          end

          substr
        end

        # a double-quoted string
        str ||= if scanner.skip(DOUBLE_QUOTE)
          charpos = scanner.charpos - 1
          substr = +""

          until scanner.skip(DOUBLE_QUOTE)
            if scanner.eos?
              raise SyntaxError, "#{charpos}: Missing matching double-quote to close string"
            elsif scanner.skip("\\")
              case (char = scanner.getch)
              when "\\"
                substr << "\\"
              when DOUBLE_QUOTE
                substr << DOUBLE_QUOTE
              when nil
                next
              else
                substr << "\\" << char
              end
            else
              substr << scanner.scan(/[^\\"]+/)
            end
          end

          substr
        end

        if str
          builder << str
        else
          # This should be unreachable but we provide a sensible error message anyway.
          raise SyntaxError, "#{scanner.charpos}: Unknown syntax error"
        end
      end

      builder.join
    end
    private_class_method :scan_string_token
  end
end
