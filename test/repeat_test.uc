'use strict';

// Repeated elements (<f>..., -v..., [-o FILE]...) are matched in one pass:
// these check the result against what repeating the match gives, computed
// here independently, and that long argument lists are parsed whole.

import { describe, it, assert, equals } from 'utest';
import * as math from 'math';
import { parse } from 'docopt';

const DOC = 'Usage: prog [-v]... [-o FILE]... [<f>...]\n\nOptions:\n  -v  V.\n  -o FILE  O.\n';

// What the doc's usage gives for argv: -v counted, -o's values and the
// positionals in order.
function expected(argv) {
    let v = 0, o = [], f = [];
    for (let i = 0; i < length(argv); i++) {
        let a = argv[i];
        if (a === '-v') v++;
        else if (a === '-vv') v += 2;
        else if (a === '-o') push(o, argv[++i]);
        else push(f, a);
    }
    return { '-v': v, '-o': o, '<f>': f };
}

describe('repeated elements', () => {
    it('match as repeating the match would, on random argument lists', () => {
        math.srand(42);
        const words = [ '-v', '-vv', '-o', 'a.txt', 'b.txt', 'c' ];
        for (let n = 0; n < 300; n++) {
            let argv = [];
            for (let k = math.rand() % 12; k > 0; k--) {
                let w = words[math.rand() % length(words)];
                push(argv, w);
                if (w === '-o') push(argv, `out${k}`);
            }
            assert.match(equals(expected(argv)), parse(DOC, argv).args);
        }
    });

    it('count a repeated command only over its leading run', () => {
        assert.match(equals({ go: 2, '<x>': 'x' }), parse('Usage: prog go... <x>', [ 'go', 'go', 'x' ]).args);
        assert.match('unexpected argument go', parse('Usage: prog go... <x>', [ 'go', 'x', 'go' ]).error);
    });

    it('take no match through brackets as a match, and none without them as none', () => {
        assert.match(equals({ '-v': 0, '<x>': 'x' }), parse('Usage: prog [-v]... <x>\n\nOptions:\n  -v  V.\n', [ 'x' ]).args);
        assert.match('the arguments do not match the usage', parse('Usage: prog -v... <x>\n\nOptions:\n  -v  V.\n', [ 'x' ]).error);
    });

    it('parse a long argument list whole', () => {
        let argv = [];
        for (let i = 0; i < 20000; i++) push(argv, (i % 10 === 0) ? '-v' : `f${i}`);
        let r = parse(DOC, argv).args;
        assert.match(2000, r['-v']);
        assert.match(18000, length(r['<f>']));
        assert.match('f19999', r['<f>'][-1]);
    });
});
