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
  end
end
