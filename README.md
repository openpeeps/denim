<p align="center"><img src=".github/denim.png" height="242px" alt="DENIM - CLI Toolkit to build cool NodeJS addons Powered by NIM language"><br><strong>Denim is CLI toolkit for creating powerful NodeJS addons powered by NIM Language</strong>(WIP)</p>

Work in progress...

# Install
Get latest version of Denim from Github releases.

# Install from Source
```bash
# Get it form Github repository
nimble install https://github.com/openpeep/denim

# Build with release flag
nimble build -d:release
```

# Usage

### Add a Nimble task
Edit your Nimble file and add the following task

```python
task denim, "Compile to native NodeJS addon":
    exec "denim build src/project.nim"
```

### Expose Nim functionality

In your Nim project you can create whatever functionality you want and expose to NodeJS via NAPI bindings.

```python
import denim/napi/napibindings

init proc(module: Module) =

    # This is how you register a function.
    # 
    # The 1st parameter represents the number of arguments
    # should this function expect when called.
    # 
    # The 2nd parameter is the name of the function
    module.registerFn(1, "hello"):
        # All function args can be found in the args array.
        # 
        # They are stored as napi_values and you need to use
        # conversion methods such as getStr, getInt, getBool, etc. to 
        # get the equivalent Nim value
        echo "Hello " & args[0].getStr
```

### Compile your first .node addon
With Nimble task setup, you simply run

```zsh
nimble denim
```


## Built with Denim
_todo_

## Background

**What's Nim?**
_Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim, and Nimble](https://nim-lang.org/)_

**Why Nim?**
Performance, fast compilation and C-like freedom. I want to keep code clean, readable, concise, and close to my intention. Also a very good language to learn in 2021.

# License
This software is released under <code>MIT</code> license and contains work from Andrei Rosca `napi-nim` package. Denim is based on [Klymene - A CLI Framework written in Nim](https://github.com/georgelemon/klymene) for building beautiful command line interfaces for your projects.
