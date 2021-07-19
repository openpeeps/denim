**Denim is a CLI toolkit for building native NodeJS addons** without touching a line of C/C++. Denim is a reimplementation of [andi23rosca/napi-nim](https://github.com/andi23rosca/napi-nim), fully written in Nim.

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

# Built with Denim
Here you can find some beautiful packages written in Nim and also built as NodeJS addon via Denim library

### Marvdown
A crazy fast, multi-threading markdown parser and AST generator, including some nice extra features and multiple export options like from Marvdown to `Markdown`, `HTML`, `TXT`, `PDF`.

Marvdown is available as Nim project, NodeJS addon and also as a binary package ready to be used as a standalone tool. [Check Marvdown.js repository](https://github.com/georgelemon/marvdown.js) or go to the main [Marvdown repo](https://github.com/georgelemon/marvdown)

### Bro
Bro is a kick-ass promise based HTTP/s Client that expose Nim's functionality for making fast requests, submissions and download data. [Check Bro repository](https://github.com/georgelemon/bro)

### Maryml
Similar to Marvdown, Maryml is a YAML parser and AST generator written in Nim and exposed to Node environment as a native addon. [Check Maryml](https://github.com/georgelemon/maryml.js) or [Maryml repository](https://github.com/georgelemon/maryml)

### Iconim
Fully written in Nim, exposed to Node environment as a native addon. Iconim is a super fast Server Side SVG Icon manager and rendered. Using Iconim you will save the visitor's browser from the effort required to download additional files or perform the rendering calculations. [Check Iconim.js](https://github.com/georgelemon/iconim.js) or [Iconim repository](https://github.com/iconim)


**What's Nim?**
_Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim, and Nimble](https://nim-lang.org/)_

**Why Nim?**
Performance, fast compilation and C-like freedom. I want to keep code clean, readable, concise, and close to my intention. Also a very good language to learn in 2021.

# License
Denim is released under <code>MIT</code> license and contains work from Andrei Rosca `napi-nim` packkage. Denim is based on [Klymene - A CLI Framework written in Nim](https://github.com/georgelemon/klymene) for building beautiful command line interfaces for your projects.