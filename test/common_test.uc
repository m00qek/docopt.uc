'use strict';

import { describe, it, assert, truthy, falsy, prop, gen } from 'utest';
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
        assert.match('a,b,c', join(',', ['a', 'b', 'c']));
        assert.match('abc', join('', ['a', 'b', 'c']));
        assert.match('a', join(',', ['a']));
        assert.match('', join(',', []));
    });

    it('arr_find() should find first matching element', () => {
        let arr = [1, 2, 3, 4];
        assert.match(3, arr_find(arr, x => x > 2));
        assert.match(null, arr_find(arr, x => x > 10));
    });

    it('starts_with() / ends_with() should work correctly', () => {
        assert.match(truthy(), starts_with('foobar', 'foo'));
        assert.match(falsy(), starts_with('foobar', 'bar'));
        assert.match(truthy(), ends_with('foobar', 'bar'));
        assert.match(falsy(), ends_with('foobar', 'foo'));
    });

    it('is_ws() should detect whitespace', () => {
        assert.match(truthy(), is_ws(' '));
        assert.match(truthy(), is_ws('\n'));
        assert.match(truthy(), is_ws('\t'));
        assert.match(truthy(), is_ws('\r'));
        assert.match(falsy(), is_ws('a'));
    });

    it('is_argument_word() should detect ALL-CAPS words', () => {
        assert.match(truthy(), is_argument_word('NAME'));
        assert.match(truthy(), is_argument_word('FIRST_NAME'));
        assert.match(falsy(), is_argument_word('<name>'));
        assert.match(falsy(), is_argument_word('name'));
        assert.match(falsy(), is_argument_word('Name'));
    });

    it('ends_with_options() should detect "options" suffix case-insensitively', () => {
        assert.match(truthy(), ends_with_options('options'));
        assert.match(truthy(), ends_with_options('Options'));
        assert.match(truthy(), ends_with_options('Global Options'));
        assert.match(falsy(), ends_with_options('usage'));
    });

    prop('starts_with(pre + suf, pre) always holds',
        gen.tuple(gen.string({max_len: 15}), gen.string({max_len: 15})),
        (p) => assert.match(truthy(), starts_with(p[0] + p[1], p[0])));

    prop('ends_with(pre + suf, suf) always holds',
        gen.tuple(gen.string({max_len: 15}), gen.string({max_len: 15})),
        (p) => assert.match(truthy(), ends_with(p[0] + p[1], p[1])));
});
