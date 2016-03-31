## Common typeclasses definitions

type
  Eq* = concept x, y
    ## Equality class
    (x == y) is bool
    # We can't use ``!=`` here because of issue https://github.com/nim-lang/Nim/issues/4020

  Ord* = concept x, y
    ## Ordered class
    x is Eq and y is Eq
    (x < y) is bool
    (x <= y) is bool
    # We can't use ``>`` and ``>=`` here because of issue https://github.com/nim-lang/Nim/issues/4020
