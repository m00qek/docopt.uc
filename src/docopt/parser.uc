'use strict';

import {
    is_ws,
    char_at,
    starts_with,
    ends_with,
    is_argument_word
} from 'docopt.common';

import {
    Argument,
    Command,
    Option,
    Required,
    Optional,
    OneOrMore,
    Either,
    OptionsShortcut
} from 'docopt.ast';

let TT = {
    LPAREN:   'LPAREN',
    RPAREN:   'RPAREN',
    LBRACKET: 'LBRACKET',
    RBRACKET: 'RBRACKET',
    PIPE:     'PIPE',
    ELLIPSIS: 'ELLIPSIS',
    OPTIONS:  'OPTIONS',
    SHORT:    'SHORT',
    LONG:     'LONG',
    ARGUMENT: 'ARGUMENT',
    COMMAND:  'COMMAND'
};

function tok(type, value) { return { type: type, value: value }; };

function tokenize_pattern(src) {
    let tokens = [];
    let i = 0;
    let n = length(src);

    while (i < n) {
        while (i < n && is_ws(char_at(src, i))) i++;
        if (i >= n) break;

        let c = char_at(src, i);

        if (c === '(') { push(tokens, tok(TT.LPAREN,   '(')); i++; continue; }
        if (c === ')') { push(tokens, tok(TT.RPAREN,   ')')); i++; continue; }
        if (c === '[') { push(tokens, tok(TT.LBRACKET, '[')); i++; continue; }
        if (c === ']') { push(tokens, tok(TT.RBRACKET, ']')); i++; continue; }
        if (c === '|') { push(tokens, tok(TT.PIPE,     '|')); i++; continue; }

        if (c === '.' && i + 2 < n && char_at(src, i+1) === '.' && char_at(src, i+2) === '.') {
            push(tokens, tok(TT.ELLIPSIS, '...'));
            i += 3;
            continue;
        }

        if (c === '<') {
            let start = i;
            i++;
            while (i < n && char_at(src, i) !== '>') i++;
            if (i < n) {
                i++;
                let word = substr(src, start, i - start);
                push(tokens, tok(TT.ARGUMENT, word));
                continue;
            }
            i = start;
        }

        let w_start = i;
        while (i < n) {
            let wc = char_at(src, i);
            if (is_ws(wc) || wc === '(' || wc === ')' || wc === '[' || wc === ']' || wc === '|') break;
            if (wc === '.' && i + 2 < n && char_at(src, i+1) === '.' && char_at(src, i+2) === '.') break;
            if (wc === '<') {
                while (i < n && char_at(src, i) !== '>') i++;
                if (i < n) i++;
                continue;
            }
            i++;
        }
        let word = substr(src, w_start, i - w_start);
        if (length(word) === 0) { i++; continue; }

        if (lc(word) === 'options') {
            push(tokens, tok(TT.OPTIONS, word));
        } else if (starts_with(word, '--') && length(word) > 2) {
            push(tokens, tok(TT.LONG, word));
        } else if (starts_with(word, '-') && length(word) >= 2 && char_at(word, 1) !== '-') {
            push(tokens, tok(TT.SHORT, word));
        } else if (starts_with(word, '<') && ends_with(word, '>')) {
            push(tokens, tok(TT.ARGUMENT, word));
        } else if (is_argument_word(word)) {
            push(tokens, tok(TT.ARGUMENT, word));
        } else {
            push(tokens, tok(TT.COMMAND, word));
        }
    }
    return tokens;
};

function make_token_stream(tokens) {
    let pos = [0];
    return {
        _pos: pos,
        _tokens: tokens,
        peek: function() {
            if (pos[0] < length(tokens)) return tokens[pos[0]];
            return null;
        },
        next: function() {
            let t = null;
            if (pos[0] < length(tokens)) { t = tokens[pos[0]]; pos[0]++; }
            return t;
        },
        expect: function(type) {
            let t = null;
            if (pos[0] < length(tokens)) { t = tokens[pos[0]]; pos[0]++; }
            if (t == null || t.type !== type)
                die(sprintf('DocoptLanguageError: expected %s, got %s', type, t ? t.type : 'EOF'));
            return t;
        }
    };
};

function opt_find_exact(options, short, long) {
    for (let o in options) {
        if ((short != null && o.short === short) ||
            (long  != null && o.long  === long)) return o;
    }
    return null;
};

function opt_find_prefix(options, prefix) {
    return filter(options, function(o) {
        return o.long != null && starts_with(o.long, prefix);
    });
};

function parse_long_in_pattern(word, options) {
    let eq = index(word, '=');
    let long_name, has_arg;
    if (eq >= 0) {
        long_name = substr(word, 0, eq);
        has_arg = true;
    } else {
        long_name = word;
        has_arg = false;
    }

    let similar = opt_find_exact(options, null, long_name);
    if (similar == null) {
        let matches = opt_find_prefix(options, long_name);
        if (length(matches) === 1) similar = matches[0];
    }

    if (similar == null) {
        return Option(null, long_name, has_arg ? 1 : 0, false);
    }
    return Option(similar.short, similar.long, similar.argcount, similar.value);
};

function parse_short_in_pattern(word, options) {
    let chars = substr(word, 1);
    let result = [];
    let i = 0;
    let n = length(chars);
    while (i < n) {
        let short = '-' + char_at(chars, i);
        i++;
        let similar = opt_find_exact(options, short, null);
        if (similar == null) {
            push(result, Option(short, null, 0, false));
        } else {
            let o = Option(similar.short, similar.long, similar.argcount, similar.value);
            if (o.argcount && i < n) {
                o.value = substr(chars, i);
                i = n;
            }
            push(result, o);
        }
    }
    return result;
};

let parse_pattern_expr, parse_pattern_seq, parse_pattern_atom;

parse_pattern_atom = function(ts, options) {
    let t = ts.peek();
    if (t == null) return [];

    if (t.type === TT.LPAREN) {
        ts.next();
        let children = parse_pattern_expr(ts, options);
        ts.expect(TT.RPAREN);
        return [Required(children)];
    }

    if (t.type === TT.LBRACKET) {
        ts.next();
        let p = ts.peek();
        if (p != null && p.type === TT.OPTIONS) {
            ts.next();
            ts.expect(TT.RBRACKET);
            return [Optional([OptionsShortcut()])];
        }
        let children = parse_pattern_expr(ts, options);
        ts.expect(TT.RBRACKET);
        return [Optional(children)];
    }

    if (t.type === TT.OPTIONS) {
        ts.next();
        return [OptionsShortcut()];
    }

    if (t.type === TT.LONG) {
        ts.next();
        return [parse_long_in_pattern(t.value, options)];
    }

    if (t.type === TT.SHORT) {
        ts.next();
        return parse_short_in_pattern(t.value, options);
    }

    if (t.type === TT.ARGUMENT) {
        ts.next();
        return [Argument(t.value, null)];
    }

    if (t.type === TT.COMMAND) {
        ts.next();
        return [Command(t.value, false)];
    }

    return [];
};

parse_pattern_seq = function(ts, options) {
    let result = [];
    let stop = { RPAREN: 1, RBRACKET: 1, PIPE: 1 };
    while (true) {
        let t = ts.peek();
        if (t == null || stop[t.type]) break;
        let atoms = parse_pattern_atom(ts, options);

        if (length(atoms) > 0) {
            let last = atoms[length(atoms) - 1];
            if (last.type === 'Option') {
                let next = ts.peek();
                if (next != null && next.type === TT.ARGUMENT) {
                    let similar = opt_find_exact(options, last.short, last.long);
                    if (similar == null || similar.argcount > 0) {
                        ts.next();
                        last.argcount = 1;
                        if (last.value === false) last.value = null;
                    }
                }
            }
        }

        let p = ts.peek();
        if (p != null && p.type === TT.ELLIPSIS) {
            ts.next();
            for (let a in atoms) push(result, OneOrMore([a]));
        } else {
            for (let a in atoms) push(result, a);
        }
    }
    return result;
};

parse_pattern_expr = function(ts, options) {
    let seq = parse_pattern_seq(ts, options);
    let seqs = [seq];
    while (true) {
        let t = ts.peek();
        if (t == null || t.type !== TT.PIPE) break;
        ts.next();
        push(seqs, parse_pattern_seq(ts, options));
    }
    if (length(seqs) === 1) return seqs[0];
    return [Either(map(seqs, function(s) { return Required(s); }))];
};

function parse_pattern(source, options) {
    let tokens = tokenize_pattern(source);
    let ts = make_token_stream(tokens);
    let result = parse_pattern_expr(ts, options);
    return Required(result);
};

export {
    TT,
    tok,
    tokenize_pattern,
    make_token_stream,
    opt_find_exact,
    opt_find_prefix,
    parse_long_in_pattern,
    parse_short_in_pattern,
    parse_pattern_atom,
    parse_pattern_seq,
    parse_pattern_expr,
    parse_pattern
};
