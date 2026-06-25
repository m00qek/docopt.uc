'use strict';

import { describe, it, assert, mock, has_length, contains, prop, gen } from 'utest';
import { docopt } from 'docopt';
import { tokenize_argv } from 'docopt.matcher';
import { Option } from 'docopt.ast';

describe('docopt public API', () => {
    const doc = `
Usage: prog [options] <name>

Options:
  -v --verbose  Verbose mode.
  --speed=<kn>  Speed [default: 10].
`;

    it('should return a result object on successful match', () => {
        let args = docopt(doc, ['-v', 'Enterprise']);
        assert.match(true, args['--verbose']);
        assert.match('Enterprise', args['<name>']);
        assert.match('10', args['--speed']);
    });

    it('should respect options_first: true', () => {
        let args = docopt(doc, ['Enterprise', '-v'], false, null, false);
        assert.match(true, args['--verbose']);
        assert.match('Enterprise', args['<name>']);

        let threw = false;
        mock.inject_builtin('exit', () => { die("MOCK_EXIT"); }, () =>
            mock.inject_builtin('warn', () => {}, () => {
                try {
                    docopt(doc, ['Enterprise', '-v'], false, null, true);
                } catch(e) {
                    let msg = type(e) === 'object' ? e.message : e;
                    if (type(msg) === 'string' && match(msg, /MOCK_EXIT/)) threw = true;
                }
            })
        );
        assert.match(true, threw);
    });

    it('should exit 0 when -h/--help is found with help=true', () => {
        let exited = null;
        mock.inject_builtin('exit', (code) => { exited = code; die('MOCK_EXIT'); }, () => {
            try { docopt(doc, ['--help']); } catch(e) {}
        });
        assert.match(0, exited);
    });

    it('should exit 0 when --version is found and version is set', () => {
        const vdoc = `
Usage: prog [--version]

Options:
  --version  Show version.
`;
        let exited = null;
        mock.inject_builtin('exit', (code) => { exited = code; die('MOCK_EXIT'); }, () => {
            try { docopt(vdoc, ['--version'], true, '1.2.3'); } catch(e) {}
        });
        assert.match(0, exited);
    });

    it('should treat args after -- as positionals', () => {
        const ddoc = `
Usage: prog [options] [<args>...]

Options:
  -v --verbose
`;
        let args = docopt(ddoc, ['--', '-v', '--verbose'], false);
        assert.match(false, args['--verbose']);
        assert.match(['-v', '--verbose'], args['<args>']);
    });

    it('--opt=FILE in usage should not swallow the following positional argument', () => {
        const doc2 = `
Usage: prog --output=FILE <input>

Options:
  --output=FILE  Output file.
`;
        let args = docopt(doc2, ['--output', 'report.txt', 'data.csv'], false);
        assert.match('report.txt', args['--output']);
        assert.match('data.csv', args['<input>']);
    });

    it('-oFILE in usage should preserve the option default when not supplied', () => {
        const doc3 = `
Usage: prog [-oFILE]

Options:
  -o FILE  Output file [default: out.txt].
`;
        let args = docopt(doc3, [], false);
        assert.match('out.txt', args['-o']);
    });

    it('-oFILE in usage should yield null for arg-option with no default when not supplied', () => {
        const doc4 = `
Usage: prog [-oFILE]

Options:
  -o FILE  Output file.
`;
        let args = docopt(doc4, [], false);
        assert.match(null, args['-o']);
    });

    it('[options]... should count repeated flags as integers', () => {
        const doc5 = `
Usage: prog [options]...

Options:
  -v  Verbose.
`;
        let args = docopt(doc5, ['-v', '-v'], false);
        assert.match(2, args['-v']);
    });

    it('tokenize_argv() should expand short option stacks', () => {
        let opts = [Option('-v', null, 0, false), Option('-n', null, 1, null)];
        let tokens = tokenize_argv(['-vn', 'foo'], opts, false);
        assert.match(has_length(2), tokens);
        assert.match(contains({ type: 'Option', short: '-v', value: true }), tokens[0]);
        assert.match(contains({ type: 'Option', short: '-n', value: 'foo' }), tokens[1]);
    });

    it('tokenize_argv() should consume inline remainder as value for short option', () => {
        let opts = [Option('-n', null, 1, null)];
        let tokens = tokenize_argv(['-nfoo'], opts, false);
        assert.match(has_length(1), tokens);
        assert.match(contains({ type: 'Option', short: '-n', value: 'foo' }), tokens[0]);
    });

    it('tokenize_argv() should parse long options with inline = value', () => {
        let opts = [Option(null, '--path', 1, null)];
        let tokens = tokenize_argv(['--path=home'], opts, false);
        assert.match(has_length(1), tokens);
        assert.match(contains({ type: 'Option', long: '--path', value: 'home' }), tokens[0]);
    });

    prop('every token after -- is an Argument',
        gen.array(gen.elements('--flag', '-f', 'word', 'another'), {max_len: 5}),
        (after_sep) => {
            let tokens = tokenize_argv(['--', ...after_sep], [], false);
            for (let t in tokens)
                assert.match('Argument', t.type);
        });

    it('should exit on mismatch', () => {
        let threw = false;
        mock.inject_builtin('exit', () => { die("MOCK_EXIT"); }, () =>
            mock.inject_builtin('warn', () => {}, () => {
                try {
                    docopt(doc, ['-x'], false);
                } catch(e) {
                    if (type(e) === 'string' && match(e, /MOCK_EXIT/)) threw = true;
                    else if (type(e) === 'object' && e.message && match(e.message, /MOCK_EXIT/)) threw = true;
                }
            })
        );
        assert.match(true, threw);
    });
});
