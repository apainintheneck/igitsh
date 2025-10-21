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
      return if zipper.empty?

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
      return if !line.end_with?(" ") && (zipper.last.command? || zipper.last.option?)

      completions = custom_completions_for(zipper:)
      return unless completions
      return completions if line.end_with?(" ")

      filter_by_prefix(terms: completions, prefix: zipper.last.token.raw_content)
    end
    private_class_method :for_custom

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [Array<String>, nil]
    def self.custom_completions_for(zipper:)
      command = zipper.last.current_command
      return unless command

      completions =
        case command.token.raw_content
        when "add"
          Git.unstaged_files
        when "checkout", "diff", "merge", "rebase", "switch"
          Git.other_branch_names
        when "restore"
          options = zipper.drop(zipper.index.succ).select(&:option?)
          if options.any? { |opt| opt.token.raw_content in "-S" | "--staged" }
            Git.staged_files
          else
            Git.unstaged_files
          end
        else
          return
        end

      completions.take(1_000) unless completions.empty?
    end
    private_class_method :custom_completions_for

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
