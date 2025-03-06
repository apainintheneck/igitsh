# frozen_string_literal: true

require "rainbow"

RSpec.describe Gitsh::Prompt, :without_git do
  let(:gitsh) { Rainbow("gitsh").color(:aqua) }
  let(:branch) { Rainbow("main").color(:mediumslateblue) }
  let(:check) { Rainbow("✔").color(:green) }
  let(:staged) { Rainbow("●2").color(:yellowgreen) }
  let(:unstaged) { Rainbow("+1").color(:blue) }
  let(:success) { 0 }
  let(:failure) { 127 }
  let(:exit_code) { Rainbow("[127]").color(:crimson) }

  before do
    %i[current_branch uncommitted_changes repo?].each do |method|
      allow(Gitsh::Git).to receive(method).and_call_original
    end
  end

  describe ".string" do
    context "with zero exit code" do
      context "with git repo", :in_git_repo do
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
            Gitsh::Test.quiet_system("git add file1 file2")

            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged})> ").bold
          end
        end

        context "with 1 unstaged change" do
          it "returns expected prompt" do
            # Commit one file
            FileUtils.touch "file1"
            Gitsh::Test.quiet_system("git add file1")
            Gitsh::Test.quiet_system("git commit -m 'first'")
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
            Gitsh::Test.quiet_system("git add file1 file2")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: success))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged}#{unstaged})> ").bold
          end
        end
      end

      context "without git repo", :in_temp_dir do
        it "returns default prompt string" do
          expect(described_class.string(exit_code: success))
            .to eq Rainbow("#{gitsh}> ").bold
        end
      end
    end

    context "with non-zero exit code" do
      context "with git repo", :in_git_repo do
        context "with no changes" do
          it "returns expected prompt", :aggregate_failures do
            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{check})#{exit_code}> ").bold

            stub_const("Gitsh::USE_COLOR", false)

            expect(described_class.string(exit_code: failure))
              .to eq "gitsh(main|✔)[127]> "
          end
        end

        context "with 2 staged changes" do
          it "returns expected prompt", :aggregate_failures do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            Gitsh::Test.quiet_system("git add file1 file2")

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged})#{exit_code}> ").bold

            stub_const("Gitsh::USE_COLOR", false)

            expect(described_class.string(exit_code: failure))
              .to eq "gitsh(main|●2)[127]> "
          end
        end

        context "with 1 unstaged change" do
          it "returns expected prompt", :aggregate_failures do
            # Commit one file
            FileUtils.touch "file1"
            Gitsh::Test.quiet_system("git add file1")
            Gitsh::Test.quiet_system("git commit -m 'first'")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{unstaged})#{exit_code}> ").bold

            stub_const("Gitsh::USE_COLOR", false)

            expect(described_class.string(exit_code: failure))
              .to eq "gitsh(main|+1)[127]> "
          end
        end

        context "with 2 staged changes and 1 unstaged change" do
          it "returns expected prompt", :aggregate_failures do
            # Two staged file changes
            FileUtils.touch "file1"
            FileUtils.touch "file2"
            Gitsh::Test.quiet_system("git add file1 file2")
            # One unstaged file change
            File.write "file1", "text"

            expect(described_class.string(exit_code: failure))
              .to eq Rainbow("#{gitsh}(#{branch}|#{staged}#{unstaged})#{exit_code}> ").bold

            stub_const("Gitsh::USE_COLOR", false)

            expect(described_class.string(exit_code: failure))
              .to eq "gitsh(main|●2+1)[127]> "
          end
        end
      end

      context "without git repo", :in_temp_dir do
        it "returns default prompt string", :aggregate_failures do
          expect(described_class.string(exit_code: failure))
            .to eq Rainbow("#{gitsh}#{exit_code}> ").bold

          stub_const("Gitsh::USE_COLOR", false)

          expect(described_class.string(exit_code: failure))
            .to eq "gitsh[127]> "
        end
      end
    end
  end
end
