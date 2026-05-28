'use strict';

import { describe, it, assert, equals } from 'utest';
import {
    Argument,
    Command,
    Option,
    Required,
    Optional,
    unique_leaves,
    node_key
} from 'docopt.ast';
import { arr_find } from 'docopt.common';

describe('docopt.ast', () => {
    it('node_key() should generate unique keys for leaf nodes', () => {
        let a1 = Argument('<name>');
        let a2 = Argument('<name>');
        let a3 = Argument('<other>');
        assert.match(equals(node_key(a1)), node_key(a2));
        assert.match(equals(true), node_key(a1) !== node_key(a3));

        let o1 = Option('-v', '--verbose', 0, false);
        let o2 = Option('-v', null, 0, false);
        assert.match(equals(true), node_key(o1) !== node_key(o2));
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
        assert.match(equals(3), length(leaves)); // <name>, -v, run

        let types = map(leaves, l => l.type);
        assert.match(equals(true), !!arr_find(types, t => t === 'Argument'));
        assert.match(equals(true), !!arr_find(types, t => t === 'Option'));
        assert.match(equals(true), !!arr_find(types, t => t === 'Command'));
    });

    it('Option constructor should handle default values correctly', () => {
        let o = Option('-p', '--path', 1, './');
        assert.match(equals('-p'), o.short);
        assert.match(equals('--path'), o.long);
        assert.match(equals(1), o.argcount);
        assert.match(equals('./'), o.value);

        let flag = Option('-v', null, 0);
        assert.match(equals(false), flag.value);
    });
});
