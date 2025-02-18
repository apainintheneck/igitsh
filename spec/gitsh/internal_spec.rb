# frozen_string_literal: true

RSpec.describe Gitsh::Internal do
  describe "::COMMANDS" do
    let(:commands) { described_class::COMMANDS }

    it "is unique" do
      expect(commands).to eq(commands.uniq)
    end

    it "has commands in the expected format" do
      expect(commands).to all(match(/^:[a-z]+$/))
    end
  end
end
