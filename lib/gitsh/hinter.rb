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
      elsif completion.start_with?("-")
        from_option_completion(completion, width: width)
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

      [].tap do |array|
        array.concat(wrap_lines("[Description]", width: width, color: :blue))
        array << ""
        array.concat(wrap_lines(description, width: width))
      end
    end

    # @param option [String]
    # @param width [Integer]
    #
    # @return [Array<String>] formatted lines
    def self.from_option_completion(option, width:)
      zipper = Tokenizer.from_line(Reline.line_buffer.to_s)
      command = zipper.last.current_command.token.raw_content
      help_page = GitHelp.for(command: command)
      return [] unless help_page

      options = help_page.options_by_prefix[option]
      return [] unless options
      return [] if options.all? { |option| option.suffix.empty? }

      sorted_option_strings = options.map(&:to_s).sort_by(&:length)

      [].tap do |array|
        array.concat(wrap_lines("[Usage]", width: width, color: :blue))
        sorted_option_strings.each do |option_string|
          array << ""
          array.concat(wrap_lines(option_string, width: width))
        end
      end
    end

    using Rainbow

    INDENT = "  "
    private_constant :INDENT

    # @param command [String]
    # @param width [Integer]
    # @param color [Symbol] see `Rainbow` gem
    #
    # @return [Array<String>] formatted lines
    def self.wrap_lines(text, width:, color: nil)
      return [] if text.empty?
      return [] if indent >= text.size

      lines = text
        .each_char
        .each_slice(width - INDENT.size)
        .map { |chars| chars.prepend(INDENT).join }

      if USE_COLOR && color
        lines.map! do |line|
          line.color(color).bold
        end
      end

      lines
    end
  end
end
