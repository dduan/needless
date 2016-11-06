# Omit Needless Words #

To promote clear usage, the Swift API Design Guidelines advice that we [omit
needless words][omit needless words] in function names. Words that *merely
repeat* type information are specifically identified as needless.

This is a tool that helps you spot those words in your code base.

## Install ##

Prerequisite: have Swift 3 installed on your system.

1. Clone or download content of this repository.
2. run `make`.

## Usage ##

### Basic ###

The command `needless` can process text from STDIN or files specified in a list of
paths. The simplest way to use it is one of the following:

```
needless path/to/file1.swift path/to/file2.swift
```
```
echo "func someName(foo bar: Baz..." | needless
```

`needless` will print out function names with needless words and suggest an
alternative.

Run `needless -h` for more details, or read the next section.

### Options ###

Several output formats are included for different use scenarios. They make this
command more useful when combined with other scripts/tools.

* By default, `needless` prints output in a readable format:

    ```
    potential needless words in first parameter label in path/to/file.swift (line 87)
        private func buttonTitleColor(forType type: NewsfeedItemType) -> UIColor {
                ^
    possible alternative: func buttonTitleColor(for type: NewsfeedItemType …
    ```

* Use the option `-Xcode` for `clang`/`swiftc` style warning:

    ```
    needless -Xcode path/to/file.swift
    ```
    ```
    path/to/file.swift:23:5: warning: potential needless words in function name 'func testWithData(_ data: Data …'; perhaps use 'func test(with data: Data …' instead?
    ```

  This means you can add `needless` as a build phase in Xcode to get inline
  highlighting.

  ![needless in Xcode](https://cloud.githubusercontent.com/assets/75067/19623971/d2e30a82-9896-11e6-899d-4b899f9e66d2.png)

  1. add a "Run Script" build phase in your Xcode project and paste in the
     following:

     ```
     needless -dollar path/to/file.swift
     ```
     ```
     IFS=$'\n' find . -name "*.swift" -exec needless -Xcode {} \;
     ```

     (customize the command according to your needs. e.g. you may want to
     change the path `.` to `Sources` to avoid warnings for files in `Packages`
     or `Pods` folder).
  2. build your Xcode project.

* `-dollar` prints results in `$`-separated strings:

    ```
    needless -dollar path/to/file.swift
    ```
    ```
    potential needless words in function name$path/to/file.swift$22$4$func testWithData(_ data: Data$func test(with data: Data
    ```

  That's `[description]$[path]$[line number]$[column number]$[original name]$[suggested name]`

  This format is convenient for parsing and further actions. It's trivial to
  read it and do automated replacement, for example.

* `-diff` will make `needless` only process lines that begin with character
  `+`, `!` or `>`. This is handy when you are dealing with patch formats. Make
  `needless` part of your [git hooks][git hooks]!

  `-diff` can be combined with `-dollar` and `-Xcode`.

## Not a robot ##

The API guideline starts with "every word in a name should convey salient
information at the use site". `needless` isn't AI with advanced natural
language processing capabilities (yet?). In fact, it assumes you use camelCase
in function names and merely tries to find problematic function names in a very
mechanical (dumb) way. Its suggestions are often awkward/too aggressive. Always
prioritize good human judgement please :)

[omit needless words]: https://swift.org/documentation/api-design-guidelines/#omit-needless-words
[git hooks]: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks
