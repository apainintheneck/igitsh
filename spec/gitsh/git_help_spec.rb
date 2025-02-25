# frozen_string_literal: true

RSpec.describe Gitsh::GitHelp do
  subject(:help_page) { described_class.from_name("diff") }

  before do
    allow(Gitsh::Git).to receive(:command_names).and_return(%w[diff])
    allow(Gitsh::Git).to receive(:command_set).and_return(Set["diff"])
    allow(Gitsh::Git).to receive(:help_page).with(command: "diff")
      .and_return(fixture("git_diff_help_page.txt"))
  end

  describe ".for" do
    it "returns nil for invalid command" do
      expect(described_class.from_name("dance")).to be_nil
    end

    it "returns instance of itself when command is valid" do
      expect(described_class.from_name("diff")).to be_a(Gitsh::GitHelp)
    end
  end

  describe "#option_prefixes" do
    it "should include expected prefixes" do
      expect(help_page.option_prefixes.sort)
        .to match_snapshot("git_diff_option_prefixes")
    end
  end

  describe "#options" do
    it "should include all options" do
      expect(help_page.options).to match_snapshot("git_diff_all_options")
    end
  end
end
