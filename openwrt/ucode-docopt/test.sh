#!/bin/sh

ucode - <<'EOF'
'use strict';
import { docopt } from 'docopt';

const doc = `
Usage:
  test.sh <input>
  test.sh -h | --help
`;

const args = docopt(doc, ['world'], false);
if (args['<input>'] !== 'world') exit(1);
EOF
