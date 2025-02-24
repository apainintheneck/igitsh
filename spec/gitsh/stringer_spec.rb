# frozen_string_literal: true

RSpec.describe Gitsh::Stringer do
  describe ".indent_by" do
    it "indents the given string by non-negative size", :aggregate_failures do
      [
        ["zero", 0, "zero"],
        ["one", 1, " one"],
        ["three", 3, "   three"],
        ["five", 5, "     five"]
      ].each do |string, size, result|
        expect(described_class.indent_by(string, size: size)).to eq(result)
      end
    end

    it "raises argument error when size is negative" do
      expect do
        described_class.indent_by("string", size: -1)
      end.to raise_error(ArgumentError, "size must not be negative: -1")
    end
  end

  describe ".wrap_ascii" do
    it "returns empty array when size is less than 10", :aggregate_failures do
      (1..9).each do |width|
        expect(described_class.wrap_ascii("string", width: width, indent: 0)).to be_empty
      end
    end

    it "raises argument error when indent >= width", :aggregate_failures do
      [[3, 1], [4, 3], [6, 6]].each do |indent, width|
        expect do
          described_class.wrap_ascii("string", width: width, indent: indent)
        end.to raise_error(ArgumentError, "indent(#{indent}) must be less than width(#{width})")
      end
    end

    it "raises argument error when indent is negative", :aggregate_failures do
      (-9..-1).each do |indent|
        expect do
          described_class.wrap_ascii("string", width: 25, indent: indent)
        end.to raise_error(ArgumentError, "indent must not be negative: #{indent}")
      end
    end

    it "wraps words based on line width and indent" do
      expect(described_class.wrap_ascii("one two three four five six seven eight nine ten", width: 12, indent: 4)).to eq([
        "    one two",
        "    three",
        "    four",
        "    five six",
        "    seven",
        "    eight",
        "    nine ten"
      ])
    end

    it "breaks long words across lines" do
      expect(described_class.wrap_ascii("Supercalifragilisticexpialidocious", width: 10, indent: 0)).to eq([
        "Supercali-",
        "fragilist-",
        "icexpiali-",
        "docious"
      ])
    end
  end
end
