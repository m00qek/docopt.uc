'use strict';

import { describe, it, assert, equals, prop, gen } from 'utest';
import { docopt } from 'docopt';
import { tokenize_argv } from 'docopt.matcher';

describe('docopt public API', () => {
    const doc = `
Usage: prog [options] <name>

Options:
  -v --verbose  Verbose mode.
  --speed=<kn>  Speed [default: 10].
`;

    it('should return a result object on successful match', () => {
        let args = docopt(doc, ['-v', 'Enterprise']);
        assert.match(equals(true), args['--verbose']);
        assert.match(equals('Enterprise'), args['<name>']);
        assert.match(equals('10'), args['--speed']);
    });

    it('should respect options_first: true', () => {
        // options_first=false: flag after positional is still parsed as an option
        let args = docopt(doc, ['Enterprise', '-v'], false, null, false);
        assert.match(equals(true), args['--verbose']);
        assert.match(equals('Enterprise'), args['<name>']);

        // options_first=true: flag after positional becomes a positional token → unmatched → exit
        let threw = false;
        let old_exit = global.exit;
        let old_warn = global.warn;
        global.exit = function(code) { die("MOCK_EXIT"); };
        global.warn = function() {};
        try {
            docopt(doc, ['Enterprise', '-v'], false, null, true);
        } catch(e) {
            let msg = type(e) === 'object' ? e.message : e;
            if (type(msg) === 'string' && match(msg, /MOCK_EXIT/)) threw = true;
        }
        global.exit = old_exit;
        global.warn = old_warn;
        assert.match(equals(true), threw);
    });

    it('should exit 0 when -h/--help is found with help=true', () => {
        let exited = null;
        let old_exit = global.exit;
        global.exit = function(code) { exited = code; die('MOCK_EXIT'); };
        try { docopt(doc, ['--help']); } catch(e) {}
        global.exit = old_exit;
        assert.match(equals(0), exited);
    });

    it('should exit 0 when --version is found and version is set', () => {
        const vdoc = `
Usage: prog [--version]

Options:
  --version  Show version.
`;
        let exited = null;
        let old_exit = global.exit;
        global.exit = function(code) { exited = code; die('MOCK_EXIT'); };
        try { docopt(vdoc, ['--version'], true, '1.2.3'); } catch(e) {}
        global.exit = old_exit;
        assert.match(equals(0), exited);
    });

    it('should treat args after -- as positionals', () => {
        const ddoc = `
Usage: prog [options] [<args>...]

Options:
  -v --verbose
`;
        let args = docopt(ddoc, ['--', '-v', '--verbose'], false);
        assert.match(equals(false), args['--verbose']);
        assert.match(equals(['-v', '--verbose']), args['<args>']);
    });

    it('--opt=FILE in usage should not swallow the following positional argument', () => {
        const doc2 = `
Usage: prog --output=FILE <input>

Options:
  --output=FILE  Output file.
`;
        let args = docopt(doc2, ['--output', 'report.txt', 'data.csv'], false);
        assert.match(equals('report.txt'), args['--output']);
        assert.match(equals('data.csv'), args['<input>']);
    });

    it('-oFILE in usage should preserve the option default when not supplied', () => {
        const doc3 = `
Usage: prog [-oFILE]

Options:
  -o FILE  Output file [default: out.txt].
`;
        let args = docopt(doc3, [], false);
        assert.match(equals('out.txt'), args['-o']);
    });

    it('-oFILE in usage should yield null for arg-option with no default when not supplied', () => {
        const doc4 = `
Usage: prog [-oFILE]

Options:
  -o FILE  Output file.
`;
        let args = docopt(doc4, [], false);
        assert.match(equals(null), args['-o']);
    });

    it('[options]... should count repeated flags as integers', () => {
        const doc5 = `
Usage: prog [options]...

Options:
  -v  Verbose.
`;
        let args = docopt(doc5, ['-v', '-v'], false);
        assert.match(equals(2), args['-v']);
    });

    prop('every token after -- is an Argument',
        gen.array(gen.elements('--flag', '-f', 'word', 'another'), {max_len: 5}),
        (after_sep) => {
            let tokens = tokenize_argv(['--', ...after_sep], [], false);
            for (let t in tokens)
                assert.match(equals('Argument'), t.type);
        });

    it('should exit on mismatch', () => {
        let threw = false;
        let old_exit = global.exit;
        let old_warn = global.warn;
        global.exit = function(code) { die("MOCK_EXIT"); };
        global.warn = function() {}; // silence

        try {
            docopt(doc, ['-x'], false);
        } catch(e) {
            if (type(e) === 'string' && match(e, /MOCK_EXIT/)) threw = true;
            else if (type(e) === 'object' && e.message && match(e.message, /MOCK_EXIT/)) threw = true;
        }

        global.exit = old_exit;
        global.warn = old_warn;

        assert.match(equals(true), threw);
    });
});
