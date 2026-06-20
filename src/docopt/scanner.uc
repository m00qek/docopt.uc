'use strict';

import {
    char_at,
    starts_with,
    ends_with,
    is_ws,
    ends_with_options
} from 'docopt.common';

import { Option } from 'docopt.ast';

/**
 * Find all sections in doc whose header ends with name (case-insensitive).
 *
 * @param {string} doc the docstring to scan
 * @param {string} name section label to match (e.g. "usage", "options")
 * @returns {list<{header: string, body: string}>}
 */
export function find_sections(doc, name) {
    let results = [];
    let i = 0;
    let n = length(doc);

    while (i < n) {
        let j = i;
        while (j < n && (char_at(doc, j) === ' ' || char_at(doc, j) === '\t')) j++;

        let found_colon = -1;
        let k = j;
        while (k < n && char_at(doc, k) !== '\n') {
            if (char_at(doc, k) === ':') { found_colon = k; break; }
            k++;
        }

        if (found_colon >= 0) {
            let before_colon = lc(substr(doc, j, found_colon - j));
            let bc_trimmed = trim(before_colon);
            if (ends_with(bc_trimmed, name)) {
                let bk = found_colon + 1;
                let line_end = bk;
                while (line_end < n && char_at(doc, line_end) !== '\n') line_end++;
                let first = trim(substr(doc, bk, line_end - bk));
                bk = line_end < n ? line_end + 1 : n;

                let body_parts = [];
                if (length(first) > 0) push(body_parts, first);

                while (bk < n) {
                    let ls = bk;
                    let all_ws = true;
                    let lk = bk;
                    while (lk < n && char_at(doc, lk) !== '\n') {
                        if (!is_ws(char_at(doc, lk))) { all_ws = false; break; }
                        lk++;
                    }
                    if (all_ws) break;
                    let fc = char_at(doc, bk);
                    if (fc !== ' ' && fc !== '\t') break;
                    while (bk < n && char_at(doc, bk) !== '\n') bk++;
                    push(body_parts, substr(doc, ls, bk - ls));
                    if (bk < n) bk++;
                }

                push(results, { header: substr(doc, j, found_colon - j), body: join('\n', body_parts) });
                i = bk;
                continue;
            }
        }

        while (i < n && char_at(doc, i) !== '\n') i++;
        if (i < n) i++;
    }
    return results;
};

/**
 * Parse a single option definition line into an Option node.
 *
 * Continuation lines (separated by newlines within line) are treated as description text only.
 * Returns null if line does not start with a flag.
 *
 * @param {string} line option definition line, possibly with newline-separated continuation lines
 * @returns {?OptionNode}
 */
export function parse_option_line(line) {
    // Use only the first line for option syntax; continuation lines are description only
    let all_lines = split(line, '\n');
    let first = all_lines[0];
    let continuation = length(all_lines) > 1 ? join(' ', slice(all_lines, 1)) : '';

    let i = 0;
    let n = length(first);
    while (i < n && is_ws(char_at(first, i))) i++;
    if (i >= n || char_at(first, i) !== '-') return null;

    let opts_end = i;
    while (opts_end < n) {
        let c = char_at(first, opts_end);
        if (c === '\t') break;
        if (c === ' ' && opts_end + 1 < n && char_at(first, opts_end + 1) === ' ') break;
        opts_end++;
    }

    let opts_part = trim(substr(first, i, opts_end - i));
    let desc_part = trim(
        (opts_end < n ? trim(substr(first, opts_end)) : '') +
        (length(continuation) > 0 ? ' ' + continuation : '')
    );

    let short = null;
    let long  = null;
    let argcount = 0;

    let parts = split(opts_part, /[,= \t]+/);
    for (let p in parts) {
        p = trim(p);
        if (length(p) === 0) continue;
        if (starts_with(p, '--')) {
            long = p;
        } else if (starts_with(p, '-') && length(p) >= 2) {
            if (length(p) === 2) {
                short = p;
            } else {
                short = substr(p, 0, 2);
                argcount = 1;
            }
        } else if (length(p) > 0) {
            argcount = 1;
        }
    }

    if (long !== null) {
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
};

function parse_option_block(text) {
    let options = [];
    let lines = split(text, '\n');
    let current_block = null;
    for (let line in lines) {
        let trimmed = trim(line);
        if (starts_with(trimmed, '-')) {
            if (current_block !== null) {
                let opt = parse_option_line(current_block);
                if (opt) push(options, opt);
            }
            current_block = line;
        } else if (current_block !== null && length(trimmed) > 0) {
            current_block += '\n' + line;
        } else if (current_block !== null) {
            let opt = parse_option_line(current_block);
            if (opt) push(options, opt);
            current_block = null;
        }
    }
    if (current_block !== null) {
        let opt = parse_option_line(current_block);
        if (opt) push(options, opt);
    }
    return options;
}

/**
 * Parse all option definitions from doc's Options sections (or from the full doc if none exist).
 *
 * @param {string} doc the docstring to scan
 * @returns {list<OptionNode>}
 */
export function parse_defaults(doc) {
    let sections = find_sections(doc, 'options');

    if (length(sections) > 0) {
        let options = [];
        for (let s in sections) {
            for (let opt in parse_option_block(s.body)) {
                push(options, opt);
            }
        }
        return options;
    }

    // No explicit options section: flat-scan the doc (excluding the usage body)
    // to find option definitions without a header or indentation requirement.
    let usage_secs = find_sections(doc, 'usage');
    let before = doc;
    let after = '';
    if (length(usage_secs) > 0 && length(usage_secs[0].body) > 0) {
        let body = usage_secs[0].body;
        let pos = index(doc, body);
        if (pos >= 0) {
            before = substr(doc, 0, pos);
            after = substr(doc, pos + length(body));
        }
    }

    let options = [];
    for (let part in [before, after]) {
        let lines = split(part, '\n');
        let current_block = null;
        for (let line in lines) {
            let trimmed = trim(line);
            if (starts_with(trimmed, '-')) {
                if (current_block !== null) {
                    let opt = parse_option_line(current_block);
                    if (opt) push(options, opt);
                }
                current_block = line;
            } else if (current_block !== null && length(trimmed) > 0) {
                current_block += '\n' + line;
            } else if (current_block !== null) {
                let opt = parse_option_line(current_block);
                if (opt) push(options, opt);
                current_block = null;
            }
        }
        if (current_block !== null) {
            let opt = parse_option_line(current_block);
            if (opt) push(options, opt);
        }
    }
    return options;
};

/**
 * Extract the formal usage pattern from doc's Usage section as a docopt expression string.
 *
 * Dies with DocoptLanguageError if no Usage section is found.
 *
 * @param {string} doc the docstring to scan
 * @returns {string}
 */
export function formal_usage(doc) {
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
        let rest = join(' ', slice(toks, 1));
        push(patterns, rest);
    }
    if (length(patterns) === 0) return '( )';
    if (length(patterns) === 1) return '( ' + patterns[0] + ' )';
    return '( ' + join(' | ', patterns) + ' )';
};

/**
 * Extract the raw body text of doc's Usage section, or an empty string if not found.
 *
 * @param {string} doc the docstring to scan
 * @returns {string}
 */
export function formal_usage_raw(doc) {
    let sections = find_sections(doc, 'usage');
    if (length(sections) === 0) return '';
    return sections[0].body;
};
