# frozen_string_literal: true

require "rainbow"

RSpec.describe Gitsh::Hinter do
  describe ".from_completion" do
    before do
      allow(Gitsh::Git).to receive(:command_list).and_return(%w[diff])
      allow(Gitsh::Git).to receive(:command_set).and_return(Set["diff"])
    end

    context "with command" do
      it "returns the expected hint lines for existing command" do
        expect(described_class.from_completion("diff", width: 40)).to eq([
          Rainbow("  [Description]").color(:blue).bold,
          "",
          "  Show changes between commits, commit a",
          "  nd working tree, etc"
        ])
      end
    end

    context "with option" do
      before do
        allow(Reline).to receive(:line_buffer).and_return("diff --stat")
        allow(Gitsh::Git).to receive(:help_page).with(command: "diff")
          .and_return(fixture("git_diff_help_page.txt"))
      end

      it "returns the expected hint lines for valid option" do
        expect(described_class.from_completion("--stat", width: 40)).to eq([
          Rainbow("  [Usage]").color(:blue).bold,
          "",
          "  --stat[=<width>[,<name-width>[,<count>",
          "  ]]]"
        ])
      end
    end
  end
end
