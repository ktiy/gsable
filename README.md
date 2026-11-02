<img align="left" width="72" src="https://codeberg.org/kitty/gsable/raw/commit/dadd226e3ad178a71966e22b0b9ada161b8dce2d/assets/icon.png">

# gsable

Interpreter and graphical environment for the **sable** programming language. Work in progress!

## Installation

Ensure the following dependencies are installed on your machine:

- [zig v0.17.0][1]
- [SDL3][2]

Then, build the project from source.

```sh
# clone and cd into the repo
git clone https://codeberg.org/kitty/gsable
cd gsable

# build the project
zig build install --prefix=~/.local --release=fast
```

## Usage
The `sbl` binary can be used to run programs or an interactive REPL (read-eval-print-loop).

```sh
$ sbl --help
usage: sbl [options] [input-file...]

   -h, --help         Print this help message and exit.
   -v, --version      Print the version number and exit.
   -r, --repl         Run the sable repl.
   --verbose-ast      Dumps the parsed ast tree to stderr.
   --verbose-bc       Dumps the compiled bytecode to stderr.
```

## Documentation

**sable** is a simple concatenative programming language. It is stack-based like [forth][3], with dynamic types and [arrays][4] like [APL][5].

Here is simple example function that finds the mean value of an array:
```
avg ← .+´~⧻÷
```

## Interpreter Limitations

- Source files must be UTF-8 encoded, and cannot be greater than 4.2GB in size
- The interpreter cannot open more than 256 files at once
- Tokens may not be larger than 512 bytes

## License

This project is licensed under the AGPLv3 License. For details, see the [LICENSE](LICENSE) file that should have been included with this program. Otherwise, see [AGPLv3][6].


[1]: https://ziglang.org
[2]: https://wiki.libsdl.org/SDL3/FrontPage
[3]: https://en.wikipedia.org/wiki/Forth_(programming_language)
[4]: https://aplwiki.com/wiki/Array
[5]: https://en.wikipedia.org/wiki/APL_(nu.org/licenses/agpl-3.0.txtprogramming_language)
[6]: https://www.gnu.org/licenses/agpl-3.0.txt
