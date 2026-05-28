'use strict';

import {
    parse_defaults,
    formal_usage,
    formal_usage_raw
} from 'docopt.scanner';

import {
    parse_pattern,
    opt_find_exact
} from 'docopt.parser';

import {
    fix_identities,
    fix_repeating_arguments,
    expand_options_shortcut,
    tokenize_argv,
    do_match
} from 'docopt.matcher';

import { unique_leaves } from 'docopt.ast';
import { starts_with } from 'docopt.common';
import * as fs from 'fs';

function docopt(doc, argv, help, version, options_first) {
    if (help == null) help = true;
    options_first = options_first ?? false;

    let options = parse_defaults(doc);

    // Tokenize early (best-effort) so stacked/aliased flags like -vh trigger help correctly
    let early_tokens;
    try {
        early_tokens = tokenize_argv(argv, options, false);
    } catch(e) {
        early_tokens = [];
    }

    // Help intercept
    if (help) {
        for (let tok in early_tokens) {
            if (tok.type === 'Option' && (tok.short === '-h' || tok.long === '--help')) {
                fs.stdout.write(trim(doc) + '\n');
                exit(0);
            }
        }
    }

    // Version intercept
    if (version != null) {
        for (let tok in early_tokens) {
            if (tok.type === 'Option' && tok.long === '--version') {
                fs.stdout.write(version + '\n');
                exit(0);
            }
        }
    }

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

    let argv_tokens;
    try {
        argv_tokens = tokenize_argv(argv, all_options, options_first);
    } catch (e) {
        let msg = (type(e) === 'object') ? e.message : e;
        if (type(msg) === 'string' && starts_with(msg, 'DocoptExit')) {
            warn(trim(formal_usage_raw(doc)) + '\n');
            exit(1);
        }
        die(e);
    }

    let r = do_match(pattern, argv_tokens, []);
    let matched   = r[0];
    let left      = r[1];
    let collected = r[2];

    if (!matched || length(left) > 0) {
        warn(trim(formal_usage_raw(doc)) + '\n');
        exit(1);
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
};

export { docopt };
