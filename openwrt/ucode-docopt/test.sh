#!/usr/bin/ucode

'use strict';

import { docopt } from 'docopt';

const doc = `
Usage:
  test.sh <input>
  test.sh -h | --help
`;

const args = docopt(doc, ['world']);

if (args['<input>'] === 'world') {
    print("Smoke test passed\n");
    exit(0);
} else {
    print("Smoke test failed\n");
    exit(1);
}
