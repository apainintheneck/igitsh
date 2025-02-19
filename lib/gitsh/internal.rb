# frozen_string_literal: true

module Gitsh
  module Internal
    module Exit
      # @raise [Gitsh::ExitError]
      def self.run(...)
        raise ExitError
      end
    end

    COMMAND_NAME_TO_MODULE = {
      ":exit" => Exit,
      ":quit" => Exit
    }.freeze

    COMMANDS = COMMAND_NAME_TO_MODULE.keys.freeze
  end
end
