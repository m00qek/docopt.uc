'use strict';

import {
    join,
    char_at,
    starts_with,
    ends_with,
    is_ws,
    ends_with_options
} from 'docopt.common';

import { Option } from 'docopt.ast';

function find_sections(doc, name) {
    let results = [];
    let i = 0;
    let n = length(doc);
    let nl = length(name);

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

                push(results, { header: substr(doc, j, found_colon - j), body: join(body_parts, '\n') });
                i = bk;
                continue;
            }
        }

        while (i < n && char_at(doc, i) !== '\n') i++;
        if (i < n) i++;
    }
    return results;
};

function parse_option_line(line) {
    let i = 0;
    let n = length(line);
    while (i < n && is_ws(char_at(line, i))) i++;
    if (i >= n || char_at(line, i) !== '-') return null;

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
};

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
};

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
        let rest = join(slice(toks, 1), ' ');
        push(patterns, rest);
    }
    if (length(patterns) === 0) return '( )';
    if (length(patterns) === 1) return '( ' + patterns[0] + ' )';
    return '( ' + join(patterns, ' | ') + ' )';
};

function formal_usage_raw(doc) {
    let sections = find_sections(doc, 'usage');
    if (length(sections) === 0) return '';
    return sections[0].body;
};

export {
    find_sections,
    parse_option_line,
    parse_defaults,
    formal_usage,
    formal_usage_raw
};
