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

import { unique_leaves, leaf_key } from 'docopt.ast';
import { starts_with } from 'docopt.common';
import * as fs from 'fs';

// The options in argv the doc does not know, when nothing matched: the
// likeliest reason (an unknown option fails the whole match).
function unknown_options(tokens, known) {
    return filter(tokens, t => t.type === 'Option' && !opt_find_exact(known, t.short, t.long));
}

// What is wrong with argv, from the tokens left unmatched (or null when
// the whole usage failed to match).
function what_is_wrong(left) {
    for (let t in left ?? []) {
        if (t.type === 'Option') return sprintf('unknown option %s', t.long ?? t.short);
        if (t.type === 'Argument') return sprintf('unexpected argument %s', t.value);
    }
    return 'the arguments do not match the usage';
}

/**
 * Parse command-line arguments according to a docopt-formatted help string,
 * without printing or exiting: the caller decides what each outcome does.
 *
 * @param {string} doc the help/usage string that defines the CLI interface
 * @param {list<string>} argv the argument list to parse (typically ARGV)
 * @param {?dict} [opts] { help = true, version = null, options_first = false }:
 *   help, report -h/--help; version, report --version (when non-null)
 * @returns {dict} one of { args }, { help: true }, { version: true }, or
 *   { error, usage }: what is wrong ("unknown option --foo") and the usage
 *   section with its heading ("Usage: prog ..."), to print to stderr
 */
export function parse(doc, argv, opts) {
    opts = opts ?? {};
    let help = opts.help ?? true;
    let version = opts.version ?? null;
    let options_first = opts.options_first ?? false;

    let options = parse_defaults(doc);

    // Tokenize early (best-effort) so stacked/aliased flags like -vh trigger help correctly
    let early_tokens;
    try {
        early_tokens = tokenize_argv(argv, options, false);
    } catch(e) {
        early_tokens = [];
    }

    if (help) {
        for (let tok in early_tokens)
            if (tok.type === 'Option' && (tok.short === '-h' || tok.long === '--help'))
                return { help: true };
    }

    if (version !== null) {
        for (let tok in early_tokens)
            if (tok.type === 'Option' && tok.long === '--version')
                return { version: true };
    }

    let usage = 'Usage: ' + trim(formal_usage_raw(doc));
    let usage_pattern_str = formal_usage(doc);
    let pattern = parse_pattern(usage_pattern_str, options);
    pattern = fix_identities(pattern);
    expand_options_shortcut(pattern, options);
    pattern = fix_repeating_arguments(pattern);

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
        if (type(msg) === 'string' && starts_with(msg, 'DocoptExit'))
            return { error: replace(msg, /^DocoptExit: */, ''), usage: usage };
        die(e);
    }

    let r = do_match(pattern, argv_tokens, []);
    let matched   = r[0];
    let left      = r[1];
    let collected = r[2];

    if (!matched || length(left) > 0)
        return { error: what_is_wrong(matched ? left : unknown_options(argv_tokens, all_options)), usage: usage };

    let result = {};
    let leaves = unique_leaves(pattern);
    for (let l in leaves) {
        let key = leaf_key(l);
        if (key !== null) result[key] = l.value;
    }
    for (let c in collected) {
        let key = leaf_key(c);
        if (key !== null) result[key] = c.value;
    }

    return { args: result };
};

/**
 * Parse command-line arguments according to a docopt-formatted help string.
 * Prints the help or version and exits 0 when asked; on a usage error,
 * prints the usage to stderr and exits 1. parse() does neither.
 *
 * @param {string} doc the help/usage string that defines the CLI interface
 * @param {list<string>} argv the argument list to parse (typically ARGV)
 * @param {boolean} [help=true] print doc and exit when -h or --help is found
 * @param {?string} [version] print this string and exit when --version is found
 * @param {boolean} [options_first=false] stop option parsing at first positional argument
 * @returns {dict<string|boolean|list<string>>} map of argument names to their parsed values
 */
export function docopt(doc, argv, help, version, options_first) {
    if (help === null) help = true;
    let r = parse(doc, argv, { help: help, version: version, options_first: options_first ?? false });
    if (r.help) {
        fs.stdout.write(trim(doc) + '\n');
        exit(0);
    }
    if (r.version) {
        fs.stdout.write(version + '\n');
        exit(0);
    }
    if (r.error) {
        warn(trim(formal_usage_raw(doc)) + '\n');
        exit(1);
    }
    return r.args;
};
