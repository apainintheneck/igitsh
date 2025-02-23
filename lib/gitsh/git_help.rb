# frozen_string_literal: true

require "strscan"

module Gitsh
  # Represents the help page for a Git command along with
  # any relevant usage and option information that was
  # able to be parsed from it.
  class GitHelp
    # @param command [String]
    #
    # @return [Gitsh::GitHelp, nil]
    def self.for(command:)
      return unless Git.command_set.include?(command)

      @for ||= {}
      @for[command] ||= new(command: command)
    end

    private_class_method :new

    # @param command [String]
    attr_reader :command

    # @param command [String]
    def initialize(command:)
      @command = command
    end

    # @param prefix [String]
    # @param suffix [String]
    Option = Struct.new(:prefix, :suffix, keyword_init: true) do
      # @return [Boolean]
      def long?
        prefix.start_with?("--")
      end

      # @return [Boolean]
      def short?
        !long?
      end

      # @return [String]
      def to_s
        prefix + suffix
      end
    end

    # @return [Array<String>]
    def option_prefixes
      @option_prefixes ||= options
        .map(&:prefix)
        .uniq
        .freeze
    end

    # @return [Hash<String, Gitsh::GitHelp::Option>]
    def options_by_prefix
      @options_by_prefix ||= options.group_by(&:prefix).freeze
    end

    # Extract options from the help page.
    #
    # @return [Array<Gitsh::Git::Option>]
    def options
      @options ||= [].tap do |options|
        help_text = Git.help_page(command: @command)
        next unless help_text

        scanner = StringScanner.new(help_text)

        # Skip straight to the OPTIONS section.
        scanner.skip_until(/\nOPTIONS\n/)
        before_option = true

        # Parse until the end of the string or docs.
        until scanner.eos? || scanner.match?(/GIT/)
          if before_option && scanner.skip("       ") # Skip leading whitespace.
            # Continue parsing options prefixed by dashes.
            while scanner.match?("-")
              prefixes = []

              if (short_prefix = scanner.scan(/-[a-zA-Z]/))
                # Parse short option prefix.
                # Ex. `-a`
                prefixes << short_prefix
              elsif (long_prefix = scanner.scan(/-(?:-[a-zA-Z]+)+/))
                # Parse long option prefix.
                # Ex. `--source`
                prefixes << long_prefix
              elsif (reversible_prefix = scanner.skip("--[no]") && scanner.scan(/(?:-[a-zA-Z]+)+/))
                # Parse long reversible option prefix.
                # Ex. `--[no]-source`
                prefixes << "-#{reversible_prefix}"
                prefixes << "--no#{reversible_prefix}"
              else
                # Break when no option prefixes are parsed.
                break
              end

              # Parse suffix including any parameters by parsing everything
              # up to the next newline or command followed by a space.
              suffix = scanner.scan(/(?:[^\n,]|,\S)*/).rstrip

              # Skip the suffix if it is not usage guidelines but just a general description.
              suffix = "" if suffix.match?(/^\s*[a-zA-Z0-9]/)

              prefixes.each do |prefix|
                options << Option.new(prefix: prefix.freeze, suffix: suffix.freeze).freeze
              end

              # Break if there isn't a comma indicating another command.
              break unless scanner.skip(", ")
            end
            before_option = false
          elsif scanner.match?(/[A-Z\n]/) # Check for empty line or section name.
            before_option = true
          else
            before_option = false
          end

          # Parse until the end of the line.
          scanner.skip_until(/\n/)
        end
      end.uniq.freeze
    end
  end
end
