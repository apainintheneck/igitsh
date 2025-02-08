# frozen_string_literal: true

require "rainbow/refinement"

module Gitsh
  module Prompt
    # @param exit_code [Integer]
    #
    # @return [String]
    def self.string(exit_code: 0)
      if Git.repo?
        build(
          status: exit_code,
          branch: Git.current_branch,
          changes: Git.uncommitted_changes
        )
      else
        build(status: exit_code)
      end
    end

    using Rainbow

    # @param status [Integer]
    # @param branch [String, nil]
    # @param changes [Gitsh::Git::Changes, nil]
    #
    # @return [String]
    def self.build(status:, branch: nil, changes: nil)
      string = +""

      if USE_COLOR
        string << "gitsh".color(:aqua)

        if branch
          string << "(" << branch.color(:mediumslateblue)

          if changes
            string << "|"

            if changes.unstaged_count.zero? && changes.staged_count.zero?
              string << "✔".color(:green)
            end

            if changes.staged_count.positive?
              string << "●#{changes.staged_count}".color(:yellowgreen)
            end

            if changes.unstaged_count.positive?
              string << "+#{changes.unstaged_count}".color(:blue)
            end
          end

          string << ")"
        end

        if status.positive?
          string << "[#{status}]".color(:crimson)
        end

        string << "> "

        string.bold.freeze
      else
        string << "gitsh"

        if branch
          string << "(" << branch

          if changes
            string << "|"

            if changes.unstaged_count.zero? && changes.staged_count.zero?
              string << "✔"
            end

            if changes.staged_count.positive?
              string << "●#{changes.staged_count}"
            end

            if changes.unstaged_count.positive?
              string << "+#{changes.unstaged_count}"
            end
          end

          string << ")"
        end

        if status.positive?
          string << "[#{status}]"
        end

        string << "> "

        string.freeze
      end
    end
    private_class_method :build
  end
end
