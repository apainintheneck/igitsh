# frozen_string_literal: true

require "strscan"

module Igitsh
  # Represents the help page for a Git command along with
  # any relevant usage and option information that was
  # able to be parsed from it.
  class GitHelp
    # @param command [String]
    #
    # @return [Igitsh::GitHelp, nil]
    def self.from_name(command)
      return unless Git.command_set.include?(command)

      @from_name ||= {}
      @from_name[command] ||= new(command: command)
    end

    # To make testing less order dependent.
    def self.clear_cache!
      @from_name = nil
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
      @option_prefixes ||= options_by_prefix.keys.freeze
    end

    # @return [Hash<String, Igitsh::GitHelp::Option>]
    def options_by_prefix
      @options_by_prefix ||= options.group_by(&:prefix).freeze
    end

    # Extract options from the help page.
    #
    # @return [Array<Igitsh::Git::Option>]
    def options
      @options ||= [].tap do |options|
        help_text = Git.help_page(command: @command)
        next unless help_text

        scanner = StringScanner.new(help_text)

        # NOTE: Options are only parsed after section headings or empty lines
        # since other lines prefixed by dashes might not represent options
        # but other text like descriptions, explanations and examples instead.
        loop do
          if scanner.skip(/(\n?[A-Z].+)?\n/) # Skip section headings and empty lines.
            if scanner.skip("       ") # Skip leading whitespace.
              while scanner.match?("-") # Parse options prefixed by dashes.
                prefixes =
                  if (short_prefix = scanner.scan(/-[a-zA-Z]/))
                    # Parse short option prefix.
                    # Ex. `-a`
                    [short_prefix]
                  elsif (long_prefix = scanner.scan(/-(?:-[a-zA-Z]+)+/))
                    # Parse long option prefix.
                    # Ex. `--source`
                    [long_prefix]
                  elsif (reversible_prefix = scanner.skip("--[no]") && scanner.scan(/(?:-[a-zA-Z]+)+/))
                    # Parse long reversible option prefix.
                    # Ex. `--[no]-source`
                    ["-#{reversible_prefix}", "--no#{reversible_prefix}"]
                  end

                break unless prefixes

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
            end
          end
          break unless scanner.skip_until(/\n/) # Parse until the end of the line.
        end
      end.uniq.freeze
    end
  end
end
