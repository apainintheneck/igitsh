# frozen_string_literal: true

RSpec.describe Gitsh::Highlighter do
  # @param line [String]
  #
  # @return [String] highlighted string
  def highlight(line)
    tokens = Gitsh::Tokenizer.tokenize(line)
    Gitsh::Highlighter.from_tokens(tokens)
  end

  before do
    allow(Gitsh).to receive(:all_commands).and_return(%w[push pull commit])
  end

  describe ".from_tokens" do
    it "colors actions green", :aggregate_failures do
      %w[&& || ;].each do |action|
        expect(highlight(action))
          .to eq(Rainbow(action).color(:mediumspringgreen).bold)
      end
    end

    it "colors partial actions orange", :aggregate_failures do
      %w[& |].each do |partial_action|
        expect(highlight(partial_action))
          .to eq(Rainbow(partial_action).color(:orange).bold)
      end
    end

    it "colors unterminated string yellow with red quote", :aggregate_failures do
      quotes = %w[' "]
      strings = ["string", "command &&"]
      quotes.product(strings).each do |quote, string|
        expect(highlight(quote + string)).to eq(
          Rainbow(Rainbow(quote).color(:crimson) + Rainbow(string).color(:greenyellow)).bold
        )
      end
    end

    it "colors valid commands blue", :aggregate_failures do
      %w[push pull commit].each do |valid_command|
        expect(highlight(valid_command))
          .to eq(Rainbow(valid_command).color(:aqua).bold)
      end
    end

    it "colors invalid commands red", :aggregate_failures do
      %w[pus pulll comit].each do |invalid_command|
        expect(highlight(invalid_command))
          .to eq(Rainbow(invalid_command).color(:crimson).bold)
      end
    end

    it "colors quoted string yellow", :aggregate_failures do
      quotes = %w[' "]
      strings = ["string", "string &&; sdlfkjsd ||"]
      quotes.product(strings).each do |quote, string|
        quoted_string = quote + string + quote
        command_with_quoted_string = "cmd #{quoted_string}"
        expect(highlight(command_with_quoted_string))
          .to end_with(Rainbow(quoted_string).color(:yellowgreen).bold)
      end
    end

    it "colors unquoted string purple", :aggregate_failures do
      %w[string_one string.two].each do |string|
        command_with_string = "cmd #{string}"
        expect(highlight(command_with_string))
          .to end_with(Rainbow(string).color(:mediumslateblue).bold)
      end
    end
  end
end
