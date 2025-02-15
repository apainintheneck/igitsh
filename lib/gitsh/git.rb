# frozen_string_literal: true

require "open3"
require "tty-which"
require "English"
require "set" # needed for Ruby 3.1 support

module Gitsh
  module Git
    # @return [Boolean]
    def self.installed?
      TTY::Which.exist?("git")
    end

    # @return [Boolean]
    def self.repo?
      out_str, _err_str, _status = Open3.capture3("git rev-parse --is-inside-work-tree")
      out_str.strip == "true"
    end

    # @return [String, nil]
    def self.current_branch
      out_str, _err_str, _status = Open3.capture3("git rev-parse --abbrev-ref HEAD")
      branch_name = out_str.strip
      branch_name unless branch_name.empty?
    end

    # @param command [String]
    #
    # @return [String, nil]
    def self.help_page(command:)
      return unless command_set.include?(command)

      out_str, _err_str, _status = Open3.capture3("git", "help", "--man", command)
      help_text = out_str.strip
      help_text unless help_text.empty?
    end

    Changes = Struct.new(:staged_count, :unstaged_count, keyword_init: true)

    # @return [Changes]
    def self.uncommitted_changes
      staged_count = 0
      unstaged_count = 0

      `git status --porcelain`.each_line(chomp: true) do |line|
        staged_count += 1 if ("A".."Z").cover?(line[0])
        unstaged_count += 1 if ("A".."Z").cover?(line[1])
      end

      Changes.new(
        staged_count: staged_count,
        unstaged_count: unstaged_count
      )
    end

    # @return [Array<String>]
    def self.command_list
      @commands ||= `git --list-cmds=main,nohelpers`
        .lines
        .map(&:strip)
        .reject(&:empty?)
        .freeze
    end

    # @return [Set<String>]
    def self.command_set
      @command_set ||= command_list.to_set.freeze
    end

    # @param args [Array<String>]
    # @param out [IO] (default STDOUT)
    # @param err [IO] (default STDIN)
    #
    # @return [Integer]
    def self.run(args, out: $stdout, err: $stderr)
      system("git", *args, out: out, err: err)
      # TODO: Handle signal failures here that don't show themselves in exit codes.
      $CHILD_STATUS.exitstatus.to_i
    end
  end
end
