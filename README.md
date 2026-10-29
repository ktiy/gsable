# Description

Interpreter and graphical environment for the **sable** programming language.

# Installation

[zig][1] and [sdl3][2] are required on the machine to build this program.

```
$ zig build install --prefix ~/.local
```

# Documentation

**Sable** is a simple concatenative programming language. It is stack-based like [forth][3], with dynamic types and [arrays][4] like [APL][5].

Work in progress!

## Interpreter limitations

- Source files must be UTF-8 encoded, and cannot be greater than 4.2GB in size
- The interpreter cannot open more than 256 files at once
- Tokens may not be larger than 512 bytes

[1]: https://ziglang.org
[2]: https://wiki.libsdl.org/SDL3/FrontPage
[3]: https://en.wikipedia.org/wiki/Forth_(programming_language)
[4]: https://aplwiki.com/wiki/Array
[5]: https://en.wikipedia.org/wiki/APL_(programming_language)
