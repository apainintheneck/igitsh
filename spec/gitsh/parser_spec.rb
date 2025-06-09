# frozen_string_literal: true

RSpec.describe Igitsh::Parser, :without_git do
  let(:error) { Rainbow("error>").blue.bold }

  def expect_parsed_lines(lines)
    parsed_lines = Array(lines).map do |line|
      {
        line: line,
        commands: described_class.parse(line)
      }
    end

    expect(parsed_lines)
  end

  it "parses a single command" do |example|
    expect_parsed_lines([
      "checkout auto_update_tap",
      "git clone https://github.com/ruby/irb.git",
      "grep -C 5 -i -F match_snapshot"
    ]).to match_snapshot(example.description.tr(" ", "_"))
  end

  it "parses multiple commands" do |example|
    expect_parsed_lines([
      %(add --all; commit -m "tmp"),
      %(add --all || commit -m "tmp"),
      %(add --all && commit -m "tmp")
    ]).to match_snapshot(example.description.tr(" ", "_"))
  end

  it "parses a long series of commands" do |example|
    expect_parsed_lines([
      "add ex.js && add ex.rb; git diff; git commit -m 'commit'",
      "git grep -q match_snapshot && git add .; git commit -m snapshots",
      "git log -5 || git diff HEAD && git commit --amend"
    ]).to match_snapshot(example.description.tr(" ", "_"))
  end

  it "parses and ignores a trailing semicolon" do |example|
    expect_parsed_lines([
      "git grep 'Github::API';",
      "diff head   ;  ",
      "git commit --amend;  "
    ]).to match_snapshot(example.description.tr(" ", "_"))
  end

  it "raises an error when there is an action to start a line", :aggregate_failures do
    %w[&& || ;].each do |action|
      line = [action, "second", "third"].join(" ")
      expect { described_class.parse(line) }.to raise_error(Igitsh::ParseError, <<~ERROR)
        | #{error} unexpected '#{action}' to start the line
        |
        | #{action} second third
        | #{"^" * action.length}
      ERROR
    end
  end

  it "raises an error when there are two actions in a row in the middle of a line", :aggregate_failures do
    %w[&& || ;].repeated_combination(2).each do |second, third|
      line = ["first", second, third, "last"].join(" ")
      expect { described_class.parse(line) }.to raise_error(Igitsh::ParseError, <<~ERROR)
        | #{error} expected a string after '#{second}' but got '#{third}' instead
        |
        | first #{second} #{third} last
        |       #{" " * second.length} #{"^" * third.length}
      ERROR
    end
  end

  it "raises an error when there is a && or || action to end a line", :aggregate_failures do
    %w[&& ||].each do |action|
      line = ["first", "second", action].join(" ")
      expect { described_class.parse(line) }.to raise_error(Igitsh::ParseError, <<~ERROR)
        | #{error} unexpected '#{action}' to end the line
        |
        | first second #{action}
        |              #{"^" * action.length}
      ERROR
    end
  end
end
