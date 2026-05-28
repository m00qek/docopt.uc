'use strict';

import { describe, it, assert, equals } from 'utest';
import { docopt } from 'docopt';
import * as fs from 'fs';

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
