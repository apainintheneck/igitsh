# frozen_string_literal: true

module Igitsh
  module Parser
    # Represents a set of shell arguments and action pair.
    # - Action: The logical action between the previous command and this one.
    # - Arguments: The shell command to run as an array of strings.
    #
    # There are three possible actions:
    # 1. '&&' - Requires the previous command to exit successfully.
    #   Ex. `Igitsh::Parser::Group::And.new(%w[diff])`
    # 2. '||' - Requires the previous command to fail.
    #   Ex. `Igitsh::Parser::Group::Or.new(%w[commit -m "WIP"])`
    # 3. ';'  - Runs no matter what happened with the previous command.
    #   Ex. `Igitsh::Parser::Group::End.new(%w[add --all])`
    module Group
      class Base < Array; end
      private_constant :Base

      # Run this command if the previous one succeeded.
      class And < Base; end

      # Run this command if the previous one failed.
      class Or < Base; end

      # Run this command regardless of the previous command.
      class End < Base; end
    end

    # Parse a line into a series of commands.
    #
    # @param line [String]
    # @return [Array<Igitsh::Parser::Group::Base>]
    def self.parse(line)
      groups = []
      zipper = Tokenizer.from_line(line)
      return groups if zipper.empty?

      groups << Group::End.new
      zipper.each do |sub_zipper|
        if sub_zipper.string_token?
          if sub_zipper.before.string_token? && sub_zipper.gap_to_prev.zero?
            # Concatenate string content when they are adjacent to each other.
            groups.last.pop.tap do |prev_string|
              groups.last << prev_string + sub_zipper.token.content
            end
          else
            groups.last << sub_zipper.token.content
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
            groups << Group::And.new
          elsif sub_zipper.or_token?
            groups << Group::Or.new
          elsif sub_zipper.end_token? && !sub_zipper.last?
            groups << Group::End.new
          end
        elsif sub_zipper.unterminated_string_token?
          raise sub_zipper.token.syntax_error("unterminated string")
        elsif sub_zipper.partial_action_token?
          raise sub_zipper.token.syntax_error("expected '#{sub_zipper.token.content * 2}' but got '#{sub_zipper.token.content}' instead")
        else
          raise sub_zipper.token.unreachable_error("unknown token: #{sub_zipper.token}")
        end
      end

      groups
    end
  end
end
