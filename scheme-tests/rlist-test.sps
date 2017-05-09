;; SRFI 101 test suite adapted to SRFI 64 and (scheme rlist)

(import (scheme base)  (scheme write)
        (scheme rlist)
        (srfi 64))

(define (requals? c e)
  (let-values (((car-c cdr-c) (cond ((pair? c) (values (car c) (cdr c)))
                                    ((rpair? c) (values (rcar c) (rcdr c)))
                                    (else (values c c))))
               ((car-e cdr-e) (cond ((pair? e) (values (car e) (cdr e)))
                                    ((rpair? e) (values (rcar e) (rcdr e)))
                                    (else (values e e)))))
              (if (or (pair? c) (rpair? c))
                (and (requals? car-c car-e)
                     (requals? cdr-c cdr-e))
                (equal? c e))))

(define (rtest-equal a b) (test-assert (requals? a b)))

(test-begin "scheme-rlist")

(rtest-equal '(1 2 3) (rlist 1 2 3))

; pair?
(test-assert (rpair? (rcons 'a 'b)))
(test-assert (rpair? (rlist 'a 'b 'c)))
(test-assert (not (rpair? '())))
(test-assert (not (rpair? #(a b))))

; cons
(rtest-equal (rcons 'a '()) (list 'a))
(rtest-equal (rcons (rlist 'a) (rlist 'b 'c 'd))       
             (list (list 'a) 'b 'c 'd))
(rtest-equal (rcons "a" (rlist 'b 'c))
             (list "a" 'b 'c))
(rtest-equal (rcons 'a 3)
             (cons 'a 3))
(rtest-equal (rcons (rlist 'a 'b) 'c)
             (cons (list 'a 'b) 'c))

; car
(rtest-equal (rcar (rlist 'a 'b 'c))
             'a)
(rtest-equal (rlist->list (rcar (rlist (rlist 'a) 'b 'c 'd)))
             (list 'a))
(rtest-equal (rcar (rcons 1 2)) 1)
(test-error (rcar '()))


; cdr
(rtest-equal (rcdr (rlist (rlist 'a) 'b 'c 'd))
             (list 'b 'c 'd))
(rtest-equal (rcdr (rcons 1 2))
             2)
(test-error (rcdr '()))

; null?
(test-assert (eq? rnull? null?))
(test-assert (rnull? '()))
(rtest-equal (rnull? (rcons 1 2)) #f)
(rtest-equal (rnull? 4) #f)

; list?
(rtest-equal (rlist? (rlist 'a 'b 'c)) #t)
(rtest-equal (rlist? '()) #t)
(rtest-equal (rlist? (rcons 'a 'b)) #f)

; list
(rtest-equal (rlist 'a (+ 3 4) 'c)
             (list 'a 7 'c))
(rtest-equal (rlist) '())

; make-list
(rtest-equal (rlength (rmake-list 5)) 5)
(rtest-equal (rmake-list 5 0)
             (list 0 0 0 0 0))

; length
(rtest-equal (rlength (rlist 'a 'b 'c)) 3)
(rtest-equal (rlength (rlist 'a (rlist 'b) (rlist 'c))) 3)
(rtest-equal (rlength '()) 0)

; append
(rtest-equal (rappend (rlist 'x) (rlist 'y)) (list 'x 'y))
(rtest-equal (rappend (rlist 'a) (rlist 'b 'c 'd)) (list 'a 'b 'c 'd))
(rtest-equal (rappend (rlist 'a (rlist 'b)) (rlist (rlist 'c))) 
             (list 'a (list 'b) (list 'c)))
(rtest-equal (rappend (rlist 'a 'b) (rcons 'c 'd))
             (cons 'a (cons 'b (cons 'c 'd))))
(rtest-equal (rappend '() 'a) 'a)

; reverse
(rtest-equal (rreverse (rlist 'a 'b 'c))
             (list 'c 'b 'a))
(rtest-equal (rreverse (rlist 'a (rlist 'b 'c) 'd (rlist 'e (rlist 'f))))
             (list (list 'e (list 'f)) 'd (list 'b 'c) 'a))

; list-tail
(rtest-equal (rlist-tail (rlist 'a 'b 'c 'd) 2)
             (list 'c 'd))

; list-ref
(rtest-equal (rlist-ref (rlist 'a 'b 'c 'd) 2) 'c)

; list-set
(rtest-equal (rlist-set (rlist 'a 'b 'c 'd) 2 'x)
             (list 'a 'b 'x 'd))

; list-ref/update
(let-values (((a b) (rlist-ref/update (rlist 7 8 9 10) 2 -)))
            (rtest-equal a 9)
            (rtest-equal b (list 7 8 -9 10)))

; map
(rtest-equal (rmap rcadr (rlist (rlist 'a 'b) (rlist 'd 'e) (rlist 'g 'h)))
             (list 'b 'e 'h))
(rtest-equal (rmap (lambda (n) (expt n n))
                   (rlist 1 2 3 4 5))
             (list 1 4 27 256 3125))
(rtest-equal (rmap + (rlist 1 2 3) (rlist 4 5 6))
             (list 5 7 9))

; for-each
(rtest-equal (let ((v (make-vector 5)))
               (rfor-each (lambda (i)
                            (vector-set! v i (* i i)))
                          (rlist 0 1 2 3 4))
               v)
             '#(0 1 4 9 16))

; rlist->list
; list->rlist
(rtest-equal (rlist->list '()) '())
(rtest-equal (list->rlist '()) '())

(rtest-equal (rlist->list (rlist 1 2 3))
             (list 1 2 3))

(rtest-equal (list->rlist (list 1 2 3))
             (rlist 1 2 3))

(test-end)

