# frozen_string_literal: true

RSpec.describe "property testing" do
  context "with property testing" do
    let(:line_generator) do
      gen = PropCheck::Generators

      gen_constants = %w[
        & | ; && || -- ' "
        push pull commit grep diff
        --no- --stat --max-depth --color=never
      ]
      gen_constants << " " << "  "
      gen_constants.map! { gen.constant(_1) }

      gen.array(
        gen.one_of(
          gen.alphanumeric_string(max: 10),
          gen.ascii_string(max: 10),
          gen.printable_string(max: 10),
          gen.printable_ascii_string(max: 10),
          *gen_constants
        )
      )
    end

    it "tokenizes and highlights unexpected input lines" do
      PropCheck.forall(line_generator) do |array|
        line = array.join
        expect { Gitsh::Highlighter.from_line(line) }.not_to raise_error
      end
    end

    it "tokenizes and parses unexpected input lines" do
      PropCheck.forall(line_generator) do |array|
        line = array.join
        expect do
          Gitsh::Parser.parse(line)
        rescue Gitsh::SyntaxError, Gitsh::ParseError
          # ignore expected parsing errors
        end.not_to raise_error
      end
    end

    it "tokenizes and completes unexpected input lines" do
      PropCheck.forall(line_generator) do |array|
        line = array.join
        expect { Gitsh::Completer.from_line(line) }.not_to raise_error
      end
    end
  end
end
