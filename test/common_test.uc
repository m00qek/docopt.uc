'use strict';

import { describe, it, assert, equals, prop, gen } from 'utest';
import {
    arr_find,
    starts_with,
    ends_with,
    is_ws,
    is_argument_word,
    ends_with_options
} from 'docopt.common';

describe('docopt.common', () => {
    it('join() builtin should join arrays with separator', () => {
        assert.match(equals('a,b,c'), join(',', ['a', 'b', 'c']));
        assert.match(equals('abc'), join('', ['a', 'b', 'c']));
        assert.match(equals('a'), join(',', ['a']));
        assert.match(equals(''), join(',', []));
    });

    it('arr_find() should find first matching element', () => {
        let arr = [1, 2, 3, 4];
        assert.match(equals(3), arr_find(arr, x => x > 2));
        assert.match(equals(null), arr_find(arr, x => x > 10));
    });

    it('starts_with() / ends_with() should work correctly', () => {
        assert.match(equals(true),  starts_with('foobar', 'foo'));
        assert.match(equals(false), starts_with('foobar', 'bar'));
        assert.match(equals(true),  ends_with('foobar', 'bar'));
        assert.match(equals(false), ends_with('foobar', 'foo'));
    });

    it('is_ws() should detect whitespace', () => {
        assert.match(equals(true),  is_ws(' '));
        assert.match(equals(true),  is_ws('\n'));
        assert.match(equals(true),  is_ws('\t'));
        assert.match(equals(false), is_ws('a'));
    });

    it('is_argument_word() should detect ALL-CAPS words', () => {
        assert.match(equals(true),  is_argument_word('NAME'));
        assert.match(equals(true),  is_argument_word('FIRST_NAME'));
        assert.match(equals(false), is_argument_word('<name>'));
        assert.match(equals(false), is_argument_word('name'));
        assert.match(equals(false), is_argument_word('Name'));
    });

    it('ends_with_options() should detect "options" suffix case-insensitively', () => {
        assert.match(equals(true), ends_with_options('options'));
        assert.match(equals(true), ends_with_options('Options'));
        assert.match(equals(true), ends_with_options('Global Options'));
        assert.match(equals(false), ends_with_options('usage'));
    });

    prop('starts_with(pre + suf, pre) always holds',
        gen.tuple(gen.string({max_len: 15}), gen.string({max_len: 15})),
        (p) => assert.match(equals(true), starts_with(p[0] + p[1], p[0])));

    prop('ends_with(pre + suf, suf) always holds',
        gen.tuple(gen.string({max_len: 15}), gen.string({max_len: 15})),
        (p) => assert.match(equals(true), ends_with(p[0] + p[1], p[1])));
});
