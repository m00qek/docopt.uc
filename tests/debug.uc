'use strict';

// Test built-in join with various single-element and multi-element arrays
printf('join(["a"], ","): %J\n', join(['a'], ','));
printf('join(["a","b"], ","): %J\n', join(['a','b'], ','));
printf('join(",", ["a"]): %J\n', join(',', ['a']));
printf('join(",", ["a","b"]): %J\n', join(',', ['a','b']));

// Test what parse_testcases actually gets from the BUILT-IN join
// when called as join(array_of_1, '\n')
printf('\njoin(["single"], "\\n"): %J\n', join(['single'], '\n'));
printf('join(["a","b"], "\\n"): %J\n', join(['a','b'], '\n'));
printf('join(["user-error"], "\\n"): %J\n', join(['"user-error"'], '\n'));

// What does join return for wrong types?
printf('\ntype of join(["x"],","): %s\n', type(join(['x'], ',')));

// Does function lookup use definition-time or call-time scope?
function caller() {
    return defined_later();
}
function defined_later() {
    return "visible!";
}
try {
    printf('\ncaller() = %s\n', caller());
} catch(e) {
    printf('\ncaller() threw: %s\n', type(e)=='object'?e.message:e);
}
