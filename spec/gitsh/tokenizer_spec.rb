# frozen_string_literal: true

RSpec.describe Gitsh::Tokenizer do
  describe ".tokenize" do
    it "tokenizes blanks lines" do
      ["", "   ", "\t", "\n", "  \t \n"].each do |line|
        expect(described_class.tokenize(line)).to be_empty
      end
    end

    it "tokenizes commands without arguments", :aggregate_failures do
      %w[diff log branch commit].each do |line|
        expect(described_class.tokenize(line)).to eq([
          Gitsh::Token::String.new(content: line, start_position: 0, end_position: line.size - 1)
        ])
      end
    end

    it "tokenizes single-quoted strings", :aggregate_failures do
      [
        [
          %(grep 'type : Tokenizer'),
          [
            Gitsh::Token::String.new(content: "grep", start_position: 0, end_position: 3),
            Gitsh::Token::String.new(content: "type : Tokenizer", start_position: 5, end_position: 22)
          ]
        ],
        [
          %(grep 'describe ".tokenize" do'  ),
          [
            Gitsh::Token::String.new(content: "grep", start_position: 0, end_position: 3),
            Gitsh::Token::String.new(content: "describe \".tokenize\" do", start_position: 5, end_position: 29)
          ]
        ],
        [
          %(add -- '*.js'),
          [
            Gitsh::Token::String.new(content: "add", start_position: 0, end_position: 2),
            Gitsh::Token::String.new(content: "--", start_position: 4, end_position: 5),
            Gitsh::Token::String.new(content: "*.js", start_position: 7, end_position: 12)
          ]
        ],
        [
          %( log --committer='Lawrence Kraft'),
          [
            Gitsh::Token::String.new(content: "log", start_position: 1, end_position: 3),
            Gitsh::Token::String.new(content: "--committer=Lawrence Kraft", start_position: 5, end_position: 32)
          ]
        ]
      ].each do |line, tokens|
        expect(described_class.tokenize(line)).to eq(tokens)
      end
    end

    it "tokenizes double-quoted strings", :aggregate_failures do
      [
        [
          %(grep   " type : Tokenizer"),
          [
            Gitsh::Token::String.new(content: "grep", start_position: 0, end_position: 3),
            Gitsh::Token::String.new(content: " type : Tokenizer", start_position: 7, end_position: 25)
          ]
        ],
        [
          %(log   --grep   "'exit' or 'quit'"),
          [
            Gitsh::Token::String.new(content: "log", start_position: 0, end_position: 2),
            Gitsh::Token::String.new(content: "--grep", start_position: 6, end_position: 11),
            Gitsh::Token::String.new(content: "'exit' or 'quit'", start_position: 15, end_position: 32)
          ]
        ],
        [
          %(  add -- "*.js"),
          [
            Gitsh::Token::String.new(content: "add", start_position: 2, end_position: 4),
            Gitsh::Token::String.new(content: "--", start_position: 6, end_position: 7),
            Gitsh::Token::String.new(content: "*.js", start_position: 9, end_position: 14)
          ]
        ],
        [
          %(log --author="One Punch Man"),
          [
            Gitsh::Token::String.new(content: "log", start_position: 0, end_position: 2),
            Gitsh::Token::String.new(content: "--author=One Punch Man", start_position: 4, end_position: 27)
          ]
        ]
      ].each do |line, tokens|
        expect(described_class.tokenize(line)).to eq(tokens)
      end
    end

    it "raises a syntax error when a matching closing quote is missing", :aggregate_failures do
      [
        %(grep "skdfsdklfj),
        %(commit -m 'slkdfjsdklfjds),
        %(log --author="sdkfsdlkj'dsfkjds'),
        %(branch -D 'sdkfsdlkj"dsfkjds")
      ].each do |line|
        expect { described_class.tokenize(line) }
          .to raise_error(Gitsh::SyntaxError, /Missing matching (?:single|double)-quote/)
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
          tokens = described_class.tokenize(line)

          expect(tokens.map(&:class)).to eq([Gitsh::Token::String, klass, Gitsh::Token::String])
          expect(tokens.map(&:content)).to eq(["first", action, "second"])
        end
      end
    end

    context "with '&&'" do
      let(:action) { "&&" }
      let(:klass) { Gitsh::Token::And }

      include_examples "tokenize with action"
    end

    context "with '||'" do
      let(:action) { "||" }
      let(:klass) { Gitsh::Token::Or }

      include_examples "tokenize with action"
    end

    context "with ';'" do
      let(:action) { ";" }
      let(:klass) { Gitsh::Token::End }

      include_examples "tokenize with action"
    end

    it "tokenizes strings with multiple actions", :aggregate_failures do
      [
        [
          "one && two; three || four",
          [
            Gitsh::Token::String.new(content: "one", start_position: 0, end_position: 2),
            Gitsh::Token::And.new(content: "&&", start_position: 4, end_position: 5),
            Gitsh::Token::String.new(content: "two", start_position: 7, end_position: 9),
            Gitsh::Token::End.new(content: ";", start_position: 10, end_position: 10),
            Gitsh::Token::String.new(content: "three", start_position: 12, end_position: 16),
            Gitsh::Token::Or.new(content: "||", start_position: 18, end_position: 19),
            Gitsh::Token::String.new(content: "four", start_position: 21, end_position: 24)
          ]
        ],
        [
          "&&   &&&&;||",
          [
            Gitsh::Token::And.new(content: "&&", start_position: 0, end_position: 1),
            Gitsh::Token::And.new(content: "&&", start_position: 5, end_position: 6),
            Gitsh::Token::And.new(content: "&&", start_position: 7, end_position: 8),
            Gitsh::Token::End.new(content: ";", start_position: 9, end_position: 9),
            Gitsh::Token::Or.new(content: "||", start_position: 10, end_position: 11)
          ]
        ]
      ].each do |line, tokens|
        expect(described_class.tokenize(line)).to eq(tokens)
      end
    end
  end
end
