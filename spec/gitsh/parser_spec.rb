# frozen_string_literal: true

RSpec.describe Gitsh::Parser do
  it "parses a single command" do
    expect(described_class.parse("checkout auto_update_tap"))
      .to eq([Gitsh::Command::End.new(arguments: %w[checkout auto_update_tap])])
  end

  it "parses multiple commands", :aggregated_failures do
    [
      [
        %(add --all; commit -m "tmp"),
        [
          Gitsh::Command::End.new(arguments: %w[add --all]),
          Gitsh::Command::End.new(arguments: %w[commit -m tmp])
        ]
      ],
      [
        %(add --all || commit -m "tmp"),
        [
          Gitsh::Command::End.new(arguments: %w[add --all]),
          Gitsh::Command::Or.new(arguments: %w[commit -m tmp])
        ]
      ],
      [
        %(add --all && commit -m "tmp"),
        [
          Gitsh::Command::End.new(arguments: %w[add --all]),
          Gitsh::Command::And.new(arguments: %w[commit -m tmp])
        ]
      ]
    ].each do |line, parse_result|
      expect(described_class.parse(line)).to eq(parse_result)
    end
  end

  it "parses a long series of commands" do
    expect(described_class.parse("add ex.js && add ex.rb; git diff; git commit -m 'commit'")).to eq([
      Gitsh::Command::End.new(arguments: %w[add ex.js]),
      Gitsh::Command::And.new(arguments: %w[add ex.rb]),
      Gitsh::Command::End.new(arguments: %w[git diff]),
      Gitsh::Command::End.new(arguments: %w[git commit -m commit])
    ])
  end

  it "parses and ignores a trailing semicolon" do
    expect(described_class.parse(%(grep 'rescue Github::API';)))
      .to eq([Gitsh::Command::End.new(arguments: ["grep", "rescue Github::API"])])
  end

  it "raises an error when there is an action to start a line", :aggregate_failures do
    %w[&& || ;].each do |action|
      line = [action, "second", "third"].join(" ")
      error_message = "0:#{action.size - 1}: Expected a string to start the line but got '#{action}' instead"

      expect { described_class.parse(line) }
        .to raise_error(Gitsh::ParseError, error_message)
    end
  end

  it "raises an error when there are two actions in a row in the middle of a line", :aggregate_failures do
    %w[&& || ;].repeated_combination(2).each do |combo|
      line = ["first", *combo, "last"].join(" ")
      error_message = "Expected a string after '#{combo.first}' but got '#{combo.last}' instead"
      error_message_end = /#{Regexp.escape(error_message)}$/

      expect { described_class.parse(line) }
        .to raise_error(Gitsh::ParseError, error_message_end)
    end
  end

  it "raises an error when there is a && or || action to end a line", :aggregate_failures do
    %w[&& ||].each do |action|
      line = ["first", "second", action].join(" ")
      error_message = "13:14: Expected a string or a semicolon to end the line but got '#{action}' instead"

      expect { described_class.parse(line) }
        .to raise_error(Gitsh::ParseError, error_message)
    end
  end
end
