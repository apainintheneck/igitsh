# frozen_string_literal: true

module Gitsh
  module Parser
    # @param line [String]
    # @return [Array<Gitsh::Command::Base>]
    def self.parse(line)
      command_list = []
      tokens = Tokenizer.tokenize(line)
      return command_list if tokens.empty?

      case tokens.first
      in Token::String => token
        command_list << Command::End.new(arguments: [token.content])
      in Token::UnterminatedString => token
        raise token.syntax_error("unterminated string")
      in Token::PartialAction => token
        raise token.syntax_error("expected '#{token.content * 2}' but got '#{token.content}' instead")
      in token
        raise token.parse_error("unexpected '#{token.content}' to start the line")
      end

      case tokens.last
      in Token::And | Token::Or => token
        raise token.parse_error("unexpected '#{token.content}' to end the line")
      in Token::UnterminatedString => token
        raise token.syntax_error("unterminated string")
      else
        # do nothing
      end

      tokens.each_cons(2) do |prev_token, next_token|
        case [prev_token, next_token]
        in Token::String, Token::String if prev_token.end_position == next_token.start_position
          # Concatenate string content when they are adjacent to each other.
          command_list.last.arguments.pop.tap do |prev_string|
            command_list.last.arguments << prev_string + next_token.content
          end
        in _, Token::PartialAction
          raise next_token.syntax_error("expected '#{next_token.content * 2}' but got '#{next_token.content}' instead")
        in _, Token::String # Token is a string.
          command_list.last.arguments << next_token.content
        in Token::String, _ # Token is an action.
          command_list << Token.to_action_command(next_token)
        else
          raise next_token.parse_error("expected a string after '#{prev_token.content}' but got '#{next_token.content}' instead")
        end
      end

      # Remove any trailing semicolons from the command list.
      command_list.pop if command_list.last.is_a?(Command::End) && command_list.last.arguments.empty?

      command_list
    end
  end
end
