# frozen_string_literal: true

require "open3"
require "tty-which"
require "English"

module Gitsh
  module Git
    # @return [Boolean]
    def self.installed?
      TTY::Which.exist?("git")
    end

    # @return [Boolean]
    def self.repo?
      `git rev-parse --is-inside-work-tree`.strip == "true"
    end

    # @return [String, nil]
    def self.current_branch
      branch_name = `git rev-parse --abbrev-ref HEAD`.strip
      branch_name unless branch_name.empty?
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
    def self.commands
      @commands ||= `git --list-cmds=main,nohelpers`
        .lines
        .map(&:strip)
        .reject(&:empty?)
        .freeze
    end

    # @return [Process::Status]
    def self.run(*args, out: $stdout, err: $stderr)
      system("git", *args, out: out, err: err)
      $CHILD_STATUS
    end
  end
end
