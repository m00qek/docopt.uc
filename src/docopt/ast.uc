'use strict';

function Argument(name, value) {
    return { type: 'Argument', name: name, value: value ?? null };
};

function Command(name, value) {
    return { type: 'Command', name: name, value: value ?? false };
};

function Option(short, long, argcount, value) {
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

function Required(children)  { return { type: 'Required',  children: children }; };
function Optional(children)  { return { type: 'Optional',  children: children }; };
function OneOrMore(children) { return { type: 'OneOrMore', children: children }; };
function Either(children)    { return { type: 'Either',    children: children }; };
function OptionsShortcut()   { return { type: 'OptionsShortcut', children: [] }; };

let BRANCH_TYPES = { Required: 1, Optional: 1, OneOrMore: 1, Either: 1, OptionsShortcut: 1 };

function is_leaf(node)   { return !BRANCH_TYPES[node.type]; };
function is_branch(node) { return !!BRANCH_TYPES[node.type]; };

function node_key(node) {
    if (node.type === 'Option')   return sprintf('Option(%s,%s,%d)', node.short, node.long, node.argcount);
    if (node.type === 'Argument') return sprintf('Argument(%s)', node.name);
    if (node.type === 'Command')  return sprintf('Command(%s)', node.name);
    return node.type;
};

function flat(node) {
    if (is_leaf(node)) return [node];
    let r = [];
    for (let c in node.children) {
        let s = flat(c);
        for (let x in s) push(r, x);
    }
    return r;
};

function unique_leaves(node) {
    let leaves = flat(node);
    let seen = {};
    let r = [];
    for (let l in leaves) {
        let k = node_key(l);
        if (!seen[k]) { seen[k] = true; push(r, l); }
    }
    return r;
};

export {
    Argument,
    Command,
    Option,
    Required,
    Optional,
    OneOrMore,
    Either,
    OptionsShortcut,
    BRANCH_TYPES,
    is_leaf,
    is_branch,
    node_key,
    flat,
    unique_leaves
};
