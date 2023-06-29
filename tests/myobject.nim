import denim

type
  MySettings = object
    age: int
    name, location: string
    languages: seq[string]

var userSettings =
  MySettings(name: "John Doe", age: 31, location: "Europe",
    languages: @["Nim", "Python", "C", "JavaScript", "Zig", "Rust"])

init proc(module: Module) =
  # Convert Nim objects to NAPI objects.
  # Note that nim object must be defined outside of `Module`
  # to avoid:
  #   inconsistent typing for reintroduced symbol 'mysettings':
  var mySettings {.export_napi.} = %* userSettings