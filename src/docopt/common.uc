'use strict';

function join(arr, sep) {
    let r = '';
    for (let i = 0; i < length(arr); i++) {
        if (i > 0) r += sep;
        r += arr[i];
    }
    return r;
};

function arr_find(arr, fn) {
    let r = filter(arr, fn);
    return length(r) > 0 ? r[0] : null;
};

function char_at(s, i) {
    return substr(s, i, 1);
};

function starts_with(s, pre) {
    return substr(s, 0, length(pre)) === pre;
};

function ends_with(s, suffix) {
    let sl = length(s);
    let el = length(suffix);
    if (sl < el) return false;
    return substr(s, sl - el) === suffix;
};

function is_ws(c) {
    return c === ' ' || c === '\t' || c === '\n' || c === '\r';
};

// Word is an ALL-CAPS positional argument if it has uppercase and no lowercase
function is_argument_word(word) {
    if (length(word) === 0) return false;
    return uc(word) === word && lc(word) !== word;
};

function ends_with_options(s) {
    let sl = length(s);
    let ol = length('options');
    if (sl < ol) return false;
    return lc(substr(s, sl - ol)) === 'options';
};

export {
    join,
    arr_find,
    char_at,
    starts_with,
    ends_with,
    is_ws,
    is_argument_word,
    ends_with_options
};
