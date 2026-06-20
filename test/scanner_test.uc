'use strict';

import { describe, it, assert, equals } from 'utest';
import {
    find_sections,
    parse_option_line,
    parse_defaults,
    formal_usage
} from 'docopt.scanner';

describe('docopt.scanner', () => {
    it('find_sections() should extract sections by name', () => {
        const doc = `
Usage:
  prog [options]

Description:
  This is a program.

Options:
  -v --verbose  More output.
`;
        let usage = find_sections(doc, 'usage');
        assert.match(equals(1), length(usage));
        assert.match(equals('prog [options]'), trim(usage[0].body));

        let opts = find_sections(doc, 'options');
        assert.match(equals(1), length(opts));
        assert.match(equals('-v --verbose  More output.'), trim(opts[0].body));
    });

    it('parse_option_line() should parse various option formats', () => {
        let o1 = parse_option_line('  -v, --verbose  Description');
        assert.match(equals('-v'), o1.short);
        assert.match(equals('--verbose'), o1.long);
        assert.match(equals(0), o1.argcount);

        let o2 = parse_option_line('  --path=<p>     Path [default: /tmp]');
        assert.match(equals('--path'), o2.long);
        assert.match(equals(1), o2.argcount);
        assert.match(equals('/tmp'), o2.value);

        let o3 = parse_option_line('  -pPATH         Path');
        assert.match(equals('-p'), o3.short);
        assert.match(equals(1), o3.argcount);
    });

    it('[default:] on a continuation line should be parsed', () => {
        let o = parse_option_line('  --speed=<kn>  Speed in knots\n                [default: 10]');
        assert.match(equals('--speed'), o.long);
        assert.match(equals(1), o.argcount);
        assert.match(equals('10'), o.value);

        // Also verify that parse_defaults picks up [default:] on continuation lines
        const doc2 = `
Usage: prog [--speed=<kn>]

Options:
  --speed=<kn>  Speed in knots
                [default: 42]
`;
        let defaults = parse_defaults(doc2);
        assert.match(equals(1), length(defaults));
        assert.match(equals('42'), defaults[0].value);
    });

    it('formal_usage() should normalize usage pattern', () => {
        const doc = `
Usage:
  prog ship <name>
  prog move <x> <y>
`;
        let fu = formal_usage(doc);
        assert.match(equals('( ship <name> | move <x> <y> )'), fu);
    });
});
