const nim = require('../../bin/mypromise.node')

async function x() {
  try {
    let xx = await nim.testPromise((1 + 1) * 4)
    console.log('Resolved promise: ' + xx)
  } catch(e) {
    console.log('Oups! ' + e)
  }
}

x()

// x() // todo: calling more than once will SIGSEGV: Illegal storage access.