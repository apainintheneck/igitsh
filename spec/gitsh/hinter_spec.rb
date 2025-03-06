# frozen_string_literal: true

require "rainbow"

RSpec.describe Gitsh::Hinter, :without_git, :stub_git_help_all do
  describe ".from_completion" do
    before do
      allow(Gitsh::Git).to receive(:command_names).and_return(%w[diff])
      allow(Gitsh::Git).to receive(:command_set).and_return(Set["diff"])
      allow(Gitsh::Git).to receive(:command_descriptions).and_call_original
    end

    context "with Git command" do
      it "returns command hints for 40 char width" do
        command_hints = Gitsh::Git.command_descriptions.keys.sort.to_h do |command|
          [command, described_class.from_completion(command, width: 40)]
        end

        expect(command_hints).to match_snapshot("wide_command_hints")
      end

      it "returns command hints for 10 char width" do
        command_hints = Gitsh::Git.command_descriptions.keys.sort.to_h do |command|
          [command, described_class.from_completion(command, width: 10)]
        end

        expect(command_hints).to match_snapshot("slim_command_hints")
      end

      it "returns empty array when width is less than 10" do
        expect(described_class.from_completion("diff", width: 9)).to be_empty
      end
    end

    context "with internal command" do
      it "returns command hints" do
        command_hints = Gitsh::Commander.internal_command_names.sort.to_h do |command|
          [command, described_class.from_completion(command, width: 25)]
        end

        expect(command_hints).to match_snapshot("internal_command_hints")
      end
    end
  end
end
