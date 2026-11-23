'use strict';

import {
    char_at,
    starts_with,
    ends_with,
    is_ws
} from 'docopt.common';

import { Option } from 'docopt.ast';

/**
 * Find all sections in doc whose header ends with name (case-insensitive).
 *
 * A section runs from its header line to the first empty line, or the first
 * line that is not indented; a line of only spaces or tabs continues it, as
 * in the reference.
 *
 * @param {string} doc the docstring to scan
 * @param {string} name section label to match (e.g. "usage", "options")
 * @returns {list<{header: string, body: string, start: int, end: int}>} start
 *   and end: the section's place in doc, from its header to its last line
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

                let end = line_end;
                while (bk < n) {
                    let ls = bk;
                    let fc = char_at(doc, bk);
                    if (fc !== ' ' && fc !== '\t') break;
                    while (bk < n && char_at(doc, bk) !== '\n') bk++;
                    let line = substr(doc, ls, bk - ls);
                    // Spaces alone continue the section; they add no line.
                    if (length(trim(line)) > 0) {
                        push(body_parts, line);
                        end = bk;
                    }
                    if (bk < n) bk++;
                }

                push(results, { header: substr(doc, j, found_colon - j), body: join('\n', body_parts), start: j, end: end });
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

function option_defined(options, o) {
    for (let x in options)
        if ((o.short !== null && x.short === o.short) || (o.long !== null && x.long === o.long))
            return true;
    return false;
}

/**
 * Parse all option definitions from doc's Options sections (or from the full doc if none exist).
 *
 * @param {string} doc the docstring to scan
 * @returns {list<OptionNode>}
 */
export function parse_defaults(doc) {
    let blocks = [];
    let sections = find_sections(doc, 'options');

    if (length(sections) > 0) {
        for (let s in sections) push(blocks, s.body);
    } else {
        // No explicit options section: flat-scan the doc outside its usage
        // section to find option definitions without a header or
        // indentation requirement.
        let usage_secs = find_sections(doc, 'usage');
        if (length(usage_secs) > 0) {
            let u = usage_secs[0];
            push(blocks, substr(doc, 0, u.start), substr(doc, u.end));
        } else {
            push(blocks, doc);
        }
    }

    // An option defined twice is the first definition.
    let options = [];
    for (let b in blocks)
        for (let opt in parse_option_block(b))
            if (!option_defined(options, opt)) push(options, opt);
    return options;
};

// The one Usage section of doc; dies with DocoptLanguageError without one,
// or with more than one.
function usage_section(doc) {
    let sections = find_sections(doc, 'usage');
    if (length(sections) === 0)
        die('DocoptLanguageError: "usage:" section not found.');
    if (length(sections) > 1)
        die('DocoptLanguageError: more than one "usage:" section (case-insensitive).');
    return sections[0];
}

/**
 * Extract the formal usage pattern from doc's Usage section as a docopt expression string.
 *
 * The first word is the program's name; each time it appears again, a new
 * alternative starts, so a pattern may wrap onto indented lines (as in the
 * reference implementation).
 *
 * Dies with DocoptLanguageError if there is no Usage section, or more than one.
 *
 * @param {string} doc the docstring to scan
 * @returns {string}
 */
export function formal_usage(doc) {
    let words = filter(split(usage_section(doc).body, /\s+/), w => length(w) > 0);
    if (length(words) === 0) return '( )';
    let prog = words[0];
    let out = [];
    for (let w in slice(words, 1))
        push(out, w === prog ? ') | (' : w);
    return '( ' + join(' ', out) + ' )';
};

/**
 * The Usage section as doc writes it, header and indentation kept, for an
 * error message: "Usage:\n  prog a\n  prog b". Dies as formal_usage does.
 *
 * @param {string} doc the docstring to scan
 * @returns {string}
 */
export function usage_text(doc) {
    let u = usage_section(doc);
    return substr(doc, u.start, u.end - u.start);
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
