# frozen_string_literal: true

require "shellwords"
require "tty-which"
require "English"
require "set" # needed for Ruby 3.1 support

module Igitsh
  module Git
    # @return [Boolean]
    def self.installed?
      TTY::Which.exist?("git")
    end

    # @return [Boolean]
    def self.repo?
      out_str = `git rev-parse --is-inside-work-tree`
      out_str.strip == "true"
    end

    # @return [String, nil]
    def self.current_branch
      out_str = `git rev-parse --abbrev-ref HEAD`
      branch_name = out_str.strip
      branch_name unless branch_name.empty?
    end

    # @param command [String]
    #
    # @return [String, nil]
    def self.help_page(command:)
      return unless command_set.include?(command)

      shell_command = Shellwords.join(["git", "help", "--man", command])
      help_text = `#{shell_command}`.strip
      help_text unless help_text.empty?
    end

    COMMAND_DESCRIPTION_REGEX = %r{
      ^          # start of the line
      [ ]{3}     # 3 spaces
      ([a-z-]+)  # capture: command
      [ ]+       # 1 or more spaces
      (.+)       # capture: description
      $          # end of the line
    }x
    private_constant :COMMAND_DESCRIPTION_REGEX

    # @return [String]
    def self.raw_command_descriptions
      `git help --all`.strip
    end

    # @return [Hash<String, String>] hash of command to description
    def self.command_descriptions
      @command_descriptions ||= raw_command_descriptions
        .scan(COMMAND_DESCRIPTION_REGEX)
        .to_h
        .freeze
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
      ).freeze
    end

    Aliases = Struct.new(:local, :global, keyword_init: true) do
      # @param key [String]
      #
      # @return [String] value
      def fetch(key)
        value = local[key] || global[key]
        raise KeyError, "no alias for key: '#{key}'" unless value

        value
      end

      # @return [Boolean]
      def include?(name)
        local.include?(name) || global.include?(name)
      end
      alias_method :key?, :include?

      # @return [Array<String>]
      def keys
        local.keys | global.keys
      end
    end

    ALIAS_REGEX = %r{
      ^                      # Start of line
      (?<type>local|global)  # capture: type
      \s+                    # whitespace
      alias\.(?<name>\S+)    # capture: name
      \s+                    # whitespace
      (?<command>.+)         # capture: command
      $
    }x
    private_constant :ALIAS_REGEX

    # @return [Aliases]
    def self.aliases
      @aliases ||= begin
        local_hash = {}
        global_hash = {}

        `git config --show-scope --get-regexp '^alias\\.'`.each_line do |line|
          line.match(ALIAS_REGEX) do |match_result|
            case match_result[:type]
            when "local"
              local_hash[match_result[:name]] = match_result[:command].strip
            when "global"
              global_hash[match_result[:name]] = match_result[:command].strip
            end
          end
        end

        Aliases.new(local: local_hash.freeze, global: global_hash.freeze)
      end.freeze
    end

    CONFIG_LEVELS = %w[--local --global].freeze

    # @param name [String] when name already exists will ask to overwrite
    # @param command [String, nil] when nil will ask to delete
    # @param level [String] from `Igitsh::Git::CONFIG_LEVELS`
    # @param out [IO] (default STDOUT)
    # @param err [IO] (default STDIN)
    #
    # @return [Integer]
    def self.set_alias(name:, command:, level:, out:, err:)
      raise ArgumentError, "missing name" if name.nil?
      raise ArgumentError, "invalid config level: #{level}" unless CONFIG_LEVELS.include?(level)
      raise MessageError, "alias name must not include whitespace" if name.match?(/\s/)

      if command
        # Create alias
        if existing_alias?(name: name, level: level)
          # Overwrite alias
          out.puts "Existing alias: #{name}  =>  #{command}"
          out.puts "Do you want to overwrite the '#{name}' alias? [Y/n]"

          if %w[Y y].include?($stdin.getch)
            out.puts "Overwriting..."
          else
            out.puts "Skipping..."
            return 0
          end
        end

        run(["config", level, "alias.#{name}", command], out: out, err: err).tap do |exit_code|
          clear_alias_cache! if exit_code.zero? # clear cache when it was set successfully
        end
      else
        unless existing_alias?(name: name, level: level)
          raise MessageError, "can't delete nonexistent #{level} alias: #{name}"
        end

        # Delete alias
        out.puts "Do you want to delete the '#{name}' alias? [Y/n]"

        if %w[Y y].include?($stdin.getch)
          out.puts "Deleting..."
        else
          out.puts "Skipping..."
          return 0
        end

        run(["config", level, "--unset", "alias.#{name}"], out: out, err: err).tap do |exit_code|
          clear_alias_cache! if exit_code.zero? # clear cache when it was successful
        end
      end
    end

    # @param name [String]
    # @param level [String] from `Igitsh::Git::CONFIG_LEVELS`
    #
    # @return [Boolean]
    def self.existing_alias?(name:, level:)
      raise ArgumentError, "invalid config level: #{level}" unless CONFIG_LEVELS.include?(level)

      clear_alias_cache!

      case level
      when "--local"
        aliases.local.include?(name)
      when "--global"
        aliases.global.include?(name)
      else
        raise UnreachableError, "Unknown level: #{level}"
      end
    end

    def self.clear_alias_cache!
      @aliases = nil
    end

    # @return [Array<String>]
    def self.command_names
      @command_names ||= `git --list-cmds=main,nohelpers`
        .lines
        .map(&:strip)
        .reject(&:empty?)
        .freeze
    end

    # @return [Set<String>]
    def self.command_set
      @command_set ||= command_names.to_set.freeze
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
