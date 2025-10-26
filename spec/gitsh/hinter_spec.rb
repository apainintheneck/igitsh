# frozen_string_literal: true

require "rainbow"

RSpec.describe Igitsh::Hinter, :without_git do
  describe ".from_completion" do
    let(:commit_info) do
      {
        "01c6912" => "Add commit completions",
        "6d8285e" => "Avoid filtering when prefix is empty",
        "14fc0fa" => "Add filepath completions"
      }
    end
    let(:indent) { "  " }

    before do
      allow(Igitsh::Git).to receive(:command_names).and_return(%w[diff])
      allow(Igitsh::Git).to receive(:command_set).and_return(Set["diff"])
      allow(Igitsh::Git).to receive(:command_descriptions).and_call_original
      allow(Igitsh::Git).to receive(:raw_command_descriptions).and_call_original
      allow(Igitsh::Git).to receive(:commit_hash_to_title).and_return(commit_info)
    end

    context "with Git command" do
      it "returns command hints for 40 char width" do
        command_hints = Igitsh::Git.command_descriptions.keys.sort.to_h do |command|
          [command, described_class.from_completion(command, width: 40)]
        end

        expect(command_hints).to match_snapshot("wide_command_hints")
      end

      it "returns command hints for 10 char width" do
        command_hints = Igitsh::Git.command_descriptions.keys.sort.to_h do |command|
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
        command_hints = Igitsh::Commander.internal_command_names.sort.to_h do |command|
          [command, described_class.from_completion(command, width: 25)]
        end

        expect(command_hints).to match_snapshot("internal_command_hints")
      end
    end

    context "with commit hash" do
      it "returns commit title hints", :aggregate_failures do
        commit_info.each do |hash, title|
          expect(described_class.from_completion(hash, width: 40)).to eq([indent + title])
        end
      end
    end

    context "without hints" do
      it "returns no hints" do
        expect(described_class.from_completion("not_completable", width: 25)).to be_empty
      end
    end
  end
end
