(import (scheme base)
        (scheme lseq)
        (srfi 64))

;; Make-generator for tests cloned from SRFI 121
(define (make-generator . args)
        (lambda () (if (null? args)
                       (eof-object)
                       (let ((next (car args)))
                            (set! args (cdr args))
                            next))))

;; Make-lseq creates an lseq, like list, but guarantees the use of a generator
(define (make-lseq . args) (generator->lseq (apply make-generator args)))

(define (factorial n)
  (cond
    ((< n 0) #f)
    ((= n 0) 1)
    (else (* n (factorial (- n 1))))))

(test-begin "scheme-lseq")

(test-group "lseqs"
            (test-group "lseqs/constructor"
                        (define one23 (make-lseq 1 2 3))
                        (test-equal 1 (car one23))
                        (test-assert (procedure? (cdr one23)))
                        (test-equal '(1 2 3) (lseq-realize one23))
                        ) ; end lseqs/constructor

            (test-group "lseqs/predicates"
                        (test-assert (lseq? '()))
                        (test-assert (lseq? '(1 2 3)))
                        (test-assert (lseq? (make-lseq 1 2 3)))
                        (test-assert (lseq? (cons 'x (lambda () 'x))))

                        (test-assert (lseq=? = '() '()))
                        (test-assert (lseq=? = '(1 2 3) '(1 2 3)))
                        (test-assert (lseq=? = (make-lseq 1 2 3)
                                             (make-lseq 1 2 3)))
                        (test-assert (lseq=? = (make-lseq 1 2 3) '(1 2 3)))
                        ) ; end lseqs/predicates

            (test-group "lseqs/selectors"
                        (test-error (lseq-car (make-generator)))
                        (test-equal 1 (lseq-car (make-lseq 1 2 3)))
                        (test-equal 1 (lseq-car '(1 2 3)))
                        (test-error (lseq-car 2))

                        (test-error (lseq-first (make-generator)))
                        (test-equal 1 (lseq-first (make-lseq 1 2 3)))
                        (test-equal 1 (lseq-first '(1 2 3)))
                        (test-error (lseq-first 2))

                        (test-error (lseq-cdr (make-generator)))
                        (test-equal 2 (lseq-cdr '(1 . 2)))
                        (test-equal 2 (lseq-car (lseq-cdr '(1 2 3))))
                        (test-equal 2 (lseq-car (lseq-cdr (make-lseq 1 2 3))))

                        (test-error (lseq-rest (make-generator)))
                        (test-equal 2 (lseq-rest '(1 . 2)))
                        (test-equal 2 (lseq-car (lseq-rest '(1 2 3))))
                        (test-equal 2 (lseq-car (lseq-rest (make-lseq 1 2 3))))
                        (test-error (lseq-rest 2))

                        (test-error (lseq-ref '() 0))
                        (test-equal 1 (lseq-ref '(1) 0))
                        (test-equal 2 (lseq-ref '(1 2) 1))
                        (test-error (lseq-ref (make-lseq) 0))
                        (test-equal 1 (lseq-ref (make-lseq 1) 0))
                        (test-equal 1 (lseq-ref (make-lseq 1 2) 0))
                        (test-equal 2 (lseq-ref (make-lseq 1 2) 1))

                        (test-error (lseq-take '() 1))
                        (test-error (lseq-take (make-lseq) 1))
                        (test-assert (procedure? (cdr (lseq-take '(1 2 3 4 5) 3)))) ; test laziness
                        (test-equal '(1 2 3) (lseq-realize (lseq-take '(1 2 3 4 5) 3)))

                        (test-error (lseq-drop '() 1))
                        (test-error (lseq-drop (make-lseq 1) 2))
                        (test-equal '(3 4 5) (lseq-realize (lseq-drop '(1 2 3 4 5) 2)))
                        (test-equal '(3 4 5) (lseq-realize (lseq-drop (make-lseq 1 2 3 4 5) 2)))
                        ) ; end lseqs/selectors

            (test-group "lseqs/whole"
                        (test-equal '() (lseq-realize '()))
                        (test-equal '(1 2 3) (lseq-realize '(1 2 3)))
                        (test-equal '() (lseq-realize (make-lseq)))
                        (test-equal '(1 2 3) (lseq-realize (make-lseq 1 2 3)))

                        (let ((g (lseq->generator '(1 2 3))))
                          (test-equal 1 (g))
                          (test-equal 2 (g))
                          (test-equal 3 (g))
                          (test-assert (eof-object? (g))))
                        (let ((g (lseq->generator (make-lseq 1 2 3))))
                          (test-equal 1 (g))
                          (test-equal 2 (g))
                          (test-equal 3 (g))
                          (test-assert (eof-object? (g))))

                        (test-equal 0 (lseq-length '()))
                        (test-equal 3 (lseq-length '(1 2 3)))
                        (test-equal 3 (lseq-length (make-lseq 1 2 3)))

                        (test-equal '(1 2 3 a b c) (lseq-realize (lseq-append '(1 2 3) '(a b c))))
                        (let ((one23abc (lseq-append (make-lseq 1 2 3) (make-lseq 'a 'b 'c))))
                          (test-assert (procedure? (cdr one23abc)))
                          (test-assert (lseq-realize one23abc))

                          (let ((one2345 (make-lseq 1 2 3 4 5))
                                (oddeven (make-lseq 'odd 'even 'odd 'even 'odd 'even 'odd 'even)))
                            (test-equal '((one 1 odd) (two 2 even) (three 3 odd))
                                        (lseq-realize (lseq-zip '(one two three) one2345 oddeven)))))
                        ) ; end lseqs/whole

            (test-group "lseqs/mapping"
                        (test-equal '() (lseq-map - '()))
                        (test-equal '(-1 -2 -3) (lseq-realize (lseq-map - '(1 2 3))))
                        (test-equal '(-1 -2 -3) (lseq-realize (lseq-map - (make-lseq 1 2 3))))
                        (test-assert (procedure? (cdr (lseq-map - '(1 2 3)))))

                        (let* ((output '())
                               (out! (lambda (x) (set! output (cons x output)))))
                          (lseq-for-each out! '())
                          (test-equal output '())
                          (lseq-for-each out! '(a b c))
                          (test-equal output '(c b a))
                          (lseq-for-each out! (make-lseq 1 2 3))
                          (test-equal output '(3 2 1 c b a)))

                        (test-equal '() (lseq-filter odd? '()))
                        (let ((odds (lseq-filter odd? '(1 2 3 4 5))))
                          (test-assert (procedure? (cdr odds)))
                          (test-equal '(1 3 5) (lseq-realize odds))
                          (test-equal '(1 3 5) (lseq-realize (lseq-filter odd? (make-lseq 1 2 3 4 5)))))

                        (test-equal '() (lseq-remove even? '()))
                        (let ((odds (lseq-remove even? '(1 2 3 4 5))))
                          (test-assert (procedure? (cdr odds)))
                          (test-equal '(1 3 5) (lseq-realize odds))
                          (test-equal '(1 3 5) (lseq-realize (lseq-remove even? (make-lseq 1 2 3 4 5)))))

                        ) ; end lseqs/mapping

            (test-group "lseqs/searching"
                        (test-equal 4 (lseq-find even? '(3 1 4 1 5 9 2 6)))
                        (test-equal 4 (lseq-find even? (make-lseq 3 1 4 1 5 9 2 6)))
                        (test-equal #f (lseq-find negative? (make-lseq 1 2 3 4 5)))

                        (test-equal '(-8 -5 0 0) (lseq-realize (lseq-find-tail even? '(3 1 37 -8 -5 0 0))))
                        (test-equal '(-8 -5 0 0) (lseq-realize (lseq-find-tail even?
                                                                               (make-lseq 3 1 37 -8 -5 0 0))))
                        (test-equal #f (lseq-find-tail even? '()))
                        (test-equal #f (lseq-find-tail negative? (make-lseq 1 2 3 4 5)))

                        (test-equal '(2 18) (lseq-realize (lseq-take-while even? '(2 18 3 10 22 9))))
                        (test-equal '(2 18) (lseq-realize (lseq-take-while even?
                                                                           (make-lseq 2 18 3 10 22 9))))
                        (test-equal '(2 18) (lseq-realize (lseq-take-while even?
                                                                           (make-lseq 2 18 3 10 22 9))))

                        (test-equal '(3 10 22 9) (lseq-drop-while even? '(2 18 3 10 22 9)))
                        (test-equal '(3 10 22 9) (lseq-realize (lseq-drop-while even?
                                                                                (make-lseq 2 18 3 10 22 9))))

                        (test-equal #t (lseq-any integer? '(a 3 b 2.7)))
                        (test-equal #t (lseq-any integer? (make-lseq 'a 3 'b 2.7)))
                        (test-equal #f (lseq-any integer? '(a 3.1 b 2.7)))
                        (test-equal #f (lseq-any integer? (make-lseq 'a 3.1 'b 2.7)))
                        (test-equal #t (lseq-any < '(3 1 4 1 5) '(2 7 1 8 2)))

                        (test-equal 6 (lseq-any factorial '(-1 -2 3 4)))
                        (test-equal 6 (lseq-any factorial (make-lseq -1 -2 3 4)))

                        (test-equal 24 (lseq-every factorial '(1 2 3 4)))
                        (test-equal 24 (lseq-every factorial (make-lseq 1 2 3 4)))

                        (test-equal 2 (lseq-index even? '(3 1 4 1 5 9)))
                        (test-equal 1 (lseq-index < '(3 1 4 1 5 9 2 5 6) '(2 7 1 8 2)))
                        (test-equal #f (lseq-index = '(3 1 4 1 5 9 2 5 6) '(2 7 1 8 2)))

                        (test-equal '(a b c) (lseq-realize (lseq-memq 'a '(a b c))))
                        (test-equal '(a b c) (lseq-realize (lseq-memq 'a (make-lseq 'a 'b 'c))))
                        (test-equal #f (lseq-memq 'a (make-lseq 'b 'c 'd)))
                        (test-equal #f (lseq-memq (list 'a) '(b c d)))
                        (test-equal #f (lseq-memq (list 'a) (make-lseq 'b 'c 'd)))

                        (test-equal '(101 102) (lseq-realize (lseq-memv 101 (make-lseq 100 101 102))))

                        (test-equal '((a) c) (lseq-realize (lseq-member (list 'a) (make-lseq 'b '(a) 'c))))
                        (test-equal '(2 3) (lseq-realize (lseq-member 2.0 (make-lseq 1 2 3) =)))
                        ) ; end lseqs/searching

            ) ; end lseqs

(test-end)

