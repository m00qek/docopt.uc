// Time to parse long argument lists, 100 to 16000 arguments, with 42 options
// described: `make bench`. Not a test: it asserts nothing.
'use strict';
import { parse } from 'docopt';
import * as fs from 'fs';
let opts = '';
for (let i = 0; i < 40; i++) opts += sprintf('  --opt%d  Option %d.\n', i, i);
const doc = 'Usage: prog [options] [-v]... [-o FILE]... <f>...\n\nOptions:\n  -v  V.\n  -o FILE  O.\n' + opts;
for (let n in [ 100, 1000, 4000, 16000 ]) {
	let argv = [];
	for (let i = 0; i < n; i++) push(argv, (i % 10 === 0) ? '-v' : (i % 10 === 1) ? '-o' : `file${i}`);
	let t0 = clock(true);
	let r = parse(doc, argv);
	let t1 = clock(true);
	let ms = ((t1[0] - t0[0]) * 1000) + ((t1[1] - t0[1]) / 1e6);
	print(sprintf('%6d args: %8.1f ms  (-v %d, -o %d, <f> %d)\n', n, ms, r.args['-v'], length(r.args['-o']), length(r.args['<f>'])));
}
