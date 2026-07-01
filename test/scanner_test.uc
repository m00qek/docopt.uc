'use strict';

import { describe, it, assert, has_length, prop, gen } from 'utest';
import {
    find_sections,
    parse_option_line,
    parse_defaults,
    formal_usage,
    formal_usage_raw
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
        assert.match(has_length(1), usage);
        assert.match('prog [options]', trim(usage[0].body));

        let opts = find_sections(doc, 'options');
        assert.match(has_length(1), opts);
        assert.match('-v --verbose  More output.', trim(opts[0].body));
    });

    it('parse_option_line() should parse various option formats', () => {
        let o1 = parse_option_line('  -v, --verbose  Description');
        if (o1 === null) die('expected an option');
        assert.match('-v', o1.short);
        assert.match('--verbose', o1.long);
        assert.match(0, o1.argcount);

        let o2 = parse_option_line('  --path=<p>     Path [default: /tmp]');
        if (o2 === null) die('expected an option');
        assert.match('--path', o2.long);
        assert.match(1, o2.argcount);
        assert.match('/tmp', o2.value);

        let o3 = parse_option_line('  -pPATH         Path');
        if (o3 === null) die('expected an option');
        assert.match('-p', o3.short);
        assert.match(1, o3.argcount);
    });

    it('[default:] on a continuation line should be parsed', () => {
        let o = parse_option_line('  --speed=<kn>  Speed in knots\n                [default: 10]');
        if (o === null) die('expected an option');
        assert.match('--speed', o.long);
        assert.match(1, o.argcount);
        assert.match('10', o.value);

        const doc2 = `
Usage: prog [--speed=<kn>]

Options:
  --speed=<kn>  Speed in knots
                [default: 42]
`;
        let defaults = parse_defaults(doc2);
        assert.match(has_length(1), defaults);
        assert.match('42', defaults[0].value);
    });

    it('formal_usage() should normalize usage pattern', () => {
        const doc = `
Usage:
  prog ship <name>
  prog move <x> <y>
`;
        assert.match('( ship <name> | move <x> <y> )', formal_usage(doc));
    });

    it('formal_usage() should die with DocoptLanguageError when no usage section', () => {
        assert.throws(() => formal_usage('No usage section here.'), /DocoptLanguageError/);
    });

    it('formal_usage_raw() should return the raw usage section body', () => {
        const doc = `
Usage:
  prog ship <name>
  prog move <x> <y>
`;
        assert.match('  prog ship <name>\n  prog move <x> <y>', formal_usage_raw(doc));
    });

    it('formal_usage_raw() should return empty string when no usage section', () => {
        assert.match('', formal_usage_raw('No usage section here.'));
    });

    prop('parse_option_line round-trips the [default: X] value',
        gen.alphanumeric({min_len: 1, max_len: 20}),
        (val) => {
            let opt = parse_option_line('  -o FILE  Output file [default: ' + val + '].');
            if (opt === null) die('expected an option');
            assert.match(val, opt.value);
        });
});
