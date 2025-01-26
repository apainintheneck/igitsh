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

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
