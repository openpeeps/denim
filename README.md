**Denim is a CLI toolkit for building native NodeJS addons** without touching a line of C/C++. Denim is a reimplementation of [andi23rosca/napi-nim](https://github.com/andi23rosca/napi-nim), fully written in Nim. (WIP)

For using Denim you will need <code>node-gyp</code> module installed globally.
```bash
npm i -g node-gyp
# or using yarn
yarn global add node-gyp
```

Get the compiled version of Denim from latest release, or install the package from Nimble and compile it yourself
```bash
nimble install denim
# go to denim directory source and build the toolkit
nimble build
```

Once you have Denim installed on your system and set in your `PATH` you can simply call `denim -h` in your terminal and you get
```
Denim 🔥 Write native NodeJS addons powered by Nim.
For more info https://github.com/georgelemon/denim

Usage:
    denim new <project>                      Create a new Denim project by invoking "nimble init" 
    denim build <entry> [--release]          Compile your Nim project to a native NodeJS addon.
                                             Use "release" flag for compiling release version. 
    denim (-h | --help)
    denim (-v | --version)

Options:
    -h --help        Show this screen.
    -v --version     Show version.
```

**What's Nim?**
_Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim, and Nimble](https://nim-lang.org/)_

**Why Nim?**
Performance, fast compilation and C-like freedom. I want to keep code clean, readable, concise, and close to my intention. Also a very good language to learn in 2021.

# License
Denim is released under <code>MIT</code> license and contains work from Andrei Rosca `napi-nim` packkage. Denim is based on [Klymene - A CLI Framework written in Nim](https://github.com/georgelemon/klymene) for building beautiful command line interfaces for your projects.
