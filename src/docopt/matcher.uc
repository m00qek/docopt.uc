'use strict';

import {
    starts_with,
    char_at,
    join,
    arr_find
} from 'docopt.common';

import {
    Required,
    Either,
    OneOrMore,
    Option,
    Argument,
    Command,
    is_branch,
    is_leaf,
    node_key,
    flat,
    unique_leaves
} from 'docopt.ast';

import {
    opt_find_exact,
    opt_find_prefix
} from 'docopt.parser';

/**
 * Flatten a pattern tree into an Either of Required sequences (the "transform" normal form).
 *
 * Each leaf sequence in the result represents one complete expansion of the original pattern.
 *
 * @param {*} pattern root AST node to transform
 * @returns {AstBranch}
 */
export function transform(pattern) {
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
};

/**
 * Replace each leaf in the pattern with the canonical instance from the deduplicated leaf set.
 *
 * This ensures that all references to the same logical option/argument share one object,
 * so value updates during matching are visible everywhere.
 *
 * @param {*} pattern root AST node to process
 * @param {?list<*>} [uniq=null] pre-computed unique leaf list; derived from pattern when null
 * @returns {*}
 */
export function fix_identities(pattern, uniq) {
    if (uniq === null) uniq = unique_leaves(pattern);

    if (is_leaf(pattern)) {
        let k = node_key(pattern);
        let found = arr_find(uniq, function(u) { return node_key(u) === k; });
        return found ?? pattern;
    }

    pattern.children = map(pattern.children, function(c) {
        return fix_identities(c, uniq);
    });
    return pattern;
};

/**
 * Convert the value field of repeated argument/option nodes to arrays, and counted flags to integers.
 *
 * Mutates the pattern in place and returns it.
 *
 * @param {*} pattern root AST node (should have fix_identities applied first)
 * @returns {*}
 */
export function fix_repeating_arguments(pattern) {
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
                        if (node.value === null || node.value === false) {
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
};

/**
 * Tokenize a command-line argument list into a flat list of AST leaf nodes.
 *
 * Handles long options (--foo, --foo=bar), short option stacks (-abc), -- separator,
 * and options_first mode. Dies with DocoptExit on unrecognized or ambiguous options.
 *
 * @param {list<string>} argv raw argument list to tokenize
 * @param {list<OptionNode>} options known options for resolution
 * @param {boolean} [options_first=false] stop parsing options after the first positional argument
 * @returns {list<*>}
 */
export function tokenize_argv(argv, options, options_first) {
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
            if (similar === null) {
                let matches = opt_find_prefix(options, long_name);
                if (length(matches) === 1) {
                    similar = matches[0];
                } else if (length(matches) > 1) {
                    die(sprintf('DocoptExit: %s is not a unique prefix: %s?',
                        long_name,
                        join(map(matches, function(o) { return o.long; }), ', ')));
                }
            }

            if (similar === null) {
                let argcount = (eq >= 0) ? 1 : 0;
                let o = Option(null, long_name, argcount, value ?? (argcount ? 1 : true));
                if (argcount && value === null) {
                    if (i < length(argv)) { o.value = argv[i]; i++; }
                    else die(sprintf('DocoptExit: %s requires argument', long_name));
                }
                push(tokens, o);
            } else {
                let o = Option(similar.short, similar.long, similar.argcount, similar.value);
                if (o.argcount === 0) {
                    if (value !== null)
                        die(sprintf('DocoptExit: %s must not have an argument', long_name));
                    o.value = true;
                } else {
                    if (value !== null) {
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
                if (similar === null) {
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
};

/**
 * Find the first token in left that matches pattern, returning [index, matched_node] or null.
 *
 * @param {*} pattern AST leaf node to match against
 * @param {list<*>} left remaining unmatched tokens
 * @returns {?list<*>}
 */
export function single_match(pattern, left) {
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
};

/**
 * Recursively match pattern against the token list, returning [matched, remaining, collected].
 *
 * @param {*} pattern AST node (branch or leaf) to match
 * @param {list<*>} left unmatched tokens remaining from the argv token list
 * @param {list<*>} collected matched nodes accumulated so far
 * @returns {list<*>}
 */
export function do_match(pattern, left, collected) {
    if (collected === null) collected = [];
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

    if (t === 'Argument' || t === 'Command' || t === 'Option') {
        let sm = single_match(pattern, left);
        if (sm === null) return [false, left, collected];

        let pos     = sm[0];
        let matched = sm[1];
        let new_left = [...slice(left, 0, pos), ...slice(left, pos + 1)];

        let same = arr_find(collected, function(cn) {
            return cn.type === t && cn.name === pattern.name;
        });

        let val = matched.value;
        if (type(pattern.value) === 'int') {
            val = (same !== null && type(same.value) === 'int') ? same.value + 1 : 1;
        } else if (type(pattern.value) === 'array') {
            let existing = (same !== null && type(same.value) === 'array') ? same.value : [];
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
        if (same !== null) {
            new_collected = map(collected, function(cn) {
                return cn === same ? new_node : cn;
            });
        } else {
            new_collected = [...collected, new_node];
        }

        return [true, new_left, new_collected];
    }

    return [false, left, collected];
};

/**
 * Replace every OptionsShortcut node in pattern with explicit Option children derived from options.
 *
 * Options already referenced elsewhere in the pattern are excluded to avoid duplication.
 * Mutates the pattern tree in place.
 *
 * @param {*} pattern root AST node to expand
 * @param {list<OptionNode>} options full set of known options
 * @param {?list<OptionNode>} [all_pattern_options=null] options already present in the pattern; derived when null
 */
export function expand_options_shortcut(pattern, options, all_pattern_options) {
    if (all_pattern_options === null) {
        let leaves = flat(pattern);
        all_pattern_options = filter(leaves, l => l.type === 'Option');
    }

    if (pattern.type === 'OptionsShortcut') {
        let filtered = filter(options, function(o) {
            return !arr_find(all_pattern_options, function(po) {
                return (o.short !== null && po.short === o.short) ||
                       (o.long !== null && po.long === o.long);
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
};
