'use strict';

import { describe, it, assert, equals } from 'utest';
import { docopt } from 'docopt';
import * as fs from 'fs';

function join(arr, sep) {
    let r = '';
    for (let i = 0; i < length(arr); i++) {
        if (i > 0) r += sep;
        r += arr[i];
    }
    return r;
}

function parse_testcases(content) {
    let cases = [];
    let blocks = split(content, 'r"""');
    for (let i = 1; i < length(blocks); i++) {
        let block = blocks[i];
        let end = index(block, '"""');
        if (end < 0) continue;
        let doc  = substr(block, 0, end);
        let rest = trim(substr(block, end + 3));

        let examples = split(rest, /\n[ \t]*\n/);
        for (let ex in examples) {
            let lines = filter(
                map(split(trim(ex), '\n'),
                    l => trim(replace(l, /#.*$/, ''))),
                l => length(l) > 0
            );

            if (length(lines) < 2) continue;
            if (substr(lines[0], 0, 2) !== '$ ') continue;

            let cmd_tokens = split(trim(substr(lines[0], 2)), /\s+/);
            let argv = slice(cmd_tokens, 1);

            // Collect all non-empty lines after the command line as expected value
            // (handles multi-line JSON objects)
            let expected_lines = slice(lines, 1);
            let expected_raw = join(expected_lines, '\n');

            push(cases, { doc, argv, expected_raw });
        }
    }
    return cases;
}

let raw   = fs.readfile('/app/testcases.docopt');
let cases = parse_testcases(raw);

describe('docopt official spec', () => {
    for (let i = 0; i < length(cases); i++) {
        let c = cases[i];
        let first_line = split(trim(c.doc), '\n')[0];
        let argv_str   = length(c.argv) > 0 ? ' ' + join(c.argv, ' ') : '';

        let doc          = c.doc;
        let argv         = c.argv;
        let expected_raw = c.expected_raw;
        let label        = sprintf('case %d: %s | $ prog%s', i + 1, trim(first_line), argv_str);

        it(label, () => {
            if (expected_raw === '"user-error"') {
                assert.throws(
                    () => docopt(doc, argv, false),
                    /DocoptExit|DocoptLanguageError/
                );
            } else {
                let expected = json(expected_raw);
                let result   = docopt(doc, argv, false);
                assert.match(equals(expected), result);
            }
        });
    }
});
