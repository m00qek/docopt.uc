'use strict';

import { describe, it, assert, equals } from 'utest';
import { parse } from 'docopt';

// parse(): docopt's matching without printing or exiting.
describe('docopt parse', () => {
    const doc = `
Usage:
  prog pull [-n] [<cert>...]
  prog csr <cert>
  prog -h | --help
  prog --version

Options:
  -n --dry-run  Change nothing.
  --speed=<kn>  Speed [default: 10].
  -h --help     Show this help.
  --version     Show the version.
`;
    const usage = 'Usage: prog pull [-n] [<cert>...]\n  prog csr <cert>\n  prog -h | --help\n  prog --version';

    it('returns the arguments on a match', () => {
        let r = parse(doc, [ 'pull', '-n', 'site' ]);
        assert.match(true, r.args['pull']);
        assert.match(true, r.args['--dry-run']);
        assert.match(equals([ 'site' ]), r.args['<cert>']);
        assert.match(null, r.error);
    });

    it('reports -h and --help, without printing or exiting', () => {
        assert.match(equals({ help: true }), parse(doc, [ '--help' ]));
        assert.match(equals({ help: true }), parse(doc, [ 'pull', '-nh' ]));
    });

    it('leaves -h to the usage when help is false', () => {
        assert.match(true, parse(doc, [ '-h' ], { help: false }).args['--help']);
    });

    it('reports --version only when a version is given', () => {
        assert.match(equals({ version: true }), parse(doc, [ '--version' ], { version: '1.0' }));
        assert.match(true, parse(doc, [ '--version' ]).args['--version']);
    });

    it('says which option is unknown, with the usage', () => {
        assert.match(equals({ error: 'unknown option --foo', usage: usage }), parse(doc, [ 'pull', '--foo' ]));
        assert.match('unknown option -x', parse(doc, [ 'pull', '-x' ]).error);
    });

    it('says an option the doc knows is out of place, not unknown, by its long name', () => {
        assert.match('unexpected option --dry-run', parse(doc, [ 'csr', '-n', 'site' ]).error);
    });

    it('says which argument is unexpected', () => {
        assert.match('unexpected argument b', parse(doc, [ 'csr', 'a', 'b' ]).error);
    });

    it('says the arguments do not match when nothing more precise is known', () => {
        assert.match('the arguments do not match the usage', parse(doc, [ 'csr' ]).error);
        assert.match('the arguments do not match the usage', parse(doc, []).error);
    });

    it('passes on the tokenizer\'s own errors, without its prefix', () => {
        assert.match('--speed requires argument', parse(doc, [ 'pull', '--speed' ]).error);
        assert.match('--dry-run must not have an argument', parse(doc, [ 'pull', '--dry-run=1' ]).error);
    });

    it('honours options_first', () => {
        const fdoc = 'Usage: prog [-v] <cmd> [<args>...]\n\nOptions:\n  -v  Verbose.\n';
        assert.match(equals([ '-v' ]), parse(fdoc, [ 'run', '-v' ], { options_first: true }).args['<args>']);
    });
});
