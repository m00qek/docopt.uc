#!/usr/bin/env ucode
'use strict';

import { docopt } from 'docopt';

const doc = `
Naval Fate.

Usage:
  naval_fate.uc ship new <name>...
  naval_fate.uc ship [<name>] move <x> <y> [--speed=<kn>]
  naval_fate.uc ship shoot <x> <y>
  naval_fate.uc mine (set|remove) <x> <y> [--moored|--drifting]
  naval_fate.uc -h | --help
  naval_fate.uc --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
  --moored      Moored (anchored) mine.
  --drifting    Drifting mine.
`;

// Parse command line arguments
// ARGV is the global array of command line arguments in ucode
const args = docopt(doc, ARGV);

// Print the resulting object as JSON
print(sprintf("%J\n", args));
