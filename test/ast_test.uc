'use strict';

import { describe, it, assert, equals, not, has_length, any_order } from 'utest';
import {
    Argument,
    Command,
    Option,
    Required,
    Optional,
    unique_leaves,
    node_key
} from 'docopt.ast';

describe('docopt.ast', () => {
    it('node_key() should generate unique keys for leaf nodes', () => {
        let a1 = Argument('<name>');
        let a2 = Argument('<name>');
        let a3 = Argument('<other>');
        assert.match(node_key(a1), node_key(a2));
        assert.match(not(equals(node_key(a3))), node_key(a1));

        let o1 = Option('-v', '--verbose', 0, false);
        let o2 = Option('-v', null, 0, false);
        assert.match(not(equals(node_key(o2))), node_key(o1));
    });

    it('unique_leaves() should return deduplicated leaf nodes', () => {
        let pattern = Required([
            Argument('<name>'),
            Optional([
                Argument('<name>'),
                Option('-v', null, 0, false)
            ]),
            Command('run'),
            Option('-v', null, 0, false)
        ]);

        let leaves = unique_leaves(pattern);
        assert.match(has_length(3), leaves); // <name>, -v, run
        assert.match(any_order(['Argument', 'Option', 'Command']), map(leaves, l => l.type));
    });

    it('Option constructor should handle default values correctly', () => {
        let o = Option('-p', '--path', 1, './');
        assert.match('-p', o.short);
        assert.match('--path', o.long);
        assert.match(1, o.argcount);
        assert.match('./', o.value);

        let flag = Option('-v', null, 0);
        assert.match(false, flag.value);
    });
});
