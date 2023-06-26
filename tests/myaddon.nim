import denim

proc getWelcomeMessage(): string =
  return "Hello, World!"

init proc(module: Module) =
  module.registerFn(0, "getWelcomeMessage"):
    return %* getWelcomeMessage()