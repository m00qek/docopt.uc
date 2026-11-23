'use strict';

import { describe, it, assert, mock } from 'utest';
import { docopt } from 'docopt';
import * as fs from 'fs';

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

            let expected_lines = slice(lines, 1);
            let expected_raw = join('\n', expected_lines);

            push(cases, { doc, argv, expected_raw });
        }
    }
    return cases;
}

// The reference's suites, as upstream publishes them, and this
// implementation's own cases in the same format.
const SUITES = {
    'docopt upstream suite (testcases.docopt)': 'testcases.docopt',
    'docopt 0.6.2 suite (testcases-0.6.2.docopt)': 'testcases-0.6.2.docopt',
    'cases beyond the reference (extra.docopt)': 'extra.docopt',
};
const DIR = sourcepath(0, true);

for (let title, file in SUITES) {
    let cases = parse_testcases(fs.readfile(`${DIR}/${file}`));
    describe(title, () => {
        for (let i = 0; i < length(cases); i++) {
            let c = cases[i];
            let first_line = split(trim(c.doc), '\n')[0];
            let argv_str   = length(c.argv) > 0 ? ' ' + join(' ', c.argv) : '';

            let label = sprintf('case %d: %s | $ prog%s', i + 1, trim(first_line), argv_str);

            it(label, () => {
                if (c.expected_raw === '"user-error"') {
                    let threw = false;
                    mock.inject_builtin('exit', () => { die("MOCK_EXIT"); }, () =>
                        mock.inject_builtin('warn', () => {}, () => {
                            try {
                                docopt(c.doc, c.argv, false);
                            } catch(e) {
                                if (type(e) === 'string' && match(e, /MOCK_EXIT/)) threw = true;
                                else if (type(e) === 'object' && e.message && match(e.message, /MOCK_EXIT/)) threw = true;
                            }
                        })
                    );
                    assert.match(true, threw);
                } else {
                    assert.match(json(c.expected_raw), docopt(c.doc, c.argv, false));
                }
            });
        }
    });
}
