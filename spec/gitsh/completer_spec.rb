# frozen_string_literal: true

RSpec.describe Gitsh::Completer do
  describe ".from_line" do
    context "for commands" do
      before do
        allow(Gitsh).to receive(:all_command_names)
          .and_return(%w[commit commit-tree commit-graph])
      end

      it "returns all commands for shared prefix", :aggregate_failures do
        ["comm", "add README.md && comm"].each do |line|
          expect(described_class.from_line(line))
            .to match_array(%w[commit commit-tree commit-graph])
        end
      end

      it "includes commands that exactly match" do
        ["commit", "add README.md || commit"].each do |line|
          expect(described_class.from_line(line))
            .to match_array(%w[commit commit-tree commit-graph])
        end
      end

      it "excludes commands that no longer match" do
        ["commit-", "add README.md; commit-"].each do |line|
          expect(described_class.from_line(line))
            .to match_array(%w[commit-tree commit-graph])
        end
      end

      it "returns no results when prefix doesn't match" do
        ["smile", "add README.md && smile"].each do |line|
          expect(described_class.from_line(line)).to be_empty
        end
      end
    end

    context "for options" do
      before do
        allow(Gitsh).to receive(:all_command_names).and_return(%w[diff])
        allow(Gitsh::Git).to receive(:help_page).with(command: "diff")
          .and_return(fixture("git_diff_help_page.txt"))
      end

      context "with Git command" do
        it "completes short options" do
          ["diff -s", "restore README.md; diff -s"].each do |line|
            expect(described_class.from_line(line)).to eq(%w[-s])
          end
        end

        it "returns all options with matching prefix" do
          ["diff --out", "restore README.md; diff --out"].each do |line|
            expect(described_class.from_line(line)).to match_array(%w[
              --output
              --output-indicator-new
              --output-indicator-old
              --output-indicator-context
            ])
          end
        end

        it "includes options that exactly match" do
          ["diff --output", "restore README.md; diff --output"].each do |line|
            expect(described_class.from_line(line)).to match_array(%w[
              --output
              --output-indicator-new
              --output-indicator-old
              --output-indicator-context
            ])
          end
        end

        it "excludes options that no longer match" do
          ["diff --output-indi", "restore README.md; diff --output-indic"].each do |line|
            expect(described_class.from_line(line)).to match_array(%w[
              --output-indicator-new
              --output-indicator-old
              --output-indicator-context
            ])
          end
        end

        it "returns no results when the prefix doesn't match" do
          ["diff --input", "restore README.md; diff --input"].each do |line|
            expect(described_class.from_line(line)).to be_empty
          end
        end
      end

      context "with internal command" do
        it "returns results when prefix matches" do
          expect(described_class.from_line(":alias --")).to match_array(%w[
            --global
            --local
          ])
        end
      end
    end
  end
end
