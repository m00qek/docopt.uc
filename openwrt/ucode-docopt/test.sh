#!/bin/sh
# The installed package: docopt() and parse() load and parse.

ucode - <<'EOF'
'use strict';
import { docopt, parse } from 'docopt';

const doc = `
Usage:
  test.sh <input>
  test.sh -h | --help
`;

const args = docopt(doc, ['world'], false);
if (args['<input>'] !== 'world') exit(1);

if (parse(doc, ['world']).args['<input>'] !== 'world') exit(1);
if (parse(doc, ['--help']).help !== true) exit(1);
if (parse(doc, ['--bogus']).error !== 'unknown option --bogus') exit(1);
EOF
