
(include "lib/core.scm")
(include "lib/pair.scm")
(include "lib/string.scm")
(include "lib/random.scm")
(include "lib/frb.scm")

(define (n-random n)
  (let loop ((n n)
	     (t (tree:empty)))
    (if (= n 0)
	t
	(loop (- n 1) (tree:insert t < (random) (random))))))

(define (print-kv k v)
  (print k)
  (print-string " ")
  (print v)
  (print-string "\n"))

(let ((t (n-random 20))
      (t2 (tree:insert (tree:empty) string-<? "howdy" 0))
      )
  (print-string "inorder:\n")
  (tree:inorder t print-kv)
  (print-string "reverse:\n")
  (tree:reverse t print-kv)
  ;(set! t2 (tree:insert t2 string-<? "howdy" 0))
  (set! t2 (tree:insert t2 string-<? "there" 2))
  ;(set! t2 (tree:insert t2 string-<? 0 3))
  (printn t2)
  )