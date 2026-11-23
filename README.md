# docopt.uc

A complete, specification-compliant implementation of **docopt** for the **ucode** programming language.

`ucode-docopt` helps you create beautiful command-line interfaces by describing them in a human-readable help message. You write the help message, and `ucode-docopt` handles the parsing.

---

## Tutorial: Getting Started

In this tutorial, we will create a simple CLI tool that greets a user.

### 1. Define your interface
Create a file named `greet.uc`. We start by defining a `doc` string that describes our program's usage and options.

```javascript
#!/usr/bin/env ucode
'use strict';

import { docopt } from 'docopt';

const doc = `
Greeter.

Usage:
  greet.uc <name>
  greet.uc --shout <name>
  greet.uc -h | --help

Options:
  -h --help  Show this screen.
  --shout    Greet in ALL CAPS.
`;
```

### 2. Parse the arguments
Now, call `docopt` with the `doc` string and the global `ARGV` array.

```javascript
const args = docopt(doc, ARGV);

let name = args['<name>'];
let message = `Hello, ${name}!`;

if (args['--shout']) {
    print(uc(message) + "\n");
} else {
    print(message + "\n");
}
```

### 3. Run the program
Make the script executable and run it directly:

```bash
chmod +x greet.uc

# Basic usage
./greet.uc world
# Output: Hello, world!

# Using an option
./greet.uc --shout world
# Output: HELLO, WORLD!

# Automatic help
./greet.uc --help
# Output: (Displays the help message)
```

---

## How-to Guides

### How to handle repeating arguments
When an argument or option can be repeated (using `...`), `ucode-docopt` returns an array of values.

```javascript
const doc = "Usage: prog <file>...";
const args = docopt(doc, ["file1.txt", "file2.txt"]);
// args['<file>'] will be ["file1.txt", "file2.txt"]
```

### How to use default values
You can specify default values in the `Options:` section of your doc string.

```javascript
const doc = `
Usage: prog [--speed=<kn>]

Options:
  --speed=<kn>  Speed in knots [default: 10].
`;
const args = docopt(doc, []);
// args['--speed'] will be "10"
```

---

## Reference

### `docopt(doc, argv, help=true, version=null, options_first=false)`

The main entry point for parsing.

*   **`doc`** (string): The help message/specification.
*   **`argv`** (array): The list of arguments to parse (usually `ARGV`).
*   **`help`** (boolean): If `true`, the program will automatically print the help message and exit if `-h` or `--help` is found (by the option's name: a `-h` that is `--host` is not help).
*   **`version`** (string|null): If provided, the program will print this string and exit if `--version` is found.
*   **`options_first`** (boolean): If `true`, stops parsing options after the first positional argument.

**Returns:** An object where keys are argument/option names (e.g., `<name>`, `--verbose`) and values are their parsed states (boolean, string, or array). On a usage error it prints what is wrong and the usage section to stderr and exits 1.

### `parse(doc, argv, opts)`

The same matching as `docopt()`, without printing or exiting: for a command
that sets its own exit statuses and messages (a usage error as exit 2, say),
or for testing one.

*   **`opts`** (object|null): `{ help = true, version = null, options_first = false }`, as `docopt()`'s arguments.

**Returns:** one of

*   `{ args }`: the parsed arguments, as `docopt()` returns them.
*   `{ help: true }`: `-h` or `--help` was given (and `help` is true).
*   `{ version: true }`: `--version` was given (and `version` is set).
*   `{ error, usage }`: what is wrong, such as `unknown option --foo`, `unexpected argument b` or `--speed requires argument`, and the usage section as the doc writes it (heading and indentation kept), to print to stderr.

A wrong `doc` (no usage section, two of them, an unbalanced pattern) is the program's bug, not the user's: both functions die with a `DocoptLanguageError`, whatever `argv` holds.

```javascript
import { parse } from 'docopt';

let r = parse(doc, ARGV, { version: '1.0.0' });
if (r.help)    { print(doc); exit(0); }
if (r.version) { print('1.0.0\n'); exit(0); }
if (r.error) {
    warn(`greet: ${r.error}\n${r.usage}\nRun 'greet --help' for more.\n`);
    exit(2);
}
let args = r.args;
```

### Specification Compliance
This implementation passes the reference's own test suites, as upstream publishes them: `test/testcases.docopt` (upstream's current one) and `test/testcases-0.6.2.docopt` (the 0.6.2 release's). `test/extra.docopt` holds cases beyond them, and `test/reference_test.uc` the reference's behaviour those suites do not cover. Supported:
*   Short options (`-v`) and long options (`--verbose`).
*   Option stacking (`-abc` as `-a -b -c`).
*   Option-arguments (`--file=input.txt` or `--file input.txt`).
*   Positional arguments (`<input>`).
*   Commands (`run`, `remote`).
*   Required/Optional groups (`()`, `[]`) and choices (`|`).

---

## Explanation

### About ucode-docopt
`ucode-docopt` is based on the idea that a good help message contains all the information necessary to parse command-line arguments. Instead of building a parser with code, you write the interface in plain text.

### Architecture
The library is divided into four main phases:
1.  **Scanner** (`docopt/scanner.uc`): Extracts the `Usage:` and `Options:` sections from your doc string.
2.  **Parser** (`docopt/parser.uc`): Converts the usage patterns into an Abstract Syntax Tree (AST).
3.  **Preparation** (`docopt/matcher.uc`): Expands `[options]` shortcuts, resolves shared node identities and marks repeating arguments.
4.  **Matcher** (`docopt/matcher.uc`): Tokenizes `argv` and matches it against the prepared AST.

### Differences from other implementations
While `ucode-docopt` aims for 100% compatibility with the Python reference implementation, it is optimized for the `ucode` environment, providing a lightweight and fast parsing experience suitable for embedded systems and OpenWrt environments.

It follows the reference (docopt 0.6.2) except where listed here:

*   `--` (the end of options) is accepted anywhere, whether or not the usage names it. The reference refuses it unless the pattern has `[--]`. When the pattern does have `[--]`, `--` is reported as `true` when given, as in the reference.
*   `--` is never an option's argument: `-l --` says `-l requires argument` (0.6.2 takes `--` as the value; upstream later changed that, as here).
*   `[options]` is recognised in any letter case (`[OPTIONS]`, `[Options]`), so an argument cannot be named `OPTIONS`.
*   A long option in the usage pattern resolves by prefix: `[--ver]` is `--verbose` when the doc describes `--verbose`.
*   An option defined twice is its first definition; the reference refuses to use it.
*   Without an `Options:` section, option definitions are read from the doc outside its usage section; the reference also reads a usage line that starts with `-` as one.
*   Lenient option descriptions: `[default:10]` without a space, a tab between an option and its description, and text after `[default: …]`.
*   A pattern with a stray `...` is refused as a language error.
