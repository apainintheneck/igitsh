# frozen_string_literal: true

module Gitsh
  module Commander
    class Base
      SUCCESS_CODE = 0
      FAILURE_CODE = 1

      # @param arguments [Array<String>]
      # @param out [IO]
      # @param err [IO]
      #
      # @return [Integer]
      def initialize(arguments, out:, err:)
        if instance_of?(Base)
          raise ArgumentError, "#{self.class} should not get initialized directly"
        end

        name = arguments.first

        if self.class.name != name
          raise ArgumentError, "unexpected command name: #{name}"
        end

        @arguments = arguments.drop(1).freeze
        @out = out
        @err = err
      end

      # @return [Integer] exit code
      def run
        option_name, *rest = @arguments
        option = self.class.option_by_prefix[option_name]

        if option.nil?
          return error("invalid option: '#{option_name}'")
        end

        begin
          option.block.call(*rest, out: @out, err: @err).to_i
        rescue ArgumentError
          error("invalid arguments: #{rest}")
        end
      end

      # Print the error message and the help page.
      #
      # @param message [String]
      #
      # @return [Integer] failure code
      def error(message)
        @out.puts "error: #{message}"
        @out.puts self.class.help_text
        FAILURE_CODE
      end

      # @param name [String, nil]
      # @param description [String]
      # @param block [Proc]
      Option = Struct.new(:name, :description, :block, keyword_init: true) do
        # @return [String]
        def prefix
          name || "*"
        end

        # @return [String]
        def suffix
          params = block.parameters.filter_map do |type, name|
            "<#{name}>" if type == :opt
          end

          params.empty? ? "" : " " + params.join(" ")
        end

        # @return [String]
        def usage
          prefix + suffix
        end
      end

      class << self
        # Override in subclass.
        #
        # @return [String]
        def name
        end

        # Override in subclass.
        #
        # @return [String]
        def description
        end

        # Callback to define help option on all subclasses.
        #
        # @param subclass [Gitsh::Commander::Base]
        def inherited(subclass)
          subclass.def_option(
            name: "--help",
            description: "Show this help page."
          ) do |*, out:, **|
            out.puts subclass.help_text
            SUCCESS_CODE
          end
        end

        # @return [Array<Gitsh::Commander::Base>]
        def options
          @options.freeze
        end

        # @return [Hash<String, Gitsh::Commander::Base>]
        def option_by_prefix
          @option_by_prefix ||= options.to_h do |option|
            [option.name, option]
          end.freeze
        end

        # All option prefixes for an internal command minus `--help`.
        # Used for completions so `--help` is often not useful.
        #
        # @return [Array<String>]
        def option_prefixes
          @option_prefixes ||= option_by_prefix
            .keys
            .compact
            .difference(%w[--help])
            .freeze
        end

        # @return [String]
        def help_text
          @help_text ||= begin
            formatted_options = options.sort_by(&:prefix).flat_map do |option|
              [
                Stringer.indent_by(option.usage, size: 6),
                *Stringer.wrap_ascii(option.description, width: 60, indent: 12)
              ]
            end.join("\n")

            <<~HELP
              GITSH-#{name.delete_prefix(":").upcase}(1)

              NAME
              #{Stringer.indent_by(name, size: 6)}

              DESCRIPTION
              #{Stringer.wrap_ascii(description.strip, width: 54, indent: 6).join("\n")}

              OPTIONS
              #{formatted_options}
            HELP
          end
        end

        protected

        # @param description [String]
        # @param block [Proc]
        def def_default(description:, &block)
          @options ||= []

          @options << Option.new(
            name: nil,
            description: description,
            block: block
          ).freeze

          nil
        end

        # @param name [String]
        # @param description [String]
        # @param block [Proc]
        def def_option(name:, description:, &block)
          raise ArgumentError, "name must be a string" unless name.is_a?(String)

          @options ||= []

          @options << Option.new(
            name: name,
            description: description,
            block: block
          ).freeze

          nil
        end
      end
    end

    class Exit < Base
      def_default(description: "Exit the program.") do
        raise ExitError
      end

      class << self
        # @return [String]
        def name
          ":exit"
        end

        # @return [String]
        def description
          "Gracefully exit the program. This is equivalent to ctrl-c or ctrl-d."
        end
      end
    end

    class Alias < Base
      def_option(
        name: "--local",
        description: "Define a local alias for the current repo."
      ) do |name, command, out:, err:|
        Git.run("config", "--local", "alias.#{name}", command, out: out, err: err)
      end

      def_option(
        name: "--global",
        description: "Define a global alias."
      ) do |name, command, out:, err:|
        Git.run("config", "--global", "alias.#{name}", command, out: out, err: err)
      end

      class << self
        # @return [String]
        def name
          ":alias"
        end

        # @return [String]
        def description
          "Create local and global Git aliases for common command combinations."
        end
      end
    end

    class Git
      # @param arguments [Array<String>]
      # @params out [IO]
      # @params err [IO]
      #
      # @return [Integer]
      def initialize(arguments, out:, err:)
        @arguments = arguments.freeze
        @out = out
        @err = err
      end

      # @return [Integer]
      def run
        ::Gitsh::Git.run(@arguments, out: @out, err: @err)
      end
    end

    # @param name [String]
    #
    # @return [Gitsh::Commander::Base, Gitsh::Commander::Git]
    def self.from_name(name)
      name_to_command.fetch(name, Git)
    end

    # @return [Hash<String, Class>]
    def self.name_to_command
      @name_to_command ||= internal_commands
        .to_h { |subclass| [subclass.name, subclass] }
        .freeze
    end

    # @return [Array<Class>]
    def self.internal_commands
      @internal_commands ||= Base.subclasses
    end

    # @return [Array<String>]
    def self.internal_command_names
      @internal_command_names ||= internal_commands.map(&:name).freeze
    end
  end
end
