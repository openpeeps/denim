**Build native NodeJS addons powered by Nim.**

**Denim is a CLI toolkit for building native NodeJS addons**. Denim contains some work from Napi Nim by Andrei Rosca.

For using Denim you will need <code>node-gyp</code> module installed globally.
```bash
npm i -g node-gyp
# or using yarn
yarn global add node-gyp
```

Get the compiled version of Denim from latest release, or install the package from Nimble and compile it yourself
```bash
nimble install denim
```

Once you have Denim installed on your system and set in your `PATH` you can simply call `denim -h` in your terminal and you get
```bash
Denim 🧿 Write native NodeJS addons powered by Nim.

Usage:
    denim new <project>...  # Create a new Denim project invoking "nimble init" #
    denim build             # Compile Nim project to native NodeJS addon #
    denim (-h | --help)
    denim --version

Options:
    -h --help     Show this screen.
    --version     Show version.
```

# License
Denim is released under <code>MIT</code> license. Contains work of Andrei Rosca and is based on Clymene CLI framework (originally based on docopt package).