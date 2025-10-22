# frozen_string_literal: true

RSpec.describe Igitsh::Git do
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
      branch_name = described_class.current_branch
      expect(branch_name).to be_a(String)
      expect(branch_name).not_to be_empty
    end
  end

  describe ".uncommitted_changes" do
    it "returns a Changes struct" do
      expect(described_class.uncommitted_changes).to be_a(described_class::Changes)
    end
  end

  RSpec.shared_context "uncommitted changes", :in_git_repo do
    before do
      FileUtils.touch(%w[staged_1.rb staged_2.rb unstaged_1.rb unstaged_2.rb])
      Igitsh::Test.quiet_system("git add staged_1.rb staged_2.rb")
    end
  end

  describe ".staged_files" do
    include_context "uncommitted changes"

    it "lists staged files" do
      expect(described_class.staged_files).to eq(%w[staged_1.rb staged_2.rb])
    end
  end

  describe ".unstaged_files" do
    include_context "uncommitted changes"

    it "lists unstaged files" do
      expect(described_class.unstaged_files).to eq(%w[unstaged_1.rb unstaged_2.rb])
    end
  end

  describe ".other_branch_names", :in_git_repo do
    before do
      Igitsh::Test.quiet_system("git branch -c second")
      Igitsh::Test.quiet_system("git branch -c first")
    end

    it "returns the branch name list" do
      expect(described_class.other_branch_names).to eq(%w[first second])
    end
  end

  describe ".aliases" do
    it "returns an Aliases struct", :in_git_repo do
      described_class.set_alias(
        name: "append",
        command: "commit --amend --no-edit",
        level: "--local",
        out: File::NULL,
        err: File::NULL
      )

      aliases = described_class.aliases
      expect(aliases).to be_a(described_class::Aliases)
      expect(aliases.local).to eq({"append" => "commit --amend --no-edit"})
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
