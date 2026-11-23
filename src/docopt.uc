'use strict';

import {
    parse_defaults,
    formal_usage,
    usage_text
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

// The options in argv the doc does not know, when nothing matched: the
// likeliest reason (an unknown option fails the whole match).
function unknown_options(tokens, known) {
    return filter(tokens, t => t.type === 'Option' && !opt_find_exact(known, t.short, t.long));
}

// What is wrong with argv, from the tokens left unmatched (or, when the
// whole usage failed to match, the options the doc does not know): an
// option the doc knows is only out of place.
function what_is_wrong(left, known) {
    for (let t in left ?? []) {
        if (t.type === 'Option')
            return sprintf(opt_find_exact(known, t.short, t.long) ? 'unexpected option %s' : 'unknown option %s', t.long ?? t.short);
        if (t.type === 'Argument') return sprintf('unexpected argument %s', t.value);
    }
    return 'the arguments do not match the usage';
}

// A token that asks for help or the version: by the option's name (its long
// form, else its short one), so `-h` is not help when it is `--host`.
function asks(tokens, names) {
    for (let t in tokens)
        if (t.type === 'Option' && t.value && (t.name in names))
            return true;
    return false;
}

// The doc without its leading and trailing newlines, as the help prints it.
function strip_newlines(s) {
    let a = 0, b = length(s);
    while (a < b && substr(s, a, 1) === '\n') a++;
    while (b > a && substr(s, b - 1, 1) === '\n') b--;
    return substr(s, a, b - a);
}

/**
 * Parse command-line arguments according to a docopt-formatted help string,
 * without printing or exiting: the caller decides what each outcome does.
 *
 * Dies with DocoptLanguageError when doc itself is wrong (no usage section,
 * more than one, an unbalanced pattern): a bug of the program, not the user.
 *
 * @param {string} doc the help/usage string that defines the CLI interface
 * @param {list<string>} argv the argument list to parse (typically ARGV)
 * @param {?dict} [opts] { help = true, version = null, options_first = false }:
 *   help, report -h/--help; version, report --version (when non-null)
 * @returns {dict} one of { args }, { help: true }, { version: true }, or
 *   { error, usage }: what is wrong ("unknown option --foo") and the usage
 *   section as doc writes it, to print to stderr
 */
export function parse(doc, argv, opts) {
    opts = opts ?? {};
    let help = opts.help ?? true;
    let version = opts.version ?? null;
    let options_first = opts.options_first ?? false;

    // The doc first: a wrong one is an error whatever argv says.
    let usage = usage_text(doc);
    let options = parse_defaults(doc);
    let pattern = parse_pattern(formal_usage(doc), options);

    // Every option argv may name: the doc's and those only the usage has.
    let all_options = [...options];
    for (let po in filter(unique_leaves(pattern), l => l.type === 'Option')) {
        if (!opt_find_exact(all_options, po.short, po.long)) {
            push(all_options, po);
        }
    }

    // A usage that names [--] gets it reported; otherwise -- is accepted
    // anywhere and dropped.
    let names_dashdash = length(filter(unique_leaves(pattern), l => l.type === 'Command' && l.name === '--')) > 0;

    let argv_tokens;
    try {
        argv_tokens = tokenize_argv(argv, all_options, options_first, names_dashdash);
    } catch (e) {
        let msg = (type(e) === 'object') ? e.message : e;
        if (type(msg) === 'string' && starts_with(msg, 'DocoptExit'))
            return { error: replace(msg, /^DocoptExit: */, ''), usage: usage };
        die(e);
    }

    // As the reference: help and the version from the parsed options, before
    // matching, so they work whatever else argv holds.
    if (help && asks(argv_tokens, { '-h': true, '--help': true }))
        return { help: true };
    if (version !== null && asks(argv_tokens, { '--version': true }))
        return { version: true };

    expand_options_shortcut(pattern, options);
    pattern = fix_identities(pattern);
    pattern = fix_repeating_arguments(pattern);

    let r = do_match(pattern, argv_tokens, []);
    let matched   = r[0];
    let left      = r[1];
    let collected = r[2];

    if (!matched || length(left) > 0)
        return { error: what_is_wrong(matched ? left : unknown_options(argv_tokens, all_options), all_options), usage: usage };

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
 * prints what is wrong and the usage to stderr and exits 1. parse() does
 * neither.
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
        print(strip_newlines(doc), '\n');
        exit(0);
    }
    if (r.version) {
        print(version, '\n');
        exit(0);
    }
    if (r.error) {
        warn(r.error, '\n', r.usage, '\n');
        exit(1);
    }
    return r.args;
};
