+++
title = "Primitives"
+++

# Primitives

| Glyph  | Primitive             | Stack Effect        |
| ------ | --------------------- | ------------------- |
| `.`    | Duplicate             | `x -- x x`          |
| `,`    | Drop                  | `x --`              |
| `~`    | Swap                  | `x y -- y x`        |
| `⫦`    | Over                  | `x y -- x y x`      |
| `⊪`    | Rotate stack          | `x y z -- z y x`    |
| `ι`    | Iota                  | `x -- [0..x]`       |
| `ρ`    | Shape                 | `x -- x$shape`      |
| `⧻`    | Length                | `x -- x$length`     |
| `△`    | Sort ascending        | `x -- x'`           |
| `▽`    | Sort descending       | `x -- x'`           |
| `□`    | Peek                  | `a n -- a[n]`       |
| `Ρ`    | Reshape               | `a s -- a'`         |
| `+`    | Add                   | `x y -- x+y`        |
| `-`    | Subtract              | `x y -- x-y`        |
| `×`    | Multiply              | `x y -- x×y`        |
| `÷`    | Div                   | `x y -- x/y`        |
| `*`    | Power                 | `x y -- x^y`        |
| `\|`    | Modulo                | `x y -- x\|y`        |
