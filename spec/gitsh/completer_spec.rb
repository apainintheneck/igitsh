# frozen_string_literal: true

RSpec.describe Igitsh::Completer do
  let(:command_set) { %w[commit add diff restore].to_set }

  before do
    allow(Igitsh::Git).to receive(:command_set).and_return(command_set)
  end

  describe ".from_line" do
    context "for commands", :without_git do
      before do
        allow(Igitsh).to receive(:all_command_names)
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
          expect(described_class.from_line(line)).to be_nil
        end
      end
    end

    context "for options", :without_git do
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
            expect(described_class.from_line(line)).to be_nil
          end
        end
      end

      context "with internal command" do
        it "returns results when prefix matches" do
          expect(described_class.from_line(":alias --")).to match_array(%w[
            --global
            --list
            --local
          ])
        end
      end
    end

    context "with filepath completions", :in_git_repo do
      let(:files) do
        %w[
          .github/workflows/main.yml
          .rspec
          README.md
          Rakefile
          lib/main.rb
          lib/parser.rb
          lib/tokenizer.rb
          lib/transpiler.rb
        ]
      end

      before do
        Dir.mkdir("lib")
        FileUtils.mkdir_p(".github/workflows")
        FileUtils.touch(files)
        Igitsh::Test.quiet_system("git add --all")
        Igitsh::Test.quiet_system("git commit -m 'test commit'")
      end

      it "returns filepath completions", :aggregate_failures do
        {
          "add lib" => nil,
          "add Rake" => nil,
          "restore ." => nil,
          "grep /" => nil,
          "restore ./*" => nil,
          "commit ./" => %w[
            ./.github/workflows/main.yml
            ./.keep
            ./.rspec
            ./README.md
            ./Rakefile
            ./lib/main.rb
            ./lib/parser.rb
            ./lib/tokenizer.rb
            ./lib/transpiler.rb
          ],
          "ls-files ./." => %w[
            ./.github/workflows/main.yml
            ./.keep
            ./.rspec
          ],
          "./." => nil,
          "grep green ./lib/main.rb ./lib" => %w[
            ./lib/main.rb
            ./lib/parser.rb
            ./lib/tokenizer.rb
            ./lib/transpiler.rb
          ],
          "grep def && ./lib" => nil,
          "push --fast ./lib*" => nil,
          "command ./lib/t" => %w[
            ./lib/tokenizer.rb
            ./lib/transpiler.rb
          ],
          "add --all && commit ./.github/workflows/" => %w[
            ./.github/workflows/main.yml
          ],
          "rebase ./R" => %w[
            ./README.md
            ./Rakefile
          ],
          "blame -v ./README." => %w[
            ./README.md
          ]
        }.each do |line, completions|
          expect(described_class.from_line(line)).to eq(completions)
        end
      end
    end

    context "for custom", :in_git_repo do
      RSpec.shared_context "uncommitted files", :in_git_repo do
        before do
          FileUtils.touch(%w[staged_1.rb staged_2.rb unstaged_1.rb unstaged_2.rb])
          Igitsh::Test.quiet_system("git add staged_1.rb staged_2.rb")
        end
      end

      context "with branch name completions" do
        let(:commands) { %w[checkout diff merge rebase switch] }

        before do
          %w[fix release test].each do |branch_name|
            Igitsh::Test.quiet_system("git branch -c #{branch_name}")
          end
        end

        it "includes all branches without a prefix", :aggregate_failures do
          commands.each do |command|
            expect(described_class.from_line("#{command}  "))
              .to eq(%w[fix release test])
          end

          commands.each do |command|
            expect(described_class.from_line(" #{command} -v "))
              .to eq(%w[fix release test])
          end
        end

        it "includes matching branches by prefix", :aggregate_failures do
          commands.each do |command|
            expect(described_class.from_line("#{command}  re")).to eq(%w[release])
          end

          commands.each do |command|
            expect(described_class.from_line(" #{command} -v re")).to eq(%w[release])
          end
        end
      end

      context "with staged file completions" do
        include_context "uncommitted files"

        it "includes all staged files without a prefix", :aggregate_failures do
          ["restore -v -S  ", "restore --staged "].each do |command|
            expect(described_class.from_line(command)).to eq(%w[staged_1.rb staged_2.rb])
          end
        end

        it "includes matching staged files by prefix", :aggregate_failures do
          ["restore -v -S  staged_2", "restore --staged staged_2"].each do |command|
            expect(described_class.from_line(command)).to eq(%w[staged_2.rb])
          end
        end
      end

      context "with unstaged file completions" do
        include_context "uncommitted files"

        let(:commands) { %w[add restore] }

        it "includes all unstaged files without a prefix", :aggregate_failures do
          commands.each do |command|
            expect(described_class.from_line("#{command}   ")).to eq(%w[unstaged_1.rb unstaged_2.rb])
          end

          commands.each do |command|
            expect(described_class.from_line("#{command} -d ")).to eq(%w[unstaged_1.rb unstaged_2.rb])
          end
        end

        it "includes matching unstaged files by prefix", :aggregate_failures do
          commands.each do |command|
            expect(described_class.from_line("#{command}  unstaged_1")).to eq(%w[unstaged_1.rb])
          end

          commands.each do |command|
            expect(described_class.from_line(" #{command} -v unstaged_1.")).to eq(%w[unstaged_1.rb])
          end
        end
      end
    end
  end
end
