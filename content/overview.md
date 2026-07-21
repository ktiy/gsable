+++
title = "Concatenative"
+++

# Overview

Sable is a **concatenative language**. Functions are applied to a shared stack rather than taking in their own arguments.

For example, in an applicative language, you might have this nesting of functions:
```
f(g(h(x)))
```

In Sable, this would be expressed as the following sequence of functions:
```
x h g f
```

Code is evaluated from left to right and from top to bottom.
