const nim = require('../../bin/myexceptions.node')

try {
  nim.parseJSON("some bad json")
} catch(e) {
  console.error(e)
}

nim.parseInt("some bad int")