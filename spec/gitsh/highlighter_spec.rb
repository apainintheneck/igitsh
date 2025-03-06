# frozen_string_literal: true

RSpec.describe Gitsh::Highlighter, :without_git do
  let(:command_set) { %w[push pull commit diff].to_set }
  let(:aliases) { Gitsh::Git::Aliases.new(local: {}.freeze, global: {}.freeze).freeze }

  before do
    allow(Gitsh::Git).to receive(:command_set).and_return(command_set)
    allow(Gitsh::Git).to receive(:aliases).and_return(aliases)
    allow(Gitsh).to receive(:all_command_names)
      .and_return(%w[push pull commit grep rebase log diff exit quit])
  end

  describe ".from_tokens" do
    it "colors actions green", :aggregate_failures do
      %w[&& || ;].each do |action|
        expect(Gitsh::Highlighter.from_line(action))
          .to eq(Rainbow(action).color(:mediumspringgreen).bold)
      end
    end

    it "colors partial actions orange", :aggregate_failures do
      %w[& |].each do |partial_action|
        expect(Gitsh::Highlighter.from_line(partial_action))
          .to eq(Rainbow(partial_action).color(:orange).bold)
      end
    end

    it "colors unterminated string yellow with red quote", :aggregate_failures do
      quotes = %w[' "]
      strings = ["string", "command &&"]
      quotes.product(strings).each do |quote, string|
        expect(Gitsh::Highlighter.from_line(quote + string)).to eq(
          Rainbow(Rainbow(quote).color(:crimson) + Rainbow(string).color(:greenyellow)).bold
        )
      end
    end

    it "colors valid commands blue", :aggregate_failures do
      %w[push pull commit].each do |valid_command|
        expect(Gitsh::Highlighter.from_line(valid_command))
          .to eq(Rainbow(valid_command).color(:aqua).bold)
      end
    end

    it "colors invalid commands red", :aggregate_failures do
      %w[pus pulll comit].each do |invalid_command|
        expect(Gitsh::Highlighter.from_line(invalid_command))
          .to eq(Rainbow(invalid_command).color(:crimson).bold)
      end
    end

    it "colors quoted string yellow", :aggregate_failures do
      quotes = %w[' "]
      strings = ["string", "string &&; sdlfkjsd ||"]
      quotes.product(strings).each do |quote, string|
        quoted_string = quote + string + quote
        command_with_quoted_string = "cmd #{quoted_string}"
        expect(Gitsh::Highlighter.from_line(command_with_quoted_string))
          .to end_with(Rainbow(quoted_string).color(:yellowgreen).bold)
      end
    end

    it "colors unquoted string purple", :aggregate_failures do
      %w[string_one string.two --option-three --option=four].each do |string|
        command_with_string = "cmd #{string}"
        expect(Gitsh::Highlighter.from_line(command_with_string))
          .to end_with(Rainbow(string).color(:mediumslateblue).bold)
      end
    end

    context "with valid options" do
      before do
        allow(Gitsh::Git).to receive(:help_page).with(command: "diff")
          .and_return(fixture("git_diff_help_page.txt"))
      end

      context "with Git command" do
        it "doesn't append docs when there are no params" do
          expect(Gitsh::Highlighter.from_line("diff --raw"))
            .to end_with(Rainbow("--raw").color(:mediumslateblue).bold)
        end

        it "doesn't append docs when there are no more options" do
          expect(Gitsh::Highlighter.from_line("diff -- --stat"))
            .to end_with(Rainbow("--stat").color(:mediumslateblue).bold)
        end

        it "appends docs when there are params" do
          expect(Gitsh::Highlighter.from_line("diff --stat")).to end_with(
            Rainbow(
              Rainbow("--stat").color(:mediumslateblue) +
                Rainbow("[=<width>[,<name-width>[,<count>]]]").color(:gray)
            ).bold
          )
        end

        it "doesn't append docs when line is complete" do
          expect(Gitsh::Highlighter.from_line("diff --stat", complete: true))
            .to end_with(Rainbow("--stat").color(:mediumslateblue).bold)
        end
      end

      context "with internal command" do
        it "appends docs when there are params" do
          expect(Gitsh::Highlighter.from_line(":alias --local")).to end_with(
            Rainbow(
              Rainbow("--local").color(:mediumslateblue) +
             Rainbow(" <name> <command>").color(:gray)
            ).bold
          )
        end
      end
    end
  end
end
