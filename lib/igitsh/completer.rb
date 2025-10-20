# frozen_string_literal: true

module Igitsh
  module Completer
    # Designed to be compatible with `Reline.completion_proc`.
    CALLBACK = lambda do |*|
      Completer.from_line(Reline.line_buffer.to_s)
    end

    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.from_line(line)
      zipper = Tokenizer.from_line(line)

      completions =
        for_command(zipper:, line:) ||
        for_option(zipper:, line:) ||
        for_custom(zipper:, line:)

      completions&.take(250)
    end

    # @param zipper [Igitsh::TokenZipper]
    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.for_command(zipper:, line:)
      return if line.end_with?(" ")
      return unless zipper.last.command?

      prefix = zipper.last.token.raw_content

      filter_by_prefix(terms: Igitsh.all_command_names, prefix:)
    end
    private_class_method :for_command

    # @param zipper [Igitsh::TokenZipper]
    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.for_option(zipper:, line:)
      return if line.end_with?(" ")
      return unless zipper.last.option?
      return unless zipper.last.options_allowed?

      last_command_zipper = zipper.reverse_find(&:command?)
      return unless last_command_zipper

      command_name = last_command_zipper.token.content
      prefix = zipper.last.token.raw_content

      option_prefixes = if last_command_zipper.valid_git_command?
        GitHelp.from_name(command_name)&.option_prefixes
      elsif last_command_zipper.valid_internal_command?
        Commander.from_name(command_name)&.option_prefixes
      end

      return unless option_prefixes

      filter_by_prefix(terms: option_prefixes, prefix:)
    end
    private_class_method :for_option

    # @param zipper [Igitsh::TokenZipper]
    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.for_custom(zipper:, line:)
      if line.end_with?(" ")
        return unless zipper.last.command?

        command_name = zipper.last.token.raw_content
        prefix = nil
      else
        return unless zipper.last.before.command?
        return unless zipper.last.string_token?
        return if zipper.last.option?

        command_name = zipper.last.before.token.raw_content
        prefix = zipper.last.token.raw_content
        return if prefix.start_with?("-")
      end

      completions = custom_completions_for(command_name:)
      return unless completions

      if prefix
        completions = filter_by_prefix(terms: completions, prefix:)
      end

      completions
    end
    private_class_method :for_custom

    # @param command_name [String]
    #
    # @return [Array<String>, nil]
    def self.custom_completions_for(command_name:)
      completions =
        case command_name
        when "add", "restore"
          Git.unstaged_files
        when "checkout", "switch", "merge"
          Git.other_branch_names
        else
          return
        end

      completions.take(1_000) unless completions.empty?
    end

    # @param terms [Array<String>]
    # @param prefix [String]
    #
    # @return [Array<String>, nil]
    def self.filter_by_prefix(terms:, prefix:)
      filtered_terms = terms
        # Select all terms starting with the given prefix.
        .select { |term| term.start_with?(prefix) }
        # Sort results by shortest command and then alphabetically.
        .sort_by { |term| [term.size, term] }

      filtered_terms unless filtered_terms.empty?
    end
    private_class_method :filter_by_prefix
  end
end
