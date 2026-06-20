'use strict';

/**
 * Return the first element of arr for which fn returns truthy, or null if none match.
 *
 * @param {list<*>} arr array to search
 * @param {(item: *) => boolean} fn predicate
 * @returns {*}
 */
export function arr_find(arr, fn) {
    let r = filter(arr, fn);
    return length(r) > 0 ? r[0] : null;
};

/**
 * Return the single character at index i in string s.
 *
 * @param {string} s source string
 * @param {int} i zero-based character index
 * @returns {string}
 */
export function char_at(s, i) {
    return substr(s, i, 1);
};

/**
 * Return true if s starts with pre.
 *
 * @param {string} s string to test
 * @param {string} pre prefix to match
 * @returns {boolean}
 */
export function starts_with(s, pre) {
    return substr(s, 0, length(pre)) === pre;
};

/**
 * Return true if s ends with suffix.
 *
 * @param {string} s string to test
 * @param {string} suffix suffix to match
 * @returns {boolean}
 */
export function ends_with(s, suffix) {
    let sl = length(s);
    let el = length(suffix);
    if (sl < el) return false;
    return substr(s, sl - el) === suffix;
};

/**
 * Return true if c is whitespace (space, tab, newline, or carriage return).
 *
 * @param {string} c single character to test
 * @returns {boolean}
 */
export function is_ws(c) {
    return c === ' ' || c === '\t' || c === '\n' || c === '\r';
};

// Word is an ALL-CAPS positional argument if it has uppercase and no lowercase
/**
 * Return true if word is written in ALL-CAPS and thus qualifies as a positional argument name.
 *
 * @param {string} word word to test
 * @returns {boolean}
 */
export function is_argument_word(word) {
    if (length(word) === 0) return false;
    return uc(word) === word && lc(word) !== word;
};

/**
 * Return true if the last seven characters of s spell "options" (case-insensitive).
 *
 * @param {string} s string to test
 * @returns {boolean}
 */
export function ends_with_options(s) {
    let sl = length(s);
    let ol = length('options');
    if (sl < ol) return false;
    return lc(substr(s, sl - ol)) === 'options';
};
