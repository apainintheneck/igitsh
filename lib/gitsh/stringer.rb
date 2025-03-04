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
    # 4. Preserves existing newlines.
    #
    # @param text [String] text to format
    # @param width [Integer] expected to be 10+
    # @param indent [Integer] must not be negative
    #
    # @return [Array<String>] formatted lines
    def self.wrap_ascii_paragraph(text, width:, indent:)
      text.each_line(chomp: true).flat_map do |line|
        wrap_ascii_line(line, width: width, indent: indent)
      end
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
    def self.wrap_ascii_line(text, width:, indent:)
      raise ArgumentError, "indent must not be negative: #{indent}" if indent.negative?
      raise ArgumentError, "indent(#{indent}) must be less than width(#{width})" if indent >= width

      return [] if width < 10

      line = nil
      lines = []
      text.split do |word|
        if line && line.size + 1 + word.size <= width
          # Add small word to current line.
          line << " " << word
        elsif word.size + indent > width
          # Finish current line.
          lines << line if line
          # Chunk large word over multiple lines with hyphons in between.
          0.step(by: width - (indent + 1), to: word.size - 1) do |idx|
            if word.size - idx <= width - indent
              # Store the end of the word.
              line = indent_by(word.slice(idx, width - indent), size: indent)
              break
            else
              # Store a chunk of the word as a line.
              lines << indent_by("#{word.slice(idx, width - (indent + 1))}-", size: indent)
            end
          end
        else
          # Finish current line.
          lines << line if line
          # Start a new line.
          line = indent_by(word, size: indent)
        end
      end
      lines << line if line
      lines = [""] if lines.empty?

      lines
    end
  end
end
