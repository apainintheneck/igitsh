# frozen_string_literal: true

require "tty-pager"

module Igitsh
  module Terminal
    # @param content [String, nil]
    # @block for incrementally adding content to the pager
    def self.page(content = nil, &block)
      if block
        TTY::Pager.page(&block)
      elsif content
        command = [
          "less",
          "--clear-screen", # make sure everything is top-justified
          "--tilde", # don't show tildes on lines after the output
          "--prompt='(press h for help or q to quit)'"
        ].join(" ")

        pager = TTY::Pager::SystemPager.new(command: command)
        pager.page(content)
      else
        raise ArgumentError, "no content or block specified"
      end
    end
  end
end
