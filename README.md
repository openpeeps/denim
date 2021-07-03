**Build native NodeJS addons powered by Nim.**

**Denim is a CLI tool for building native NodeJS addons powered by Clymene CLI Framework**. Also, Denim contains some work from Napi Nim from Andrei Rosca.

For using Denim you will need <code>node-gyp</code> module installed globally.
```bash
npm i -g node-gyp
# or using yarn
yarn global add node-gyp
```

On the Nim side, get Denim with Nimble
```bash
nimble install denim
```

# License
Denim is released under <code>MIT</code> license. Contains work of Andrei Rosca and is based on Clymene CLI framework (originally based on docopt package).