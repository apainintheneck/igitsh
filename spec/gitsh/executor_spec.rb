# frozen_string_literal: true

require "tempfile"
require "rainbow"

RSpec.describe Gitsh::Executor do
  let!(:out) { Tempfile.new }
  let!(:err) { Tempfile.new }

  let(:out_str) { out.tap(&:rewind).read }
  let(:err_str) { err.tap(&:rewind).read }

  let(:error) { Rainbow("error>").blue.bold }

  around do |example|
    example.run
  ensure
    out.close
    out.unlink

    err.close
    err.unlink
  end

  describe ".execute_line" do
    #
    # Success
    #
    context "with a single command" do
      it "executes a command without a git prefix" do
        expect(described_class.execute_line(line: "help", out: out, err: err))
          .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

        expect(out_str).to start_with("usage: git")
        expect(err.size).to eq(0)
      end

      it "executes an unknown command and returns a non-zero exit code" do
        expect(described_class.execute_line(line: "not-a-git-command", out: out, err: err))
          .to eq(Gitsh::Executor::Result::Success.new(exit_code: 1))

        expect(out.size).to eq(0)
        expect(err_str).to eq("git: 'not-a-git-command' is not a git command. See 'git --help'.\n")
      end
    end

    context "with two commands" do
      context "with '&&'" do
        it "executes the second command when the first succeeds" do
          expect(described_class.execute_line(line: "help && unknown command", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 1))

          expect(out_str).to start_with("usage: git")
          expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
        end

        it "skips the second command when the first fails" do
          expect(described_class.execute_line(line: "unknown command && help", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 1))

          expect(out.size).to eq(0)
          expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
        end
      end

      context "with '||'" do
        it "skips the second command when the first succeeds" do
          expect(described_class.execute_line(line: "help || unknown command", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

          expect(out_str).to start_with("usage: git")
          expect(err.size).to eq(0)
        end

        it "executes the second command when the first fails" do
          expect(described_class.execute_line(line: "unknown command || help", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

          expect(out_str).to start_with("usage: git")
          expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
        end
      end

      context "with semicolon" do
        it "executes the second command when the first succeeds" do
          expect(described_class.execute_line(line: "help; unknown command", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 1))

          expect(out_str).to start_with("usage: git")
          expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
        end

        it "executes the second command when the first fails" do
          expect(described_class.execute_line(line: "unknown command; help", out: out, err: err))
            .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

          expect(out_str).to start_with("usage: git")
          expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
        end
      end
    end

    context "with changed commands" do
      it "when it succeeds it skips everything after || until ;" do
        line = "help || help || help && help; unknown command"

        expect(described_class.execute_line(line: line, out: out, err: err))
          .to eq(Gitsh::Executor::Result::Success.new(exit_code: 1))

        expect(out_str.scan("usage: git").size).to eq(1)
        expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
      end

      it "when it fails it skips everything after && until ||" do
        line = "unknown command && help && help || version && help; version"

        expect(described_class.execute_line(line: line, out: out, err: err))
          .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

        expect(out_str.scan("usage: git").size).to eq(1)
        expect(out_str.scan("git version").size).to eq(2)
        expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
      end

      it "when it fails it skips everything after && until ;" do
        line = "unknown && version && version && version; version"

        expect(described_class.execute_line(line: line, out: out, err: err))
          .to eq(Gitsh::Executor::Result::Success.new(exit_code: 0))

        expect(out_str.scan("git version").size).to eq(1)
        expect(err_str).to eq("git: 'unknown' is not a git command. See 'git --help'.\n")
      end
    end

    #
    # Exit
    #
    it "exits successfully" do
      expect do
        described_class.execute_line(line: ":exit", out: out, err: err)
      end.to raise_error(Gitsh::ExitError)
    end

    #
    # Failure
    #
    it "fails when there is an unterminated single-quoted string" do
      expect(described_class.execute_line(line: "first second 'third fourth", out: out, err: err))
        .to eq(Gitsh::Executor::Result::Failure.new(exit_code: 127))

      expect(out.size).to eq(0)
      expect(err_str).to eq <<~ERROR
        | #{error} unterminated string
        |
        | first second 'third fourth
        |              ^^^^^^^^^^^^^
      ERROR
    end

    it "fails when there is an unterminated double-quoted string" do
      expect(described_class.execute_line(line: "first second \"third fourth", out: out, err: err))
        .to eq(Gitsh::Executor::Result::Failure.new(exit_code: 127))

      expect(out.size).to eq(0)
      expect(err_str).to eq <<~ERROR
        | #{error} unterminated string
        |
        | first second "third fourth
        |              ^^^^^^^^^^^^^
      ERROR
    end

    it "fails when there is a partial action" do
      expect(described_class.execute_line(line: "git clone sdlkfdjsf&sdfklsdfjsd", out: out, err: err))
        .to eq(Gitsh::Executor::Result::Failure.new(exit_code: 127))

      expect(out.size).to eq(0)
      expect(err_str).to eq <<~ERROR
        | #{error} expected '&&' but got '&' instead
        |
        | git clone sdlkfdjsf&sdfklsdfjsd
        |                    ^
      ERROR
    end

    it "fails when there is a parse error" do
      expect(described_class.execute_line(line: "first && && fourth", out: out, err: err))
        .to eq(Gitsh::Executor::Result::Failure.new(exit_code: 127))

      expect(out.size).to eq(0)
      expect(err_str).to eq <<~ERROR
        | #{error} expected a string after '&&' but got '&&' instead
        |
        | first && && fourth
        |          ^^
      ERROR
    end
  end
end
