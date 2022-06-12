<p align="center">
    A small toolkit for building powerful native NodeJS addons using Nim language 👑
</p>

Work in progress...

# Install
Get latest version of Denim from Github releases.

# Install from Source
```bash
nimble install denim

# Build with release flag
nimble build -d:release
```

### Add a Nimble task
Edit your Nimble file and add the following task

```nim
task denim, "Compile to native NodeJS addon":
    exec "denim build src/project.nim"
```


### ❤ Contributions
If you like this project you can contribute to DENIM by opening new issues, fixing bugs, contribute with code, ideas and you can even [donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C) 🥰

### 👑 Discover Nim language
<strong>What's Nim?</strong> Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim language](https://nim-lang.org/)

<strong>Why Nim?</strong> Performance, fast compilation and C-like freedom. We want to keep code clean, readable, concise, and close to our intention. Also a very good language to learn in 2022.

### 🎩 License
DENIM is an Open Source Software released under `MIT` license. Based on [Andrei Rosca - napi-nim](https://github.com/andi23rosca/napi-nim). [Developed by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2022 OpenPeep & Contributors &mdash; All rights reserved.

<a href="https://hetzner.cloud/?ref=Hm0mYGM9NxZ4"><img src="https://openpeep.ro/banners/openpeep-footer.png" width="100%"></a>
