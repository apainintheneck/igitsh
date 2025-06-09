# frozen_string_literal: true

require "rainbow/refinement"

module Igitsh
  # This class highlights the current line before printing it to the REPL.
  module Highlighter
    # Designed to be compatible with `Reline.output_modifier_proc`.
    CALLBACK = lambda do |line, complete:|
      return if line.strip.empty?

      Highlighter.from_line(Reline.line_buffer.to_s, complete: complete)
    end

    using Rainbow

    # Highlight an input line for the command line.
    #
    # @param line [String]
    # @param complete [Boolean] true means that user has pressed enter
    #
    # @return [String]
    def self.from_line(line, complete: false)
      zipper = Tokenizer.from_line(line)
      string = +""
      return string if zipper.empty?

      # Highlight each token in the zipper and preserve gaps between tokens.
      zipper.each do |sub_zipper|
        string << highlight_token(sub_zipper)
        token_gap = sub_zipper.gap_to_next
        string << " " * token_gap if token_gap.positive?
      end

      # Add trailing hint if one exists and there are no spaces after the token.
      # Skip this after the user presses enter and the line is complete.
      if !complete && !line.end_with?(" ") && (suffix = zipper.last.suffix)
        string << suffix.color(:gray)
      end

      string.freeze
    end

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [String]
    def self.highlight_token(zipper)
      if zipper.action?
        zipper.token.raw_content.color(:mediumspringgreen)
      elsif zipper.partial_action_token?
        zipper.token.raw_content.color(:orange)
      elsif zipper.unterminated_string_token?
        zipper.token.start_char.color(:crimson) + zipper.token.content.color(:greenyellow)
      elsif zipper.string_token?
        if zipper.command?
          if zipper.valid_command?
            zipper.token.raw_content.color(:aqua)
          else
            zipper.token.raw_content.color(:crimson)
          end
        elsif zipper.token.quoted?
          zipper.token.raw_content.color(:yellowgreen)
        else
          zipper.token.raw_content.color(:mediumslateblue)
        end
      else
        raise zipper.token.unreachable_error("unable to highlight unexpected token")
      end.bold
    end
    private_class_method :highlight_token
  end
end
