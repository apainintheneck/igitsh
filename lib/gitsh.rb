# frozen_string_literal: true

require_relative "gitsh/version"
require "reline"
require "xdg"

module Gitsh
  class Error < StandardError; end

  class SyntaxError < Error; end

  class ParseError < Error; end

  autoload :Command, "gitsh/command"
  autoload :Executor, "gitsh/executor"
  autoload :Git, "gitsh/git"
  autoload :Highlighter, "gitsh/highlighter"
  autoload :Parser, "gitsh/parser"
  autoload :Prompt, "gitsh/prompt"
  autoload :Token, "gitsh/token"
  autoload :TokenZipper, "gitsh/token_zipper"
  autoload :Tokenizer, "gitsh/tokenizer"

  HISTORY_FILE_PATH = (XDG::Data.new.home / "gitsh/history").freeze
  USE_COLOR = ENV["NO_COLOR"].then { _1.nil? || _1.empty? }

  def self.run!
    # Set up shell history.
    original_history = Reline::HISTORY.to_a
    if HISTORY_FILE_PATH.exist?
      Reline::HISTORY.replace(HISTORY_FILE_PATH.read.lines(chomp: true).uniq)
    else
      HISTORY_FILE_PATH.dirname.mkpath
      Reline::HISTORY.clear
    end

    # Set up shell completions.
    Reline.autocompletion = true
    Reline.completion_proc = method(:completions)
    Reline.output_modifier_proc = method(:highlight) if USE_COLOR

    puts "# Welcome to gitsh!"

    exit_code = 0

    # Run the shell REPL in a loop.
    loop do
      prompt = Prompt.string(exit_code: exit_code)
      line = Reline.readline(prompt)&.strip
      break if line.nil?
      next if line.empty?

      result = Executor.execute_line(line: line)

      case result
      when Gitsh::Executor::Result::Success
        # Save the current input line to the shell history.
        if Reline::HISTORY.last != line
          Reline::HISTORY.push(line)
          HISTORY_FILE_PATH.write("#{line}\n", mode: "a")
        end
      when Gitsh::Executor::Result::Failure
        # Only save the lines with syntax or parsing errors to the session history.
        if Reline::HISTORY.last != line
          Reline::HISTORY.push(line)
        end
      when Gitsh::Executor::Result::Exit
        # The user entered 'exit' or 'quit'.
        return
      end

      exit_code = result.exit_code
    end
  ensure
    # Note: This is only useful when testing in IRB.
    Reline::HISTORY.replace(original_history)
  end

  # @return [Array<String>]
  def self.all_commands
    @all_commands ||= (Git.commands + %w[exit quit]).freeze
  end

  # @param word [String]
  #
  # @return [Array<String>, nil]
  def self.completions(word)
    return if word.empty?

    last_token_zipper = line_token_zipper.last
    return unless last_token_zipper.command?
    return if last_token_zipper.valid_command?

    all_commands
      # Complete all commands starting with the given prefix.
      .grep(/^#{Regexp.escape(word)}./)
      # Sort results by shortest command and then alphabetically.
      .sort_by { |cmd| [cmd.size, cmd] }
  end
  private_class_method :completions

  # @return [String]
  def self.highlight(...)
    Highlighter.from_token_zipper(line_token_zipper)
  end

  # @return [Gitsh::TokenZipper]
  def self.line_token_zipper
    Gitsh::Tokenizer.tokenize(Reline.line_buffer)
  end
  private_class_method :line_token_zipper
end
