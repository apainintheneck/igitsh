# frozen_string_literal: true

require "rainbow"

RSpec.describe Gitsh::Prompt do
  let(:gitsh) { Rainbow("gitsh").color(:aqua) }
  let(:branch) { Rainbow("main").color(:mediumslateblue) }
  let(:check) { Rainbow("✔").color(:green) }
  let(:staged) { Rainbow("●2").color(:yellowgreen) }
  let(:unstaged) { Rainbow("+1").color(:blue) }
  let(:success) { 0 }
  let(:failure) { 127 }
  let(:exit_code) { Rainbow("[127]").color(:crimson) }

  def quiet_system(command)
    system(command, out: File::NULL, err: File::NULL)
  end

  def in_temp_dir
    old_dir = Dir.pwd

    Dir.mktmpdir do |new_dir|
      Dir.chdir(new_dir)

      yield
    end
  ensure
    Dir.chdir(old_dir)
  end

  def in_git_repo
    in_temp_dir do
      quiet_system("git init")
      # Add a commit to be able to set the branch name.
      FileUtils.touch(".keep")
      quiet_system("git add .keep && git commit -m 'init'")
      quiet_system("git branch -m main")

      yield
    end
  end

  describe ".string" do
    context "with zero exit code" do
      context "with git repo" do
        around do |example|
          in_git_repo { example.run }
        end

        context "with no changes" do
          it "returns expected prompt" do
            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{check})> ").bold
          end
        end

        context "with 2 staged changes" do
          it "returns expected prompt" do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            quiet_system("git add file1 file2")

            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged})> ").bold
          end
        end

        context "with 1 unstaged change" do
          it "returns expected prompt" do
            # Commit one file
            FileUtils.touch "file1"
            quiet_system("git add file1")
            quiet_system("git commit -m 'first'")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{unstaged})> ").bold
          end
        end

        context "with 2 staged changes and 1 unstaged change" do
          it "returns expected prompt" do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            quiet_system("git add file1 file2")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged}#{unstaged})> ").bold
          end
        end
      end

      context "without git repo" do
        around do |example|
          in_temp_dir { example.run }
        end

        it "returns default prompt string" do
          expect(described_class.string(exit_code: success))
            .to eq Rainbow("#{gitsh}> ").bold
        end
      end
    end

    context "with non-zero exit code" do
      context "with git repo" do
        around do |example|
          in_git_repo { example.run }
        end

        context "with no changes" do
          it "returns expected prompt" do
            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{check})#{exit_code}> ").bold
          end
        end

        context "with 2 staged changes" do
          it "returns expected prompt" do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            quiet_system("git add file1 file2")

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged})#{exit_code}> ").bold
          end
        end

        context "with 1 unstaged change" do
          it "returns expected prompt" do
            # Commit one file
            FileUtils.touch "file1"
            quiet_system("git add file1")
            quiet_system("git commit -m 'first'")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{unstaged})#{exit_code}> ").bold
          end
        end

        context "with 2 staged changes and 1 unstaged change" do
          it "returns expected prompt" do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            quiet_system("git add file1 file2")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged}#{unstaged})#{exit_code}> ").bold
          end
        end
      end

      context "without git repo" do
        around do |example|
          in_temp_dir { example.run }
        end

        it "returns default prompt string" do
          expect(described_class.string(exit_code: failure))
            .to eq Rainbow("#{gitsh}#{exit_code}> ").bold
        end
      end
    end
  end
end
