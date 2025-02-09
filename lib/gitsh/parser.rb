# frozen_string_literal: true

module Gitsh
  module Parser
    # Parse a line into a series of commands.
    #
    # @param line [String]
    # @return [Array<Gitsh::Command::Base>]
    def self.parse(line)
      command_list = []
      zipper = Tokenizer.tokenize(line)
      return command_list if zipper.empty?

      command_list << Command::End.new
      zipper.each do |sub_zipper|
        if sub_zipper.string_token?
          if sub_zipper.before.string_token? && sub_zipper.gap_to_prev.zero?
            # Concatenate string content when they are adjacent to each other.
            command_list.last.arguments.pop.tap do |prev_string|
              command_list.last.arguments << prev_string + sub_zipper.token.content
            end
          else
            command_list.last.arguments << sub_zipper.token.content
          end
        elsif sub_zipper.action?
          if sub_zipper.first?
            raise sub_zipper.token.parse_error("unexpected '#{sub_zipper.token.content}' to start the line")
          elsif sub_zipper.last? && !sub_zipper.end_token?
            raise sub_zipper.token.parse_error("unexpected '#{sub_zipper.token.content}' to end the line")
          elsif !sub_zipper.before.string_token?
            raise sub_zipper.token.parse_error("expected a string after '#{sub_zipper.before.token.content}' but got '#{sub_zipper.token.content}' instead")
          end

          if sub_zipper.and_token?
            command_list << Command::And.new
          elsif sub_zipper.or_token?
            command_list << Command::Or.new
          elsif sub_zipper.end_token? && !sub_zipper.last?
            command_list << Command::End.new
          end
        elsif sub_zipper.unterminated_string_token?
          raise sub_zipper.token.syntax_error("unterminated string")
        elsif sub_zipper.partial_action_token?
          raise sub_zipper.token.syntax_error("expected '#{sub_zipper.token.content * 2}' but got '#{sub_zipper.token.content}' instead")
        end
      end

      command_list
    end
  end
end
