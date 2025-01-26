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
      builder = []

      builder << "gitsh".color(:aqua)

      if branch
        builder << "(" << branch.color(:magenta).bold

        if changes
          builder << "|"

          if changes.unstaged_count.zero? && changes.staged_count.zero?
            builder << "✔".color(:green).bold
          end

          if changes.staged_count.positive?
            builder << "●#{changes.staged_count}".color(:yellow)
          end

          if changes.unstaged_count.positive?
            builder << "+#{changes.unstaged_count}".color(:blue)
          end
        end

        builder << ")"
      end

      if status.positive?
        builder << "[#{status}]".color(:red)
      end

      builder << "> "

      builder.join
    end
    private_class_method :build
  end
end
