;; -*- Mode: Irken -*-

(include "lib/core.scm")

(define thing1 {a=1 b=#\b c="c"})
(define thing2 {c="hey" b=#\b a=12})

(set! thing2.c "there")
(set! thing1.a 34)

(print thing1)
(print thing2)
(print thing1.a)
(print thing2.c)

