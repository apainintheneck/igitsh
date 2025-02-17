# frozen_string_literal: true

module Gitsh
  module Completer
    # Designed to be compatible with `Reline.completion_proc`.
    CALLBACK = lambda do |*|
      Completer.from_line(Reline.line_buffer.to_s)
    end

    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.from_line(line)
      return if line.end_with?(" ")

      zipper = Tokenizer.from_line(line)

      if zipper.last.command?
        for_command(zipper)
      elsif zipper.last.long_option? && zipper.last.options_allowed?
        for_long_option(zipper)
      end
    end

    # @param zipper [Gitsh::Zipper]
    #
    # @return [Array<String>, nil]
    def self.for_command(zipper)
      command_prefix_regex = /^#{Regexp.escape(zipper.last.token.raw_content)}/

      Gitsh
        .all_commands
        # Complete all commands starting with the given prefix.
        .grep(command_prefix_regex)
        # Sort results by shortest command and then alphabetically.
        .sort_by { |cmd| [cmd.size, cmd] }
    end
    private_class_method :for_command

    # @param zipper [Gitsh::Zipper]
    #
    # @return [Array<String>, nil]
    def self.for_long_option(zipper)
      last_command_zipper = zipper.reverse_find(&:command?)
      return unless last_command_zipper&.valid_command?

      command = last_command_zipper.token.content
      help_page = GitHelp.for(command: command)
      return unless help_page

      long_option_prefix_regex = /^#{Regexp.escape(zipper.last.token.raw_content)}/

      help_page
        .long_option_prefixes
        # Complete all commands starting with the given prefix.
        .grep(long_option_prefix_regex)
        # Sort results by shortest command and then alphabetically.
        .sort_by { |cmd| [cmd.size, cmd] }
    end
  end
end
