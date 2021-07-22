/**
 * Denim 'sprintf' Example
 * Bundles the original sprintf function from 'stdin.h' as a native NodeJS addon
 */
const sprintf = require('../build/sprintf.node')
let str = sprintf('Hey, this is $1, a great toolkit for creating fast $2 addons', 'Denim', 'NodeJS')
console.log(str)