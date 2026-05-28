'use strict';

// ─── 1. UTILITIES ────────────────────────────────────────────────────────────

function join(arr, sep) {
    let r = '';
    for (let i = 0; i < length(arr); i++) {
        if (i > 0) r += sep;
        r += arr[i];
    }
    return r;
}

function arr_find(arr, fn) {
    let r = filter(arr, fn);
    return length(r) > 0 ? r[0] : null;
}

function char_at(s, i) {
    return substr(s, i, 1);
}

function starts_with(s, pre) {
    return substr(s, 0, length(pre)) === pre;
}

function ends_with(s, suffix) {
    let sl = length(s);
    let el = length(suffix);
    if (sl < el) return false;
    return substr(s, sl - el) === suffix;
}

function is_ws(c) {
    return c === ' ' || c === '\t' || c === '\n' || c === '\r';
}

// Word is an ALL-CAPS positional argument if it has uppercase and no lowercase
function is_argument_word(word) {
    if (length(word) === 0) return false;
    return uc(word) === word && lc(word) !== word;
}

function ends_with_options(s) {
    let sl = length(s);
    let ol = length('options');
    if (sl < ol) return false;
    return substr(s, sl - ol) === 'options';
}

// ─── 2. AST NODE CONSTRUCTORS ────────────────────────────────────────────────

function Argument(name, value) {
    return { type: 'Argument', name: name, value: value ?? null };
}

function Command(name, value) {
    return { type: 'Command', name: name, value: value ?? false };
}

function Option(short, long, argcount, value) {
    argcount = argcount ?? 0;
    if (value == null) value = false;
    if (value === false && argcount) value = null;
    return {
        type: 'Option',
        short: short ?? null,
        long: long ?? null,
        argcount: argcount,
        value: value,
        name: long ?? short
    };
}

function Required(children)  { return { type: 'Required',  children: children }; }
function Optional(children)  { return { type: 'Optional',  children: children }; }
function OneOrMore(children) { return { type: 'OneOrMore', children: children }; }
function Either(children)    { return { type: 'Either',    children: children }; }
function OptionsShortcut()   { return { type: 'OptionsShortcut', children: [] }; }

// ─── 3. NODE HELPERS ─────────────────────────────────────────────────────────

let BRANCH_TYPES = { Required: 1, Optional: 1, OneOrMore: 1, Either: 1, OptionsShortcut: 1 };

function is_leaf(node)   { return !BRANCH_TYPES[node.type]; }
function is_branch(node) { return !!BRANCH_TYPES[node.type]; }

function node_key(node) {
    if (node.type === 'Option')   return sprintf('Option(%s,%s,%d)', node.short, node.long, node.argcount);
    if (node.type === 'Argument') return sprintf('Argument(%s)', node.name);
    if (node.type === 'Command')  return sprintf('Command(%s)', node.name);
    return node.type;
}

function flat(node) {
    if (is_leaf(node)) return [node];
    let r = [];
    for (let c in node.children) {
        let s = flat(c);
        for (let x in s) push(r, x);
    }
    return r;
}

function unique_leaves(node) {
    let leaves = flat(node);
    let seen = {};
    let r = [];
    for (let l in leaves) {
        let k = node_key(l);
        if (!seen[k]) { seen[k] = true; push(r, l); }
    }
    return r;
}

// ─── 4. SECTION FINDER ───────────────────────────────────────────────────────

// Returns array of {header, body} where header is the section name (case-preserving)
// and body is all the text belonging to the section.
function find_sections(doc, name) {
    let results = [];
    let i = 0;
    let n = length(doc);
    let nl = length(name);

    while (i < n) {
        // skip leading spaces/tabs on this line
        let j = i;
        while (j < n && (char_at(doc, j) === ' ' || char_at(doc, j) === '\t')) j++;

        // check if the line contains 'name' followed eventually by ':'
        // scan to ':' or newline
        let found_colon = -1;
        let k = j;
        while (k < n && char_at(doc, k) !== '\n') {
            if (char_at(doc, k) === ':') { found_colon = k; break; }
            k++;
        }

        if (found_colon >= 0) {
            // The part before the colon should end with our name
            let before_colon = lc(substr(doc, j, found_colon - j));
            // trim trailing spaces
            let bc_trimmed = trim(before_colon);
            if (ends_with(bc_trimmed, name)) {
                // We have a match. Collect body.
                let bk = found_colon + 1;
                // rest of first line
                let line_end = bk;
                while (line_end < n && char_at(doc, line_end) !== '\n') line_end++;
                let first = trim(substr(doc, bk, line_end - bk));
                bk = line_end < n ? line_end + 1 : n;

                let body_parts = [];
                if (length(first) > 0) push(body_parts, first);

                while (bk < n) {
                    let ls = bk;
                    // check if blank line
                    let all_ws = true;
                    let lk = bk;
                    while (lk < n && char_at(doc, lk) !== '\n') {
                        if (!is_ws(char_at(doc, lk))) { all_ws = false; break; }
                        lk++;
                    }
                    if (all_ws) break;
                    // stop if line starts with non-whitespace (new section/paragraph)
                    let fc = char_at(doc, bk);
                    if (fc !== ' ' && fc !== '\t') break;
                    while (bk < n && char_at(doc, bk) !== '\n') bk++;
                    push(body_parts, substr(doc, ls, bk - ls));
                    if (bk < n) bk++;
                }

                push(results, { header: substr(doc, j, found_colon - j), body: join(body_parts, '\n') });
                i = bk;
                continue;
            }
        }

        // advance to next line
        while (i < n && char_at(doc, i) !== '\n') i++;
        if (i < n) i++;
    }
    return results;
}

// ─── 5. OPTION PARSING ───────────────────────────────────────────────────────

// Parse one options-section line. Returns Option node or null.
function parse_option_line(line) {
    let i = 0;
    let n = length(line);
    while (i < n && is_ws(char_at(line, i))) i++;
    if (i >= n || char_at(line, i) !== '-') return null;

    // Split at 2+ spaces or tab: left = options spec, right = description
    let opts_end = i;
    while (opts_end < n) {
        let c = char_at(line, opts_end);
        if (c === '\t') break;
        if (c === ' ' && opts_end + 1 < n && char_at(line, opts_end + 1) === ' ') break;
        opts_end++;
    }

    let opts_part = trim(substr(line, i, opts_end - i));
    let desc_part = opts_end < n ? trim(substr(line, opts_end)) : '';

    let short = null;
    let long  = null;
    let argcount = 0;

    // Split opts_part by commas and spaces
    let parts = split(opts_part, /[,= \t]+/);
    for (let p in parts) {
        p = trim(p);
        if (length(p) === 0) continue;
        if (starts_with(p, '--')) {
            // strip trailing angle-bracket arg: --path=<p> already split on '='
            long = p;
        } else if (starts_with(p, '-') && length(p) >= 2) {
            if (length(p) === 2) {
                short = p;
            } else {
                // -pPATH form
                short = substr(p, 0, 2);
                argcount = 1;
            }
        } else if (length(p) > 0) {
            // standalone word = argument name
            argcount = 1;
        }
    }

    // strip angle brackets from long option name
    if (long != null) {
        let lt = index(long, '<');
        if (lt >= 0) { long = trim(substr(long, 0, lt)); argcount = 1; }
    }

    let value = false;
    if (argcount) {
        value = null;
        let dm = match(desc_part, /\[default:[ \t]*([^\]]*)\]/i);
        if (dm) value = trim(dm[1]);
    }

    return Option(short, long, argcount, value);
}

function parse_defaults(doc) {
    let options = [];
    let sections = find_sections(doc, 'options');
    for (let s in sections) {
        let lines = split(s.body, '\n');
        let current_block = '';
        for (let line in lines) {
            let trimmed = trim(line);
            if (starts_with(trimmed, '-')) {
                if (length(current_block) > 0) {
                    let opt = parse_option_line(current_block);
                    if (opt) push(options, opt);
                }
                current_block = line;
            } else if (length(current_block) > 0 && length(trimmed) > 0) {
                current_block += '\n' + line;
            }
        }
        if (length(current_block) > 0) {
            let opt = parse_option_line(current_block);
            if (opt) push(options, opt);
        }
    }
    return options;
}

// ─── 6. FORMAL USAGE ─────────────────────────────────────────────────────────

function formal_usage(doc) {
    let sections = find_sections(doc, 'usage');
    if (length(sections) === 0) {
        die('DocoptLanguageError: "usage:" section not found.');
    }
    let body = sections[0].body;
    let lines = split(body, '\n');
    let patterns = [];
    for (let line in lines) {
        line = trim(line);
        if (length(line) === 0) continue;
        let toks = split(line, /[ \t]+/);
        // skip first token (program name)
        let rest = join(slice(toks, 1), ' ');
        push(patterns, rest);
    }
    if (length(patterns) === 0) return '( )';
    if (length(patterns) === 1) return '( ' + patterns[0] + ' )';
    return '( ' + join(patterns, ' | ') + ' )';
}

function formal_usage_raw(doc) {
    let sections = find_sections(doc, 'usage');
    if (length(sections) === 0) return '';
    return sections[0].body;
}

// ─── 7. PATTERN TOKENIZER ────────────────────────────────────────────────────

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

function tok(type, value) { return { type: type, value: value }; }

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
            i = start; // backtrack if no closing >
        }

        // collect a word (stop at delimiter chars)
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
}

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
}

// ─── 8. OPTION LOOKUP HELPERS ────────────────────────────────────────────────

function opt_find_exact(options, short, long) {
    return arr_find(options, function(o) {
        return (short != null && o.short === short) ||
               (long  != null && o.long  === long);
    });
}

function opt_find_prefix(options, prefix) {
    return filter(options, function(o) {
        return o.long != null && starts_with(o.long, prefix);
    });
}

// ─── 9. LONG OPTION HELPERS ──────────────────────────────────────────────────

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
}

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
}

// ─── 10. RECURSIVE DESCENT PATTERN PARSER ───────────────────────────────────

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
}

// ─── 11. PATTERN TRANSFORMS ──────────────────────────────────────────────────

function transform(pattern) {
    let result = [];
    let queue = [[pattern]];

    while (length(queue) > 0) {
        let current = queue[0];
        splice(queue, 0, 1);

        let branch_idx = -1;
        for (let i = 0; i < length(current); i++) {
            if (is_branch(current[i])) { branch_idx = i; break; }
        }

        if (branch_idx < 0) {
            push(result, current);
        } else {
            let node   = current[branch_idx];
            let before = slice(current, 0, branch_idx);
            let after  = slice(current, branch_idx + 1);

            if (node.type === 'Either') {
                for (let c in node.children) {
                    push(queue, [...before, c, ...after]);
                }
            } else if (node.type === 'OneOrMore') {
                let c = node.children[0];
                push(queue, [...before, c, c, ...after]);
            } else {
                push(queue, [...before, ...node.children, ...after]);
            }
        }
    }

    return Either(map(result, function(seq) { return Required(seq); }));
}

function fix_identities(pattern, uniq) {
    if (uniq == null) uniq = unique_leaves(pattern);

    if (is_leaf(pattern)) {
        let k = node_key(pattern);
        let found = arr_find(uniq, function(u) { return node_key(u) === k; });
        return found ?? pattern;
    }

    pattern.children = map(pattern.children, function(c) {
        return fix_identities(c, uniq);
    });
    return pattern;
}

function fix_repeating_arguments(pattern) {
    let either_seqs = transform(pattern);

    for (let req in either_seqs.children) {
        let seq = req.children;
        let counts = {};
        for (let node in seq) {
            if (!is_leaf(node)) continue;
            let k = node_key(node);
            counts[k] = (counts[k] ?? 0) + 1;
        }
        for (let node in seq) {
            if (!is_leaf(node)) continue;
            let k = node_key(node);
            if (counts[k] > 1) {
                if (node.type === 'Argument' || (node.type === 'Option' && node.argcount > 0)) {
                    if (type(node.value) !== 'array') {
                        if (node.value == null || node.value === false) {
                            node.value = [];
                        } else {
                            node.value = split(node.value, /\s+/);
                        }
                    }
                }
                if (node.type === 'Command' || (node.type === 'Option' && node.argcount === 0)) {
                    if (type(node.value) !== 'int') {
                        node.value = 0;
                    }
                }
            }
        }
    }
    return pattern;
}

// ─── 12. ARGV TOKENIZER ──────────────────────────────────────────────────────

function tokenize_argv(argv, options, options_first) {
    options_first = options_first ?? false;
    let tokens = [];
    let parsing_opts = true;
    let i = 0;

    while (i < length(argv)) {
        let arg = argv[i];
        i++;

        if (arg === '--') {
            parsing_opts = false;
            continue;
        }

        if (parsing_opts && arg === '-') {
            push(tokens, Argument(null, '-'));
            continue;
        }

        if (parsing_opts && starts_with(arg, '--') && length(arg) > 2) {
            let eq = index(arg, '=');
            let long_name, value;
            if (eq >= 0) {
                long_name = substr(arg, 0, eq);
                value     = substr(arg, eq + 1);
            } else {
                long_name = arg;
                value     = null;
            }

            let similar = opt_find_exact(options, null, long_name);
            if (similar == null) {
                let matches = opt_find_prefix(options, long_name);
                if (length(matches) === 1) {
                    similar = matches[0];
                } else if (length(matches) > 1) {
                    die(sprintf('DocoptExit: %s is not a unique prefix: %s?',
                        long_name,
                        join(map(matches, function(o) { return o.long; }), ', ')));
                }
            }

            if (similar == null) {
                let argcount = (eq >= 0) ? 1 : 0;
                let o = Option(null, long_name, argcount, value ?? (argcount ? 1 : true));
                if (argcount && value == null) {
                    if (i < length(argv)) { o.value = argv[i]; i++; }
                    else die(sprintf('DocoptExit: %s requires argument', long_name));
                }
                push(tokens, o);
            } else {
                let o = Option(similar.short, similar.long, similar.argcount, similar.value);
                if (o.argcount === 0) {
                    if (value != null)
                        die(sprintf('DocoptExit: %s must not have an argument', long_name));
                    o.value = true;
                } else {
                    if (value != null) {
                        o.value = value;
                    } else if (i < length(argv)) {
                        o.value = argv[i]; i++;
                    } else {
                        die(sprintf('DocoptExit: %s requires argument', long_name));
                    }
                }
                push(tokens, o);
            }

        } else if (parsing_opts && starts_with(arg, '-') && length(arg) >= 2) {
            let j = 1;
            while (j < length(arg)) {
                let short = '-' + char_at(arg, j);
                j++;
                let similar = opt_find_exact(options, short, null);
                if (similar == null) {
                    push(tokens, Option(short, null, 0, true));
                } else {
                    let o = Option(similar.short, similar.long, similar.argcount, similar.value);
                    if (o.argcount === 0) {
                        o.value = true;
                        push(tokens, o);
                    } else {
                        if (j < length(arg)) {
                            o.value = substr(arg, j);
                            j = length(arg);
                        } else if (i < length(argv)) {
                            o.value = argv[i]; i++;
                        } else {
                            die(sprintf('DocoptExit: %s requires argument', short));
                        }
                        push(tokens, o);
                    }
                }
            }
        } else {
            if (options_first) parsing_opts = false;
            push(tokens, Argument(null, arg));
        }
    }
    return tokens;
}

// ─── 13. PATTERN MATCHING ────────────────────────────────────────────────────

function single_match(pattern, left) {
    for (let i = 0; i < length(left); i++) {
        let token = left[i];
        if (pattern.type === 'Argument') {
            if (token.type === 'Argument') return [i, Argument(pattern.name, token.value)];
        } else if (pattern.type === 'Command') {
            if (token.type === 'Argument' && token.value === pattern.name)
                return [i, Command(pattern.name, true)];
        } else if (pattern.type === 'Option') {
            if (token.type === 'Option' && token.name === pattern.name)
                return [i, token];
        }
    }
    return null;
}

function do_match(pattern, left, collected) {
    if (collected == null) collected = [];
    let t = pattern.type;

    if (t === 'Required') {
        let l = left;
        let c = collected;
        for (let child in pattern.children) {
            let r = do_match(child, l, c);
            if (!r[0]) return [false, left, collected];
            l = r[1]; c = r[2];
        }
        return [true, l, c];
    }

    if (t === 'Optional' || t === 'OptionsShortcut') {
        let l = left;
        let c = collected;
        for (let child in pattern.children) {
            let r = do_match(child, l, c);
            if (r[0]) { l = r[1]; c = r[2]; }
        }
        return [true, l, c];
    }

    if (t === 'Either') {
        let outcomes = [];
        for (let child in pattern.children) {
            let r = do_match(child, left, collected);
            if (r[0]) push(outcomes, r);
        }
        if (length(outcomes) === 0) return [false, left, collected];
        let best = outcomes[0];
        for (let o in outcomes) {
            if (length(o[1]) < length(best[1])) best = o;
        }
        return best;
    }

    if (t === 'OneOrMore') {
        let child = pattern.children[0];
        let l = left;
        let c = collected;
        let prev_len = length(l) + 1;
        let matched_once = false;
        while (true) {
            let r = do_match(child, l, c);
            if (!r[0]) break;
            matched_once = true;
            if (length(r[1]) >= prev_len) break;
            prev_len = length(r[1]);
            l = r[1]; c = r[2];
        }
        if (!matched_once) return [false, left, collected];
        return [true, l, c];
    }

    // Leaf: Argument, Command, Option
    if (t === 'Argument' || t === 'Command' || t === 'Option') {
        let sm = single_match(pattern, left);
        if (sm == null) return [false, left, collected];

        let pos     = sm[0];
        let matched = sm[1];
        let new_left = [...slice(left, 0, pos), ...slice(left, pos + 1)];

        let same = arr_find(collected, function(cn) {
            if (t === 'Argument') return cn.type === 'Argument' && cn.name === pattern.name;
            if (t === 'Command')  return cn.type === 'Command'  && cn.name === pattern.name;
            if (t === 'Option')   return cn.type === 'Option'   && cn.name === pattern.name;
            return false;
        });

        let val = matched.value;
        if (type(pattern.value) === 'int') {
            val = (same != null && type(same.value) === 'int') ? same.value + 1 : 1;
        } else if (type(pattern.value) === 'array') {
            let existing = (same != null && type(same.value) === 'array') ? same.value : [];
            if (type(val) === 'array') {
                val = [...existing, ...val];
            } else {
                val = [...existing, val];
            }
        }

        let new_node;
        if (t === 'Argument')     new_node = Argument(pattern.name, val);
        else if (t === 'Command') new_node = Command(pattern.name, val);
        else new_node = Option(matched.short, matched.long, matched.argcount, val);

        let new_collected;
        if (same != null) {
            new_collected = map(collected, function(cn) {
                return cn === same ? new_node : cn;
            });
        } else {
            new_collected = [...collected, new_node];
        }

        return [true, new_left, new_collected];
    }

    return [false, left, collected];
}

// ─── 14. EXPAND OPTIONS SHORTCUT ─────────────────────────────────────────────

function expand_options_shortcut(pattern, options, all_pattern_options) {
    if (all_pattern_options == null) {
        let leaves = flat(pattern);
        all_pattern_options = filter(leaves, l => l.type === 'Option');
    }

    if (pattern.type === 'OptionsShortcut') {
        let filtered = filter(options, function(o) {
            return !arr_find(all_pattern_options, function(po) {
                return (o.short != null && po.short === o.short) ||
                       (o.long != null && po.long === o.long);
            });
        });
        pattern.children = map(filtered, function(o) {
            return Option(o.short, o.long, o.argcount, o.value);
        });
        return;
    }
    if (is_branch(pattern)) {
        for (let c in pattern.children) {
            expand_options_shortcut(c, options, all_pattern_options);
        }
    }
}

// ─── 15. MAIN DOCOPT FUNCTION ────────────────────────────────────────────────

function docopt(doc, argv, help) {
    if (help == null) help = true;

    let options = parse_defaults(doc);
    let usage_pattern_str = formal_usage(doc);
    let pattern = parse_pattern(usage_pattern_str, options);
    pattern = fix_identities(pattern);
    pattern = fix_repeating_arguments(pattern);
    expand_options_shortcut(pattern, options);

    let all_options = [...options];
    for (let po in filter(unique_leaves(pattern), l => l.type === 'Option')) {
        if (!opt_find_exact(all_options, po.short, po.long)) {
            push(all_options, po);
        }
    }
    let argv_tokens = tokenize_argv(argv, all_options, false);

    let r = do_match(pattern, argv_tokens, []);
    let matched   = r[0];
    let left      = r[1];
    let collected = r[2];

    if (!matched || length(left) > 0) {
        die(sprintf('DocoptExit: %s', trim(formal_usage_raw(doc))));
    }

    // Build result: start with pattern defaults, overwrite with collected
    let result = {};
    let leaves = unique_leaves(pattern);
    for (let l in leaves) {
        let key = l.name ?? l.long ?? l.short;
        if (key != null) result[key] = l.value;
    }
    for (let c in collected) {
        let key = c.name ?? c.long ?? c.short;
        if (key != null) result[key] = c.value;
    }

    return result;
}

export { docopt };
