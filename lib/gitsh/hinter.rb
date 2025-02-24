# frozen_string_literal: true

require "rainbow/refinement"

module Gitsh
  module Hinter
    # Based on https://github.com/ruby/irb/blob/9f1bfde29eba377c5454b7e85c718191b64a2456/lib/irb/input-method.rb#L327-L443
    #
    # Designed to be compatible with `Reline.add_dialog_proc`.
    #
    # @return [Proc]
    def self.callback
      lambda do
        return if just_cursor_moving && completion_journey_data.nil?

        cursor_pos_to_render, result, pointer, autocomplete_dialog = context.pop(4)
        return if result.nil? || pointer.nil? || (pointer < 0)

        choice = result[pointer]
        return if choice.nil? || choice.strip.empty?

        width = 40

        right_x = cursor_pos_to_render.x + autocomplete_dialog.width
        if right_x + width > screen_width
          right_width = screen_width - (right_x + 1)
          left_x = autocomplete_dialog.column - width
          left_x = 0 if left_x < 0
          left_width = (width > autocomplete_dialog.column) ? autocomplete_dialog.column : width
          if right_width.positive? && left_width.positive?
            if right_width >= left_width
              width = right_width
              x = right_x
            else
              width = left_width
              x = left_x
            end
          elsif right_width.positive? && (left_width <= 0)
            width = right_width
            x = right_x
          elsif (right_width <= 0) && left_width.positive?
            width = left_width
            x = left_x
          else # Both are negative width.
            return
          end
        else
          x = right_x
        end

        hint_lines = Hinter.from_completion(choice, width: width)
        hint_lines = hint_lines.take(preferred_dialog_height)
        return if hint_lines.empty?

        y = cursor_pos_to_render.y
        Reline::DialogRenderInfo.new(
          pos: Reline::CursorPos.new(x, y),
          contents: hint_lines,
          width: width,
          bg_color: "49"
        )
      end
    end

    # @param completion [String]
    # @param width [Integer]
    #
    # @return [Array<String>] formatted lines
    def self.from_completion(completion, width:)
      description = if Git.command_descriptions.include?(completion)
        Git.command_descriptions.fetch(completion)
      elsif Commander.internal_command_names.include?(completion)
        Commander.name_to_command.fetch(completion).description
      end

      if description
        Stringer.wrap_ascii(description, width: width, indent: 2)
      else
        []
      end
    end
  end
end
