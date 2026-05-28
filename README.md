# ucode-docopt

A complete, specification-compliant implementation of **docopt** for the **ucode** programming language.

`ucode-docopt` helps you create beautiful command-line interfaces by describing them in a human-readable help message. You write the help message, and `ucode-docopt` handles the parsing.

---

## Tutorial: Getting Started

In this tutorial, we will create a simple CLI tool that greets a user.

### 1. Define your interface
Create a file named `greet.uc`. We start by defining a `doc` string that describes our program's usage and options.

```javascript
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
Execute your script from the terminal:

```bash
# Basic usage
ucode greet.uc world
# Output: Hello, world!

# Using an option
ucode greet.uc --shout world
# Output: HELLO, WORLD!

# Automatic help
ucode greet.uc --help
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
*   **`help`** (boolean): If `true`, the program will automatically print the help message and exit if `-h` or `--help` is found.
*   **`version`** (string|null): If provided, the program will print this string and exit if `--version` is found.
*   **`options_first`** (boolean): If `true`, stops parsing options after the first positional argument.

**Returns:** An object where keys are argument/option names (e.g., `<name>`, `--verbose`) and values are their parsed states (boolean, string, or array).

### Specification Compliance
This implementation passes the official `docopt` test suite, including support for:
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
1.  **Scanner**: Extracts the `Usage:` and `Options:` sections from your doc string.
2.  **Parser**: Converts the usage patterns into an Abstract Syntax Tree (AST).
3.  **Matcher**: Matches the provided `argv` against the AST.
4.  **Refinement**: Fixes identities and repeating arguments to ensure consistent output.

### Differences from other implementations
While `ucode-docopt` aims for 100% compatibility with the Python reference implementation, it is optimized for the `ucode` environment, providing a lightweight and fast parsing experience suitable for embedded systems and OpenWrt environments.
