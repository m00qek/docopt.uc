'use strict';

/**
 * @typedef {{type: string, short: ?string, long: ?string, argcount: int, value: string|boolean|list<string>|null, name: ?string}} OptionNode
 */

/**
 * @typedef {{type: string, children: list<*>}} AstBranch
 */

/**
 * Create a positional argument AST leaf node.
 *
 * @param {?string} name argument name (e.g. "<file>"), or null for anonymous
 * @param {string|null} [value=null] initial captured value
 * @returns {{type: string, name: ?string, value: string|null}}
 */
export function Argument(name, value) {
    return { type: 'Argument', name: name, value: value ?? null };
};

/**
 * Create a command (subcommand keyword) AST leaf node.
 *
 * @param {string} name command keyword as it appears in the usage pattern
 * @param {boolean} [value=false] initial match state
 * @returns {{type: string, name: string, value: boolean}}
 */
export function Command(name, value) {
    return { type: 'Command', name: name, value: value ?? false };
};

/**
 * Create an option AST leaf node.
 *
 * @param {?string} short short flag (e.g. "-v"), or null
 * @param {?string} long long flag (e.g. "--verbose"), or null
 * @param {int} [argcount=0] number of option arguments (0 or 1)
 * @param {string|boolean|null} [value=false] default value; becomes null when argcount > 0 and no explicit default is set
 * @returns {OptionNode}
 */
export function Option(short, long, argcount, value) {
    argcount = argcount ?? 0;
    if (value === null) value = false;
    if (value === false && argcount) value = null;
    return {
        type: 'Option',
        short: short ?? null,
        long: long ?? null,
        argcount: argcount,
        value: value,
        name: long ?? short
    };
};

/**
 * Create a Required branch node: all children must match.
 *
 * @param {list<*>} children child pattern nodes
 * @returns {AstBranch}
 */
export function Required(children)  { return { type: 'Required',  children: children }; };

/**
 * Create an Optional branch node: children are matched greedily but not required.
 *
 * @param {list<*>} children child pattern nodes
 * @returns {AstBranch}
 */
export function Optional(children)  { return { type: 'Optional',  children: children }; };

/**
 * Create a OneOrMore branch node: the child pattern must match at least once.
 *
 * @param {list<*>} children child pattern nodes (single child expected)
 * @returns {AstBranch}
 */
export function OneOrMore(children) { return { type: 'OneOrMore', children: children }; };

/**
 * Create an Either branch node: exactly one child alternative must match.
 *
 * @param {list<*>} children child pattern alternatives
 * @returns {AstBranch}
 */
export function Either(children)    { return { type: 'Either',    children: children }; };

/**
 * Create an OptionsShortcut node representing the bare [options] placeholder in usage patterns.
 *
 * @returns {AstBranch}
 */
export function OptionsShortcut()   { return { type: 'OptionsShortcut', children: [] }; };

/**
 * Set of branch AST node type names mapped to 1 for O(1) membership tests.
 *
 * @type {dict<int>}
 */
export let BRANCH_TYPES = { Required: 1, Optional: 1, OneOrMore: 1, Either: 1, OptionsShortcut: 1 };

/**
 * Return true if node is a leaf (Argument, Command, or Option).
 *
 * @param {{type: string}} node AST node to test
 * @returns {boolean}
 */
export function is_leaf(node)   { return !BRANCH_TYPES[node.type]; };

/**
 * Return true if node is a branch (Required, Optional, OneOrMore, Either, or OptionsShortcut).
 *
 * @param {{type: string}} node AST node to test
 * @returns {boolean}
 */
export function is_branch(node) { return !!BRANCH_TYPES[node.type]; };

/**
 * Return a canonical string key that uniquely identifies node by its type and names.
 *
 * @param {{type: string, short: ?string, long: ?string, argcount: int, name: ?string}} node AST leaf node
 * @returns {string}
 */
export function node_key(node) {
    if (node.type === 'Option')   return sprintf('Option(%s,%s,%d)', node.short, node.long, node.argcount);
    if (node.type === 'Argument') return sprintf('Argument(%s)', node.name);
    if (node.type === 'Command')  return sprintf('Command(%s)', node.name);
    return node.type;
};

/**
 * Return the result-dict key for a leaf node — the name used in the parsed-args map.
 *
 * @param {{type: string, name: ?string}} node AST leaf node
 * @returns {?string}
 */
export function leaf_key(node) { return node.name; };

/**
 * Return a flat list of all leaf nodes reachable from node in depth-first order.
 *
 * @param {*} node root AST node
 * @returns {list<*>}
 */
export function flat(node) {
    if (is_leaf(node)) return [node];
    let r = [];
    for (let c in node.children) {
        let s = flat(c);
        for (let x in s) push(r, x);
    }
    return r;
};

/**
 * Return a deduplicated list of leaf nodes under node, preserving first-seen order.
 *
 * @param {*} node root AST node
 * @returns {list<*>}
 */
export function unique_leaves(node) {
    let leaves = flat(node);
    let seen = {};
    let r = [];
    for (let l in leaves) {
        let k = node_key(l);
        if (!seen[k]) { seen[k] = true; push(r, l); }
    }
    return r;
};
