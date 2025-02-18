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
      if Git.command_descriptions.include?(completion)
        from_command_completion(completion, width: width)
      else
        []
      end
    end

    # @param command [String]
    # @param width [Integer]
    #
    # @return [Array<String>] formatted lines
    def self.from_command_completion(command, width:)
      description = Git.command_descriptions[command]
      return [] unless description

      wrap_lines(description, width: width)
    end
    private_class_method :from_command_completion

    INDENT = "  "
    private_constant :INDENT

    # Simple word wrap implementation.
    #
    # 1. Splits words on whitespace boundaries.
    # 2. Fits as many words joined by one space on a single line.
    # 3. If word and indent are bigger than width, it gets split accross multiple lines with a hyphon.
    #
    # @param text [String]
    # @param width [Integer] expected to 10 or larger otherwise it will return an empty array
    #
    # @return [Array<String>] formatted lines
    def self.wrap_lines(text, width:)
      return [] if text.strip.empty?
      return [] if width < 10

      line = nil
      lines = []
      text.split do |word|
        line ||= +" "

        if line.size + 1 + word.size <= width
          # Add small word to current line.
          line << " " << word
        elsif word.size + 2 > width
          # Finish current line.
          lines << line
          # Chunk large word over multiple lines with hyphons in between.
          0.step(by: width - 3, to: word.size - 1) do |idx|
            if word.size - idx <= width - 2
              # Store the end of the word.
              line = "  #{word.slice(idx, width - 2)}"
              break
            else
              # Store a chunk of the word as a line.
              lines << "  #{word.slice(idx, width - 3)}-"
            end
          end
        else
          # Finish current line.
          lines << line
          # Start a new line.
          line = "  #{word}"
        end
      end
      lines << line if line

      lines
    end
    private_class_method :wrap_lines
  end
end
