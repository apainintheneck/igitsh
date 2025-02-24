# frozen_string_literal: true

module Gitsh
  # This is a data structure representing an array of tokens with the index
  # pointing at an individual token. The advantage of this data structure
  # over an array is that it allows you to reference the tokens before
  # and after the current token, adds a bunch of helper methods and
  # allows data to be shared between tokens. When moving to another
  # token it will return a copy of itself with the index, before and
  # after values changed to minimize copying of strings.
  class TokenZipper
    include Enumerable

    # @return [String]
    attr_reader :source
    # @return [Array<Gitsh::Token::Base>]
    attr_reader :tokens
    # @return [Integer]
    attr_reader :index

    # @param source [String] must be frozen
    # @param tokens [Array<Gitsh::Token::Base>] must be frozen
    # @param index [Integer] Defaults to 0
    # @param before [Gitsh::TokenZipper] Defaults to nil
    # @param after [Gitsh::TokenZipper] Defaults to nil
    # @param first [Gitsh::TokenZipper] Defaults to nil
    # @param last [Gitsh::TokenZipper] Defaults to nil
    def initialize(source:, tokens:, index: 0, before: nil, after: nil, first: nil, last: nil)
      raise ArgumentError, ":source must be frozen" unless source.frozen?
      raise ArgumentError, ":tokens must be frozen" unless tokens.frozen?

      @source = source
      @tokens = tokens
      @index = index.clamp(-1, tokens.size)
      @before = before if before
      @after = after if after
      @first = first if first
      @last = last if last
    end

    # Returns the number of tokens.
    #
    # @return [Integer]
    def size
      @tokens.size
    end

    # Returns true if there are no tokens.
    #
    # @return [Boolean]
    def empty?
      @tokens.empty?
    end

    # Yields zippers representing each token starting from the beginning.
    #
    # @yield [Gitsh::TokenZipper]
    def each
      return if empty?

      zipper = first

      until zipper.tail?
        yield zipper
        zipper = zipper.after
      end
    end

    # Yields zippers representing each token starting from the end.
    #
    # @yield [Gitsh::TokenZipper]
    def reverse_each
      return if empty?

      zipper = last

      until zipper.head?
        yield zipper
        zipper = zipper.before
      end
    end

    # Like `#find` but starting from the end.
    #
    # @yield [Gitsh::TokenZipper]
    # @return [Gitsh::TokenZipper, nil]
    def reverse_find
      reverse_each do |zipper|
        bool = yield zipper
        return zipper if bool
      end
    end

    # @return [Gitsh::TokenZipper] a new zipper representing the previous token
    def before
      @before ||= if head?
        self
      else
        self.class.new(
          source: @source,
          tokens: @tokens,
          index: @index - 1,
          after: self,
          first: @first,
          last: @last
        )
      end
    end

    # @return [Gitsh::TokenZipper] a new zipper representing the next token
    def after
      @after ||= if tail?
        self
      else
        self.class.new(
          source: @source,
          tokens: @tokens,
          index: @index + 1,
          before: self,
          first: @first,
          last: @last
        )
      end
    end

    # @param index [Integer]
    #
    # @return [Gitsh::TokenZipper] a new zipper representing the token at the index
    def at(index:)
      return self if index == @index
      return before if index == @index - 1
      return after if index == @index + 1

      self.class.new(source: @source, tokens: @tokens, index: index)
    end

    # The gap between the end position of the current token and
    # the start position of the next token.
    #
    # @return [Integer]
    def gap_to_next
      return 0 if head? || tail? || after.tail?

      after.token.start_position - token.end_position
    end

    # The gap between the end position of the previous token and
    # the start position of the current token.
    #
    # @return [Integer]
    def gap_to_prev
      return 0 if head? || tail? || before.head?

      token.start_position - before.token.end_position
    end

    # Represents a zipper before the first token.
    #
    # @return [Boolean]
    def head?
      @index.negative?
    end

    # Represents a zipper after the last token.
    #
    # @return [Boolean]
    def tail?
      tokens.size <= @index
    end

    # Returns true if the zipper represents the first token.
    #
    # @return [Boolean]
    def first?
      !tail? && before.head?
    end

    # Returns the zipper associated with the first token or head.
    #
    # @return [Gitsh::Zipper]
    def first
      @first ||= empty? ? at(index: -1) : at(index: 0)
    end

    # Returns true if the zipper represents the last token.
    #
    # @return [Boolean]
    def last?
      !head? && after.tail?
    end

    # Returns the zipper associated with the first token or head.
    #
    # @return [Gitsh::Zipper]
    def last
      @last ||= empty? ? at(index: size) : at(index: size - 1)
    end

    # Returns the token at the current index or nil
    # if the current index is the head or the tail.
    #
    # @return [Gitsh::Token::Base, nil]
    def token
      @tokens[@index] unless head? || tail?
    end

    # Returns true if the current token is a string.
    #
    # @return [Boolean]
    def string_token?
      token&.is_a?(Gitsh::Token::String)
    end

    # Returns true if the current token is the and action.
    #
    # @return [Boolean]
    def and_token?
      token&.is_a?(Gitsh::Token::And)
    end

    # Returns true if the current token is the or action.
    #
    # @return [Boolean]
    def or_token?
      token&.is_a?(Gitsh::Token::Or)
    end

    # Returns true if the current token is the end action.
    #
    # @return [Boolean]
    def end_token?
      token&.is_a?(Gitsh::Token::End)
    end

    # Returns true if the current token is a unterminated string.
    #
    # @return [Boolean]
    def unterminated_string_token?
      token&.is_a?(Gitsh::Token::UnterminatedString)
    end

    # Returns true if the current token is a partial action.
    #
    # @return [Boolean]
    def partial_action_token?
      token&.is_a?(Gitsh::Token::PartialAction)
    end

    # Returns true if the current token is the end of options token.
    #
    # @return [Boolean]
    def end_of_options_token?
      token&.is_a?(Gitsh::Token::EndOfOptions)
    end

    # Returns true if the current token is the and, or or end action.
    #
    # @return [Boolean]
    def action?
      and_token? || or_token? || end_token?
    end

    # Returns true if the current token is a string and the previous token
    # was at the head position, an action or a partial action.
    #
    # @return [Boolean]
    def command?
      string_token? && (before.head? || before.action? || before.partial_action_token?)
    end

    # Returns true if the current token is a command present in the
    # all commands list.
    #
    # @return [Boolean]
    def valid_command?
      command? && Gitsh.all_command_names.include?(token.content)
    end

    # Returns true if the current token is a command present in the
    # internal commands list.
    #
    # @return [Boolean]
    def valid_git_command?
      command? && Gitsh::Git.command_names.include?(token.content)
    end

    # Returns true if the current token is a command present in the
    # internal commands list.
    #
    # @return [Boolean]
    def valid_internal_command?
      command? && Gitsh::Commander.internal_command_names.include?(token.content)
    end

    # Returns the most recent command if one exists before an action or head.
    #
    # @return [Gitsh::TokenZipper]
    def current_command
      return @current_command if defined?(@current_command)

      zipper = self

      while zipper.string_token? && !zipper.command?
        zipper = zipper.before
      end

      @current_command = zipper if zipper.command?
    end

    # Returns false if the end of the options token has come after a command.
    #
    # @return [Boolean]
    def options_allowed?
      zipper = before

      until head?
        return true if zipper.command?
        return false if zipper.end_of_options_token?

        zipper = zipper.before
      end

      false
    end

    # Returns true if the current_token is a short option and is not a command.
    #
    # @return [Boolean]
    def short_option?
      string_token? && token.raw_content.match?(/^-[^-]?$/) && !command?
    end

    # Returns true if the current_token is a long option and is not a command.
    #
    # @return [Boolean]
    def long_option?
      string_token? && token.raw_content.match?(/^--([^-].+)?/) && !command?
    end

    # Returns true if the current token is a short or long option and is not a command.
    #
    # @return [Boolean]
    def option?
      short_option? || long_option?
    end

    # Returns the documented parameter suffix for the current Git option prefix if options are allowed.
    #
    # @return [String, nil]
    def option_suffix
      return unless option?
      return unless options_allowed?
      return unless current_command

      if current_command.valid_git_command?
        help_page = GitHelp.for(command: current_command.token.content)
        return unless help_page

        options = help_page.options_by_prefix[token.raw_content]
        return unless options

        options.find { |option| !option.suffix.empty? }&.suffix
      elsif current_command.valid_internal_command?
        internal_command = Commander.name_to_command[current_command.token.content]
        return unless internal_command

        option = internal_command.option_by_prefix[token.raw_content]
        return unless option

        option.suffix unless option.suffix.empty?
      end
    end
  end
end
