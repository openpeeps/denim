const nim = require('../../bin/myexceptions.node')

try {
  nim.parseJSON("some bad json")
} catch(e) {
  console.error(e)
}

try {
  nim.myCatchable(1)
} catch(e) {
  console.log("Something went wrong")
}

nim.parseInt("some bad int") // uncaught exception with non-zero exit code 