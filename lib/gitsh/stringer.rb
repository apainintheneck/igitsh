# frozen_string_literal: true

module Gitsh
  module Stringer
    # Indent a string by the given amount.
    #
    # @param text [String] text to indent
    # @param by [Integer] amount to indent
    def self.indent_by(text, size:)
      raise ArgumentError, "size must not be negative: #{size}" if size.negative?

      return text if size.zero?

      (" " * size) + text
    end

    # Simple word wrap implementation.
    #
    # 1. Splits words on whitespace boundaries.
    # 2. Fits as many words joined by one space on a single line.
    # 3. If word and indent are bigger than width, it gets split accross multiple lines with a hyphon.
    #
    # @param text [String] text to format
    # @param width [Integer] expected to be 10+
    # @param indent [Integer] must not be negative
    #
    # @return [Array<String>] formatted lines
    def self.wrap_ascii(text, width:, indent:)
      raise ArgumentError, "indent must not be negative: #{indent}" if indent.negative?

      return [] if text.strip.empty?
      return [] if width < 10

      line = nil
      lines = []
      text.split do |word|
        line ||= indent.zero? ? +"" : indent_by("", size: indent - 1)

        if line.size + 1 + word.size <= width
          # Add small word to current line.
          line << " " << word
        elsif word.size + indent > width
          # Finish current line.
          lines << line
          # Chunk large word over multiple lines with hyphons in between.
          0.step(by: width - (indent + 1), to: word.size - 1) do |idx|
            if word.size - idx <= width - indent
              # Store the end of the word.
              line = "  #{word.slice(idx, width - indent)}"
              break
            else
              # Store a chunk of the word as a line.
              lines << "  #{word.slice(idx, width - (indent + 1))}-"
            end
          end
        else
          # Finish current line.
          lines << line
          # Start a new line.
          line = indent_by(word, size: indent)
        end
      end
      lines << line if line

      lines
    end
  end
end
