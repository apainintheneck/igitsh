# frozen_string_literal: true

module Igitsh
  module Completer
    # Designed to be compatible with `Reline.completion_proc`.
    CALLBACK = lambda do |*|
      Completer.from_line(Reline.line_buffer.to_s)
    end

    MAX_COMPLETIONS = 250

    # @param line [String]
    #
    # @return [Array<String>, nil]
    def self.from_line(line)
      zipper = Tokenizer.from_line(line)
      return if zipper.empty?

      for_command(zipper:) ||
        for_option(zipper:) ||
        for_filepath(zipper:) ||
        for_custom(zipper:)
    end

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [Array<String>, nil]
    def self.for_command(zipper:)
      return if zipper.trailing_whitespace?
      return unless zipper.last.command?

      prefix = zipper.last.token.raw_content
      completions = Igitsh.all_command_names.select do |command_name|
        command_name.start_with?(prefix)
      end

      completions unless completions.empty?
    end
    private_class_method :for_command

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [Array<String>, nil]
    def self.for_option(zipper:)
      return if zipper.trailing_whitespace?
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

      completions = option_prefixes.select do |option_prefix|
        option_prefix.start_with?(prefix)
      end

      completions unless completions.empty?
    end
    private_class_method :for_option

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [Array<String>, nil]
    def self.for_filepath(zipper:)
      return if zipper.trailing_whitespace?
      return unless zipper.last.string_token?
      return if zipper.last.command?
      return if zipper.last.option?

      filepath = zipper.last.token.raw_content
      return unless filepath.start_with?("./")

      completions = Git
        .files(prefix: filepath.delete_prefix("./"), limit: MAX_COMPLETIONS)
        .map { |filepath| "./#{filepath}" }

      completions unless completions.empty?
    end

    # @param zipper [Igitsh::TokenZipper]
    #
    # @return [Array<String>, nil]
    def self.for_custom(zipper:)
      unless zipper.trailing_whitespace?
        return unless zipper.last.string_token?
        return if zipper.last.command?
        return if zipper.last.option?
      end

      prefix = zipper.trailing_whitespace? ? "" : zipper.last.token.raw_content
      custom_completions_for(zipper:, prefix:)
    end
    private_class_method :for_custom

    # @param zipper [Igitsh::TokenZipper]
    # @param prefix [String]
    #
    # @return [Array<String>, nil]
    def self.custom_completions_for(zipper:, prefix:)
      command = zipper.last.current_command
      return unless command

      completions =
        case command.token.raw_content
        when "add"
          Git.unstaged_files(prefix:, limit: MAX_COMPLETIONS)
        when "checkout", "diff", "merge", "rebase", "switch"
          Git.other_branch_names(prefix:, limit: MAX_COMPLETIONS)
        when "restore"
          options = zipper.drop(zipper.index.succ).select(&:option?)
          if options.any? { |opt| opt.token.raw_content in "-S" | "--staged" }
            Git.staged_files(prefix:, limit: MAX_COMPLETIONS)
          else
            Git.unstaged_files(prefix:, limit: MAX_COMPLETIONS)
          end
        when "log", "revert", "reset"
          Git.commits(limit: MAX_COMPLETIONS) if zipper.trailing_whitespace?
        end

      completions unless completions.nil? || completions.empty?
    end
    private_class_method :custom_completions_for
  end
end
