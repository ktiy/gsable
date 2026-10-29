# Description

Interpreter and graphical environment for the **sable** programming language.

# Installation

[zig][1] and [sdl3][2] are required on the machine to build this program.

```
$ zig build install --prefix ~/.local
```

# Documentation

- Source files must be UTF-8 encoded, and cannot be greater than 4.2GB in size
- The interpreter cannot open more than 256 files at once
- Tokens may not be larger than 512 bytes

[1]: https://ziglang.org
[2]: https://wiki.libsdl.org/SDL3/FrontPage
