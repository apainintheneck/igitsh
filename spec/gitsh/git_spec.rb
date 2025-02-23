# frozen_string_literal: true

RSpec.describe Gitsh::Git do
  describe ".installed?" do
    it "returns true when git exists" do
      expect(described_class.installed?).to be(true)
    end
  end

  describe ".repo?" do
    it "returns true when in a repo" do
      expect(described_class.repo?).to be(true)
    end
  end

  describe ".current_branch" do
    it "returns a branch name" do
      expect(described_class.current_branch).to be_a(String)
    end
  end

  describe ".uncommitted_changes" do
    it "returns a Changes struct" do
      expect(described_class.uncommitted_changes).to be_a(described_class::Changes)
    end
  end

  describe ".command_descriptions" do
    it "parses the command descriptions" do
      expect(described_class.command_descriptions).to match_snapshot("git_command_descriptions")
    end
  end

  describe ".help_page" do
    it "returns nil if command doesn't exist" do
      expect(described_class.help_page(command: "not-a-command")).to be_nil
    end

    it "returns help page for real command" do
      # Matching exactly would surely break with different Git versions.
      expect(described_class.help_page(command: "pull")).to include("GIT-PULL(1)")
    end
  end

  describe ".command_names" do
    it "returns an array of Git commands" do
      expect(described_class.command_names)
        .to be_an(Array)
        .and include("commit", "push", "pull", "status", "diff", "grep", "log")
    end
  end

  describe ".command_set" do
    it "returns a set of Git command" do
      expect(described_class.command_set)
        .to be_a(Set)
        .and include("commit", "push", "pull", "status", "diff", "grep", "log")
    end
  end

  describe ".run" do
    it "succeeds with a valid command" do
      exit_code = described_class.run(["help"], out: File::NULL, err: File::NULL)
      expect(exit_code).to eq(0)
    end

    it "fails with an invalid command" do
      exit_code = described_class.run(["not-a-command"], out: File::NULL, err: File::NULL)
      expect(exit_code).to eq(1)
    end
  end
end
