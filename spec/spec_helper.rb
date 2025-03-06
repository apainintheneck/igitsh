# frozen_string_literal: true

# Make sure that tests run with color by default.
ENV.delete("NO_COLOR")

require "gitsh"
require "fileutils"
require "prop_check"
require "rspec/snapshot"
require "yaml"
require "pathname"
require "set"

module Gitsh
  module Test
    # To prevent flakiness when calling methods unexpectedly in tests.
    class Error < StandardError; end

    # For the snapshot testing library.
    class YAMLSerializer
      def dump(object)
        YAML.dump(object)
      end
    end

    # @param command [String]
    def self.quiet_system(command)
      system(command, out: File::NULL, err: File::NULL)
    end

    # @yield inside temporary directory
    def self.in_temp_dir
      old_dir = Dir.pwd

      Dir.mktmpdir do |new_dir|
        Dir.chdir(new_dir)

        yield
      end
    ensure
      Dir.chdir(old_dir)
    end
  end
end

# Copied from `Library/Homebrew/dev-cmd/tests.rb`.
# This prevents git repo set up errors.
%w[AUTHOR COMMITTER].each do |role|
  ENV["GIT_#{role}_NAME"] = "gitsh tests"
  ENV["GIT_#{role}_EMAIL"] = "gitsh-tests@localhost"
  ENV["GIT_#{role}_DATE"] = "Sun Jan 22 19:59:13 2017 +0000"
end

# Setup fixture directory helper.
SPEC_DIR = Pathname(__dir__).expand_path.freeze
FIXTURE_DIR = (SPEC_DIR / "fixtures").freeze

# @param filename [String] located in the `spec/fixtures` directory.
#
# @return [String] file contents
def fixture(filename)
  @fixture ||= {}
  @fixture[filename] ||= File.read FIXTURE_DIR / filename
end

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  # https://rspec.info/features/3-12/rspec-core/configuration/zero-monkey-patching-mode/
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = "doc"
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  # The default setting is `:relative`, which means snapshot files will be
  # created in a '__snapshots__' directory adjacent to the spec file where the
  # matcher is used.
  #
  # Set this value to put all snapshots in a fixed directory
  config.snapshot_dir = "spec/fixtures/snapshots"

  # Defaults to using the awesome_print gem to serialize values for snapshots
  #
  # Set this value to use a custom snapshot serializer
  config.snapshot_serializer = Gitsh::Test::YAMLSerializer

  config.before(:each, :without_git) do
    # To prevent errors where these get loaded for real and get cached by another test.
    Gitsh::Git.methods(false).each do |method|
      allow(Gitsh::Git).to receive(method) do
        raise Gitsh::Test::Error, "Unexpected call to Gitsh::Git.#{method}"
      end
    end
  end

  config.before(:each, :stub_git_help_all) do
    allow(Open3).to receive(:capture3).with("git help --all")
      .and_return(fixture("git_help_all_commands.txt"))
  end

  config.around(:each, :in_temp_dir) do |example|
    Gitsh::Test.in_temp_dir { example.run }
  end

  config.around(:each, :in_git_repo) do |example|
    Gitsh::Test.in_temp_dir do
      Gitsh::Test.quiet_system("git init")
      # Add a commit to be able to set the branch name.
      FileUtils.touch(".keep")
      Gitsh::Test.quiet_system("git add .keep && git commit -m 'init'")
      Gitsh::Test.quiet_system("git branch -m main")

      example.run
    end
  end
end
