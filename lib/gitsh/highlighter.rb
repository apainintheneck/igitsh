# frozen_string_literal: true

require "rainbow/refinement"

module Gitsh
  module Highlighter
    # @param tokens [Array<Gitsh::Token::Base>]
    #
    # @return [String]
    def self.from_tokens(tokens)
      string = +""
      return string if tokens.empty?

      [nil, *tokens].each_cons(2) do |prev_token, token|
        token_gap = token.start_position - prev_token&.end_position.to_i

        string << " " * token_gap if token_gap.positive?
        string << highlight_token(prev_token, token)
      end

      string.freeze
    end

    using Rainbow

    # @param prev_token [Gitsh::Token::Base, nil]
    # @param token [Gitsh::Token::Base]
    #
    # @return [String]
    def self.highlight_token(prev_token, token)
      case token
      in Token::And | Token::Or | Token::End
        token.content.color(:mediumspringgreen)
      in Token::PartialAction
        token.content.color(:orange)
      in Token::UnterminatedString
        token.start_char.color(:crimson) + token.content.color(:greenyellow)
      in Token::String
        case prev_token
        when Token::String
          if token.quoted?
            token.raw_content.color(:yellowgreen)
          else
            token.raw_content.color(:mediumslateblue)
          end
        else
          if ::Gitsh.all_commands.include?(token.content)
            token.raw_content.color(:aqua)
          else
            token.raw_content.color(:crimson)
          end
        end
      end.bold
    end
    private_class_method :highlight_token
  end
end
