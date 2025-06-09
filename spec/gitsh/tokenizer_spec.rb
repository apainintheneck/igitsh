# frozen_string_literal: true

RSpec.describe Igitsh::Tokenizer, :without_git do
  def expect_tokenized_lines(lines)
    tokenized_lines = Array(lines).map do |line|
      {
        line: line,
        tokens: described_class.from_line(line)
      }
    end

    expect(tokenized_lines)
  end

  describe ".from_line" do
    it "tokenizes blanks lines" do
      ["", "   ", "\t", "\n", "  \t \n"].each do |line|
        expect(described_class.from_line(line)).to be_empty
      end
    end

    it "tokenizes commands without arguments" do |example|
      expect_tokenized_lines(%w[diff log branch commit cherry-pick])
        .to match_snapshot(example.description.tr(" ", "_"))
    end

    it "tokenizes single-quoted strings" do |example|
      expect_tokenized_lines([
        %(grep 'type : Tokenizer'),
        %(grep 'describe ".from_line" do'  ),
        %(add -- '*.js'),
        %( log --committer='Lawrence Kraft'),
        %(commit -m 'Quote \\' of some time')
      ]).to match_snapshot(example.description.tr(" ", "_"))
    end

    it "tokenizes double-quoted strings" do |example|
      expect_tokenized_lines([
        %(grep   " type : Tokenizer"),
        %(log   --grep   "'exit' or 'quit'"),
        %(  add -- "*.js"),
        %(log --author="One Punch Man"),
        %(commit -m "Quote \\" of all time")
      ]).to match_snapshot(example.description.tr(" ", "_"))
    end

    it "parses unterminated strings", :aggregate_failures do
      [
        %(grep "skdfsdklfj),
        %(commit -m 'slkdfjsdklfjds),
        %(log --author="sdkfsdlkj'dsfkjds'),
        %(branch -D 'sdkfsdlkj"dsfkjds"),
        %(checkout -b 'skldfjsd\\'skdlfjsdkf),
        %(commit -m "sdfjsdfsdf\\"sdk  djf)
      ].each do |line|
        expect(described_class.from_line(line).last)
          .to be_an_unterminated_string_token
      end
    end

    it "parses unterminated strings", :aggregate_failures do
      [
        %(grep skdfs&dklfj),
        %(commit -m 'slkdfjsdklfjds' &&& git status),
        %(|log --author="sdkfsdlkj'dsfkjds'),
        %(branch -D sdkfsdlk|jdsfkjds),
        %(checkout -b skdlfjsdkf|)
      ].each do |line|
        expect(described_class.from_line(line).tokens)
          .to include(Igitsh::Token::PartialAction)
      end
    end

    shared_examples "tokenize with action" do
      it "tokenizes lines with action", :aggregate_failures do
        [
          "first #{action} second",
          "first#{action} second",
          "first #{action}second",
          "first#{action}second"
        ].each do |line|
          zipper = described_class.from_line(line)

          expect(zipper.tokens.map(&:class)).to eq([Igitsh::Token::String, klass, Igitsh::Token::String])
          expect(zipper.tokens.map(&:content)).to eq(["first", action, "second"])
        end
      end
    end

    context "with '&&'" do
      let(:action) { "&&" }
      let(:klass) { Igitsh::Token::And }

      include_examples "tokenize with action"
    end

    context "with '||'" do
      let(:action) { "||" }
      let(:klass) { Igitsh::Token::Or }

      include_examples "tokenize with action"
    end

    context "with ';'" do
      let(:action) { ";" }
      let(:klass) { Igitsh::Token::End }

      include_examples "tokenize with action"
    end

    it "tokenizes strings with multiple actions" do |example|
      expect_tokenized_lines([
        "one && two; three || four",
        "&&   &&&&;||",
        "one two &&||||; three four ;;"
      ]).to match_snapshot(example.description.tr(" ", "_"))
    end
  end
end
