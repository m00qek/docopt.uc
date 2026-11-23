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

    it('takes -h as help only when it is -h or --help, not another option\'s short form', () => {
        assert.match(equals({ '--host': 'x' }), parse('Usage: prog -h HOST\n\nOptions:\n  -h HOST, --host=HOST  Host.\n', [ '-h', 'x' ]).args);
    });

    it('finds help and the version among the options only the usage has', () => {
        assert.match(equals({ '--out': '--help', '<x>': 'foo' }), parse('Usage: prog --out=FILE <x>', [ '--out', '--help', 'foo' ]).args);
        assert.match(equals({ version: true }), parse('Usage: prog [--version]', [ '--vers' ], { version: '1.0' }));
    });

    it('refuses a doc without a usage section, even for --help', () => {
        assert.throws(() => parse('No usage here', [ '--help' ]), /"usage:" section not found/);
    });

    it('counts an option across two [options] shortcuts', () => {
        assert.match(2, parse('Usage: prog [options] <x> [options]\n\nOptions:\n  -v  V.\n', [ '-v', 'x', '-v' ]).args['-v']);
    });

    it('continues a section past a line of only spaces', () => {
        assert.match(equals({ '-a': false, '-b': true }), parse('Usage: prog [options]\n\nOptions:\n  -a  A.\n  \n  -b  B.\n', [ '-b' ]).args);
    });

    it('refuses a pattern with an unopened ) or a stray ...', () => {
        assert.throws(() => parse('Usage: prog a b)', [ 'a', 'b' ]), /unexpected ending: \)/);
        assert.throws(() => parse('Usage: prog ... a', [ 'a' ]), /must follow an element/);
    });

    it('reads [options ...] with siblings like any group', () => {
        assert.match(equals({ '-q': false, '-a': true }), parse('Usage: prog [options -a]\n\nOptions:\n  -q  Q.\n  -a  A.\n', [ '-a' ]).args);
    });

    it('reads an option defined twice as its first definition (the reference refuses it)', () => {
        assert.match(equals({ '-a': true }), parse('Usage: prog [options]\n\nOptions:\n  -a  A.\n  -a  A again.\n', [ '-a' ]).args);
    });

    it('without an Options section, reads no definition from the usage, whatever its spacing', () => {
        const want = { '-v': false, '<x>': 'x', '-o': true, '<y>': 'y' };
        assert.match(equals(want), parse('Usage: prog [-v] <x>   \n         -o <y>\n\n-v  V.\n', [ 'x', '-o', 'y' ]).args);
        assert.match(equals(want), parse('Usage: prog [-v] <x>\n         -o <y>\n\n-v  V.\n', [ 'x', '-o', 'y' ]).args);
    });

    it('names a long option in full in its errors, whatever prefix was typed', () => {
        assert.match('--verbose must not have an argument', parse('Usage: prog [--verbose]', [ '--verb=1' ]).error);
    });
});
