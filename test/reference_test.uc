'use strict';

// Behaviour the official testcases.docopt does not cover, as the reference
// implementation (docopt.py and its test_docopt.py) has it, except where
// noted: each was a bug here.

import { describe, it, assert, equals } from 'utest';
import { parse } from 'docopt';

describe('docopt, as the reference', () => {
    it('matches a command only as the next positional', () => {
        assert.match('the arguments do not match the usage', parse('Usage: prog go <x>', [ 'bar', 'go' ]).error);
        assert.match(equals({ go: true, '<x>': 'bar' }), parse('Usage: prog go <x>', [ 'go', 'bar' ]).args);
    });

    it('reads a usage pattern wrapped onto an indented line', () => {
        const doc = 'Usage:\n  prog pull [-n]\n            [<cert>...]\n\nOptions:\n  -n  Dry.\n';
        assert.match(equals([ 'a', 'b' ]), parse(doc, [ 'pull', 'a', 'b' ]).args['<cert>']);
        assert.match('the arguments do not match the usage', parse(doc, []).error);
    });

    it('takes no argument for an option the doc does not describe', () => {
        assert.match(equals({ '-v': true, '<file>': 'x' }), parse('Usage: prog -v <file>', [ '-v', 'x' ]).args);
        assert.match(equals({ '--verbose': true, '<file>': 'x' }), parse('Usage: prog --verbose <file>', [ '--verbose', 'x' ]).args);
    });

    it('still takes the metavar of an option described with an argument', () => {
        const doc = 'Usage: prog -o FILE <in>\n\nOptions:\n  -o FILE  Out.\n';
        assert.match(equals({ '-o': 'out', '<in>': 'in' }), parse(doc, [ '-o', 'out', 'in' ]).args);
    });

    it('with options_first, leaves a --help after the first positional to it', () => {
        const doc = 'Usage: prog [-v] <cmd> [<args>...]\n\nOptions:\n  -v  V.\n  -h --help  H.\n';
        assert.match(equals([ '--help' ]), parse(doc, [ 'run', '--help' ], { options_first: true }).args['<args>']);
        assert.match(equals({ help: true }), parse(doc, [ '--help', 'run' ], { options_first: true }));
    });

    it('reports [--] when given, and accepts -- anywhere when the usage does not name it (unlike the reference)', () => {
        assert.match(equals({ '-o': false, '<arg>': '-o', '--': true }), parse('Usage: prog [-o] [--] <arg>\n\nOptions:\n  -o  O.\n', [ '--', '-o' ]).args);
        assert.match(equals({ '-o': true, '<arg>': '1', '--': false }), parse('Usage: prog [-o] [--] <arg>\n\nOptions:\n  -o  O.\n', [ '-o', '1' ]).args);
        assert.match(equals({ '-o': false, '<arg>': '-o' }), parse('Usage: prog [-o] <arg>\n\nOptions:\n  -o  O.\n', [ '--', '-o' ]).args);
    });

    it('keeps a -- after options_first stopped, for the subcommand', () => {
        const doc = 'Usage: prog <cmd> [<args>...]';
        assert.match(equals([ '--', 'x' ]), parse(doc, [ 'run', '--', 'x' ], { options_first: true }).args['<args>']);
    });

    it('does not take -- as an option\'s argument', () => {
        assert.match('--log requires argument', parse('Usage: prog [--log=LEVEL] [--] <args>...', [ '--log', '--', '1', '2' ]).error);
        assert.match('-l requires argument', parse('Usage: prog [-l LEVEL] [--] <args>...\n\nOptions:\n  -l LEVEL  L.\n', [ '-l', '--', '1', '2' ]).error);
    });

    it('gives a repeated option with an empty default no values', () => {
        assert.match(equals([]), parse('Usage: prog [-o <x>]...\n\nOptions:\n  -o <x>  Out [default: ].\n', []).args['-o']);
        assert.match(equals([ 'a', 'b' ]), parse('Usage: prog [-o <x>]...\n\nOptions:\n  -o <x>  Out [default: a b].\n', []).args['-o']);
    });
});
