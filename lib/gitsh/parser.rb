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
      when Token::String
        command_list << Command::End.new(arguments: [tokens.first.content])
      else
        raise ParseError, "#{tokens.first.location}: Expected a string to start the line but got '#{tokens.first.content}' instead"
      end

      case tokens.last
      when Token::And, Token::Or
        raise ParseError, "#{tokens.last.location}: Expected a string or a semicolon to end the line but got '#{tokens.last.content}' instead"
      end

      tokens.each_cons(2) do |prev_token, token|
        case [prev_token, token]
        in _, Token::String # Token is a string.
          command_list.last.arguments << token.content
        in Token::String, _ # Token is an action.
          command_list << Token.to_action_command(token)
        else
          raise ParseError, "#{token.location}: Expected a string after '#{prev_token.content}' but got '#{token.content}' instead"
        end
      end

      # Remove any trailing semicolons from the command list.
      command_list.pop if command_list.last.is_a?(Command::End) && command_list.last.arguments.empty?

      command_list
    end
  end
end
