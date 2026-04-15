const nim = require('../../bin/example_promise.node')

async function x(num) {
  try {
    let xx = await nim.testPromise((1 + 1) * num)
    console.log('Resolved promise: ' + xx)
  } catch(e) {
    console.log('Oups! ' + e)
  }
}

x(4)
x(8)