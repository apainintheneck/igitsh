# Gitsh

This is a shell for Git that facilitates common actions by including shell completions for command names, shell history and removes the need to preface each command with the word `git`.

I originally started this as an [awk script](https://gist.github.com/apainintheneck/ddc87043a645e87f2d9e02b69be155b6). Then, I tried to implement it in a [crystal program](https://github.com/apainintheneck/gitsh-cr) and now I've implemented it in Ruby.

## Installation

```console
$ bundle install
$ bundle rake install
```

## Usage

```console
$ gitsh
```

## Development

```console
# Linting
$ bundle exec rake standard

# Testing
$ bundle exec rake spec

# Linting & Testing
$ bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/apainintheneck/gitsh.

## Related Projects

- Gitsh: An interactive shell for git
    - Repo: https://github.com/thoughtbot/gitsh
    - Language: Ruby
    - Last Updated: December 16, 2019
- Gitsh: lame git wrapper tool that tries to make git act like a shell - highly unstable, prickly, experimental, and all-around bad.
    - Repo: https://github.com/belden/gitsh
    - Language: Perl
    - Last Updated: March 3, 2015
- Gitsh: A simple git shell
    - Repo: https://github.com/caglar/gitsh
    - Language: Perl
    - Last Updated: September 26, 2011

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
