import kapsis
import ./commands/[newCommand, buildCommand]

App:
  about:
    "Denim 🔥 Create powerful native NodeJS addons powered by Nim language."

  commands:
    $ "new" `project`:
      ? "Create a new Nimble project"
    $ "build" `entry` "--release":
      ? "Build Nim project to a native NodeJS addon"
