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

      def run
        option_name, *rest = @arguments

        return default if option_name.nil?

        option = self.class.options_by_name[option_name]

        if option.nil?
          return error("unknown option: '#{option_name}'")
        elsif option.block.arity != rest.size
          return error("invalid arguments for '#{option_name}': #{rest}")
        end

        option.block.call(*rest).to_i
      end

      def error(message)
        @out.puts "error: #{message}"
        @out.puts
        @out.puts self.class.help_text
        FAILURE_CODE
      end

      Option = Struct.new(:name, :description, :block, keyword_init: true) do
        def usage
          params = block.parameters.filter_map do |type, name|
            "<#{name}>" if type == :opt
          end

          [name, *params].join(" ")
        end
      end

      class << self
        def name
        end

        def description
        end

        def inherited(subclass)
          subclass.def_option(
            name: "--help",
            description: "Show this help page"
          ) do |*, out:, err:|
            out.puts subclass.help_text
            SUCCESS_CODE
          end
        end

        def options
          @options.freeze
        end

        def options_by_name
          @options_by_name ||= options.each_with_object({}) do |option, hash|
            hash[option.name] = option
          end.freeze
        end

        def help_text
          @help_text ||= begin
            require "erb"

            template = <<~HELP
              GITSH-<%= command.name.delete_prefix(":").upcase %>(1)

              NAME
                    <%= command.name %>

              DESCRIPTION
              <% command.description.strip.lines.each do |line| %>
                    <%= line %>
              <% end %>

              OPTIONS
              <% command.options.sort_by(&:name).each do |option| %>
                    <%= option.usage %>
                          <%= option.description %>
              <% end %>
            HELP

            ERB.new(template, trim_mode: "<>").result_with_hash(command: self)
          end
        end

        protected

        def def_option(name:, description:, &block)
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
      # @raise [Gitsh::ExitError]
      def default
        raise ExitError
      end

      class << self
        def name
          ":exit"
        end

        def description
          "Gracefully exit the program. This is equivalent to ctrl-c and ctrl-d."
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

    def self.from_name(name)
      name_to_command.fetch(name, Git)
    end

    def self.internal_commands
      @internal_commands ||= Base.subclasses
    end

    def self.name_to_command
      @name_to_command ||= internal_commands
        .to_h { |subclass| [subclass.name, subclass] }
        .freeze
    end

    def self.internal_list
      @internal_list ||= name_to_command.keys.freeze
    end
  end
end
