# frozen_string_literal: true

RSpec.describe Igitsh::Commander, :without_git do
  describe ".internal_command_names" do
    let(:command_names) { described_class.internal_command_names }

    it "has unique command names" do
      expect(command_names).to eq(command_names.uniq)
    end

    it "has valid command names" do
      expect(command_names).to all(match(/^:[a-z]+$/))
    end
  end

  describe ".from_name" do
    it "returns internal command" do
      expect(described_class.from_name(":exit")).to eq(described_class::Exit)
    end

    it "falls back to Git command when not internal" do
      expect(described_class.from_name("diff")).to eq(described_class::Git)
    end
  end

  describe ".internal_commands" do
    it "has name and description set for each command", :aggregate_failures do
      described_class.internal_commands.each do |command|
        expect(command.name).to be_a(String), "`#{command}.name` is not set"
        expect(command.description).to be_a(String), "`#{command}.description` is not set"
      end
    end

    context "with options" do
      it "has at least one option per command", :aggregate_failures do
        described_class.internal_commands.each do |command|
          expect(command.options).not_to be_empty, "`#{command}` must have at least one option"
        end
      end

      it "has unique options per command" do
        described_class.internal_commands.each do |command|
          expect(command.options.map(&:name))
            .to eq(command.options.map(&:name).uniq), "`#{command}` must have unique options"
        end
      end

      it "has valid option blocks per command", :aggregate_failures do
        described_class.internal_commands.each do |command|
          command.options.each do |option|
            expect(option.name).to be_nil.or(match(/^-(-[a-z]+)+$/)),
              "`#{command}` has invalid option name `#{option.name}`"
          end
        end
      end
    end
  end

  describe "::Commands" do
    it "shows the command list" do
      allow(::Igitsh::Git).to receive(:raw_command_descriptions).and_call_original
      expect(::Igitsh::Terminal).to receive(:page).with(match_snapshot("internal_command_list_output"))

      described_class::Commands.new([":commands"], out: File::NULL, err: File::NULL).run
    end
  end

  describe "::Git" do
    it "matches the #initialize params of the Base class" do
      expect(described_class::Git.instance_method(:initialize).parameters)
        .to eq(described_class::Base.instance_method(:initialize).parameters)
    end

    it "matches the #run params of the Base class" do
      expect(described_class::Git.instance_method(:run).parameters)
        .to eq(described_class::Base.instance_method(:run).parameters)
    end
  end

  describe "::Help" do
    it "matches the #initialize params of the Base class" do
      expect(described_class::Help.instance_method(:initialize).parameters)
        .to eq(described_class::Base.instance_method(:initialize).parameters)
    end

    it "matches the #run params of the Base class" do
      expect(described_class::Help.instance_method(:run).parameters)
        .to eq(described_class::Base.instance_method(:run).parameters)
    end

    it "shows help pages for internal commands", :aggregate_failures do
      described_class.internal_commands.each do |command|
        expect(::Igitsh::Terminal).to receive(:page).with(command.help_text)

        described_class::Help.new(["help", command.name], out: File::NULL, err: File::NULL).run
      end
    end

    it "calls out to git for external commands", :aggregate_failures do
      allow(::Igitsh::Git).to receive(:run)
      %w[commit push].each do |command_name|
        expect(::Igitsh::Git).to receive(:run).with(["help", command_name], out: File::NULL, err: File::NULL)

        described_class::Help.new(["help", command_name], out: File::NULL, err: File::NULL).run
      end
    end
  end

  describe "Base.help_text" do
    it "prints a nice help page for each command" do
      help_pages = described_class.internal_commands.to_h do |command|
        [command.name, command.help_text]
      end

      expect(help_pages).to match_snapshot("internal_command_help_pages")
    end
  end
end
