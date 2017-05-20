;; Tests for (scheme hash-table) derived from reference implementation
;; but repackaged for SRFI 64 and R7RS Scheme by Peter Lane, 2017.

;;; Copyright (C) William D Clinger 2015. All Rights Reserved.
;;;
;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without restriction,
;;; including without limitation the rights to use, copy, modify, merge,
;;; publish, distribute, sublicense, and/or sell copies of the Software,
;;; and to permit persons to whom the Software is furnished to do so,
;;; subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; This is a very shallow sanity test for hash tables.
;;;

(import (scheme base)
        (scheme char)
        (scheme comparator)
        (scheme hash-table)
        (scheme list)
        (scheme sort)
        (srfi 64))

;;; Constructors.

(define ht-default (make-hash-table (make-default-comparator)))

(define ht-eq (hash-table (make-eq-comparator)))

(define ht-eqv (make-hash-table (make-eqv-comparator)))

(define ht-eq2 (make-hash-table (make-eq-comparator)))

(define ht-eqv2 (make-hash-table (make-eqv-comparator)))

(define ht-equal (make-hash-table (make-default-comparator)))

(define ht-string (make-hash-table (make-comparator string? string=? string<? string-hash)))

(define ht-string-ci (make-hash-table (make-comparator string? string-ci=? string-ci<? string-ci-hash)))

(define ht-symbol (make-hash-table (make-comparator symbol? symbol=? 
                                                    (lambda (a b) (string<? (symbol->string a)
                                                                            (symbol->string b)))
                                                    (lambda (obj) (string-hash (symbol->string obj))))))    ; FIXME: glass-box

(define ht-fixnum (make-hash-table (make-comparator number? = abs (lambda (x) (exact (abs (round x)))))))

(define ht-default2
  (hash-table (make-default-comparator) 'foo 'bar 101.3 "fever" '(x y z) #()))

(define ht-fixnum2 (make-hash-table (make-comparator real? = < (lambda (x) (exact (abs (round x)))))))
(for-each (lambda (i) (hash-table-set! ht-fixnum2 (square i) i)) (iota 10))

(define ht-string2
  (hash-table-unfold (lambda (s) (= 0 (string-length s)))
                     (lambda (s) (values s (string-length s)))
                     (lambda (s) (substring s 0 (- (string-length s) 1)))
                     "prefixes"
                     (make-comparator string? string=? string<? string-hash)))

(define ht-string-ci2
  (alist->hash-table '(("" . 0) ("Mary" . 4) ("Paul" . 4) ("Peter" . 5))
                     (make-comparator string? string-ci=? string-ci<? string-ci-hash)))

(define ht-symbol2
  (alist->hash-table '((mary . travers) (noel . stookey) (peter . yarrow))
                     (make-eq-comparator)))

(define ht-equal2
  (alist->hash-table '(((edward) . abbey)
                       ((dashiell) . hammett)
                       ((edward) . teach)
                       ((mark) . twain))
                     (make-default-comparator)))

(define test-tables
  (list ht-default   ht-default2   ; initial keys: foo, 101.3, (x y z)
        ht-eq        ht-eq2        ; initially empty
        ht-eqv       ht-eqv2       ; initially empty
        ht-equal     ht-equal2     ; initial keys: (edward), (dashiell), (mark)
        ht-string    ht-string2    ; initial keys: "p, "pr", ..., "prefixes"
        ht-string-ci ht-string-ci2 ; initial keys: "", "Mary", "Paul", "Peter"
        ht-symbol    ht-symbol2    ; initial keys: mary, noel, peter
        ht-fixnum    ht-fixnum2))  ; initial keys: 0, 1, 4, 9, ..., 81

(test-begin "scheme-hash-table")

;;; Predicates

(test-assert (not (hash-table? #())))
(test-assert (not (hash-table? (make-default-comparator))))
(test-assert (every hash-table? test-tables))

(test-assert (every equal?
                    (map hash-table-contains?
                         test-tables
                         '(foo 101.3
                               x "y"
                               (14 15) #\newline
                               (edward) (mark)
                               "p" "pref"
                               "mike" "PAUL"
                               jane noel
                               0 4))
                    '(#f #t #f #f #f #f #f #t #f #t #f #t #f #t #f #t)))

(test-assert (every equal?
                    (map hash-table-contains?
                         test-tables
                         '(#u8() 47.9
                           '#() '()
                           foo bar
                           19 (henry)
                           "p" "perp"
                           "mike" "Noel"
                           jane paul
                           0 5))
                    (map (lambda (x) #f) test-tables)))

(test-assert (every equal? ;; TODO - failed
                    (map hash-table-empty? test-tables)
                    '(#t #f #t #t #t #t #t #f #t #f #t #f #t #f #t #f)))

(test-assert (every equal?
                    (map (lambda (ht1 ht2) (hash-table=? (make-default-comparator) ht1 ht2))
                         test-tables
                         test-tables)
                    (map (lambda (x) #t) test-tables)))

(test-assert (every equal? ;; TODO - failed
                    (map (lambda (ht1 ht2) (hash-table=? (make-default-comparator) ht1 ht2))
                         test-tables
                         (do ((tables (reverse test-tables) (cddr tables))
                              (rev '() (cons (car tables) (cons (cadr tables) rev))))
                           ((null? tables)
                            rev)))
                    '(#f #f #t #t #t #t #f #f #f #f #f #f #f #f #f #f)))

(test-assert (every (lambda (x) x) (map hash-table-mutable? test-tables))) ;; Note: all mutable in this version

;; Accessors

(test-assert (every equal?
                    (map (lambda (ht key)
                           (guard (exn
                                    (else 'err))
                                  (hash-table-ref ht key)))
                         test-tables
                         '(foo 101.3
                               x "y"
                               (14 15) #\newline
                               (edward) (mark)
                               "p" "pref"
                               "mike" "PAUL"
                               jane noel
                               0 4))
                    '(err "fever" err err err err err twain err 4 err 4 err stookey err 2)))

(test-assert (every equal?
                    (map (lambda (ht key)
                           (guard (exn
                                    (else 'err))
                                  (hash-table-ref ht key (lambda () 'eh))))
                         test-tables
                         '(foo 101.3
                               x "y"
                               (14 15) #\newline
                               (edward) (mark)
                               "p" "pref"
                               "mike" "PAUL"
                               jane noel
                               0 4))
                    '(eh "fever" eh eh eh eh eh twain eh 4 eh 4 eh stookey eh 2)))

(test-assert (every equal?
                    (map (lambda (ht key)
                           (guard (exn
                                    (else 'err))
                                  (hash-table-ref ht key (lambda () 'eh) list)))
                         test-tables
                         '(foo 101.3
                               x "y"
                               (14 15) #\newline
                               (edward) (mark)
                               "p" "pref"
                               "mike" "PAUL"
                               jane noel
                               0 4))
                    '(eh ("fever") eh eh eh eh eh (twain) eh (4) eh (4) eh (stookey) eh (2))))

(test-assert (every equal?
                    (map (lambda (ht key)
                           (guard (exn
                                    (else 'err))
                                  (hash-table-ref/default ht key 'eh)))
                         test-tables
                         '(foo 101.3
                               x "y"
                               (14 15) #\newline
                               (edward) (mark)
                               "p" "pref"
                               "mike" "PAUL"
                               jane noel
                               0 4))
                    '(eh "fever" eh eh eh eh eh twain eh 4 eh 4 eh stookey eh 2)))

(test-equal (begin (hash-table-set! ht-fixnum)
                   (list-sort < (hash-table-keys ht-fixnum)))
            '())

(test-equal (begin (hash-table-set! ht-fixnum 121 11 144 12 169 13)
                   (list-sort < (hash-table-keys ht-fixnum)))
            '(121 144 169))

(test-equal (begin (hash-table-set! ht-fixnum
                                    0 0 1 1 4 2 9 3 16 4 25 5 36 6 49 7 64 8 81 9)
                   (list-sort < (hash-table-keys ht-fixnum)))
            '(0 1 4 9 16 25 36 49 64 81 121 144 169))

(test-equal (map (lambda (i) (hash-table-ref/default ht-fixnum i 'error))
                 '(169 144 121 0 1 4 9 16 25 36 49 64 81))
            '(13 12 11 0 1 2 3 4 5 6 7 8 9))

(test-equal (begin (hash-table-delete! ht-fixnum)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i 'error))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 5 6 7 8 9))

(test-equal (begin (hash-table-delete! ht-fixnum 1 9 25 49 81 200 121 169 81 1)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(-1 12 -1 0 -1 2 -1 4 -1 6 -1 8 -1))

(test-equal (begin (hash-table-delete! ht-fixnum 200 100 0 81 36)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(-1 12 -1 -1 -1 2 -1 4 -1 -1 -1 8 -1))

(test-equal (begin (hash-table-intern! ht-fixnum 169 (lambda () 13))
                   (hash-table-intern! ht-fixnum 121 (lambda () 11))
                   (hash-table-intern! ht-fixnum   0 (lambda ()  0))
                   (hash-table-intern! ht-fixnum   1 (lambda ()  1))
                   (hash-table-intern! ht-fixnum   1 (lambda () 99))
                   (hash-table-intern! ht-fixnum 121 (lambda () 66))
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 -1 4 -1 -1 -1 8 -1))

(test-equal (list-sort (lambda (v1 v2) (< (vector-ref v1 0) (vector-ref v2 0)))
                       (hash-table-map->list vector ht-fixnum))
            '(#(0 0) #(1 1) #(4 2) #(16 4) #(64 8) #(121 11) #(144 12) #(169 13)))

(test-equal (begin (hash-table-prune! (lambda (key val)
                                        (and (odd? key) (> val 10)))
                                      ht-fixnum)
                   (list-sort (lambda (l1 l2)
                                (< (car l1) (car l2)))
                              (hash-table-map->list list ht-fixnum)))
            '((0 0) (1 1) (4 2) (16 4) (64 8) #;(121 11) 
                    (144 12) 
                    #;(169 13)
                    ))

(test-equal (begin (hash-table-intern! ht-fixnum 169 (lambda () 13))
                   (hash-table-intern! ht-fixnum 144 (lambda () 9999))
                   (hash-table-intern! ht-fixnum 121 (lambda () 11))
                   (list-sort (lambda (l1 l2)
                                (< (car l1) (car l2)))
                              (hash-table-map->list list ht-fixnum)))
            '((0 0) (1 1) (4 2) (16 4) (64 8) (121 11) (144 12) (169 13)))

(test-equal (begin (hash-table-update! ht-fixnum 9 length (lambda () '(a b c)))
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 -1 -1 -1 8 -1))

(test-equal (begin (hash-table-update! ht-fixnum 16 -)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 -4 -1 -1 -1 8 -1))

(test-equal (begin (hash-table-update! ht-fixnum 16 - abs)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 -1 -1 -1 8 -1))

(test-equal (begin (hash-table-update!/default ht-fixnum 25 - 5)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 -5 -1 -1 8 -1))

(test-equal (begin (hash-table-update!/default ht-fixnum 25 - 999)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 5 -1 -1 8 -1))

(test-equal (let* ((n0 (hash-table-size ht-fixnum))
                   (ht (hash-table-copy ht-fixnum #t)))
              (call-with-values
                (lambda () (hash-table-pop! ht))
                (lambda (key val)
                  (list (= key (* val val))
                        (= (- n0 1) (hash-table-size ht))))))
            '(#t #t))

(test-equal (begin (hash-table-delete! ht-fixnum 75)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 75 81)))
            '(13 12 11 0 1 2 3 4 5 -1 -1 8 -1 -1))

(test-equal (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                 '(169 144 121 0 1 4 9 16 25 36 49 64 81))
            '(13 12 11 0 1 2 3 4 5 -1 -1 8 -1))

(test-equal (begin (hash-table-set! ht-fixnum 36 6)
                   (hash-table-set! ht-fixnum 81 9)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(169 144 121 0 1 4 9 16 25 36 49 64 81)))
            '(13 12 11 0 1 2 3 4 5 6 -1 8 9))

(test-equal (begin (hash-table-clear! ht-eq)
                   (hash-table-size ht-eq))
            0)

;;;; The whole hash table.

(test-equal (begin (hash-table-set! ht-eq 'foo 13 'bar 14 'baz 18)
                   (hash-table-size ht-eq))
            3)

(test-equal (let* ((ht (hash-table-empty-copy ht-eq))
                   (n0 (hash-table-size ht))
                   (ignored (hash-table-set! ht 'foo 13 'bar 14 'baz 18))
                   (n1 (hash-table-size ht)))
              (list n0 n1 (hash-table=? (make-default-comparator) ht ht-eq)))
            '(0 3 #t))

(test-equal (begin (hash-table-clear! ht-eq)
                   (hash-table-size ht-eq))
            0)

(test-equal (hash-table-find (lambda (key val)
                               (if (= 144 key (* val val))
                                 (list key val)
                                 #f))
                             ht-fixnum
                             (lambda () 99))
            '(144 12))

(test-equal (hash-table-find (lambda (key val)
                               (if (= 144 key val)
                                 (list key val)
                                 #f))
                             ht-fixnum
                             (lambda () 99))
            99)

(test-equal (hash-table-count <= ht-fixnum)
            2)

;;;; Mapping and folding.

(test-equal (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                 '(0 1 4 9 16 25 36 49 64 81 100 121 144 169 196))
            '(0 1 2 3 4 5 6 -1 8 9 -1 11 12 13 -1))

(test-equal (let ((ht (hash-table-map (lambda (val) (* val val))
                                      (make-eqv-comparator)
                                      ht-fixnum)))
              (map (lambda (i) (hash-table-ref/default ht i -1))
                   '(0 1 4 9 16 25 36 49 64 81 100 121 144 169 196)))
            '(0 1 4 9 16 25 36 -1 64 81 -1 121 144 169 -1))

(test-equal (let ((keys (make-vector 15 -1))
                  (vals (make-vector 15 -1)))
              (hash-table-for-each (lambda (key val)
                                     (vector-set! keys val key)
                                     (vector-set! vals val val))
                                   ht-fixnum)
              (list keys vals))
            '(#(0 1 4 9 16 25 36 -1 64 81 -1 121 144 169 -1)
              #(0 1 2 3  4  5  6 -1  8  9 -1  11  12  13 -1)))

(test-equal (begin (hash-table-map! (lambda (key val)
                                      (if (<= 10 key)
                                        (- val)
                                        val))
                                    ht-fixnum)
                   (map (lambda (i) (hash-table-ref/default ht-fixnum i -1))
                        '(0 1 4 9 16 25 36 49 64 81 100 121 144 169 196)))
            '(0 1 2 3 -4 -5 -6 -1 -8 -9 -1 -11 -12 -13 -1))

(test-equal (hash-table-fold (lambda (key val acc)
                               (+ val acc))
                             0
                             ht-string-ci2)
            13)

(test-equal (list-sort < (hash-table-fold (lambda (key val acc)
                                            (cons key acc))
                                          '()
                                          ht-fixnum))
            '(0 1 4 9 16 25 36 64 81 121 144 169))

;;;; Copying and conversion.

(test-assert (hash-table=? (make-comparator real? = < (lambda (x) (exact (abs (round x))))) ht-fixnum (hash-table-copy ht-fixnum)))

(test-assert (hash-table=? (make-comparator real? = < (lambda (x) (exact (abs (round x))))) ht-fixnum (hash-table-copy ht-fixnum #f)))

(test-assert (hash-table=? (make-comparator real? = < (lambda (x) (exact (abs (round x))))) ht-fixnum (hash-table-copy ht-fixnum #t)))

(test-equal (hash-table->alist ht-eq)
            '())

(test-equal (list-sort (lambda (x y) (< (car x) (car y)))
                       (hash-table->alist ht-fixnum))
            '((0 . 0)
              (1 . 1)
              (4 . 2)
              (9 . 3)
              (16 . -4)
              (25 . -5)
              (36 . -6)
              (64 . -8)
              (81 . -9)
              (121 . -11)
              (144 . -12)
              (169 . -13)))

;;;; Hash tables as sets.

(test-equal (begin (hash-table-union! ht-fixnum ht-fixnum2)
                   (list-sort (lambda (x y) (< (car x) (car y)))
                              (hash-table->alist ht-fixnum)))
            '((0 . 0)
              (1 . 1)
              (4 . 2)
              (9 . 3)
              (16 . -4)
              (25 . -5)
              (36 . -6)
              (49 . 7)
              (64 . -8)
              (81 . -9)
              (121 . -11)
              (144 . -12)
              (169 . -13)))

(test-equal (let ((ht (hash-table-copy ht-fixnum2 #t)))
              (hash-table-union! ht ht-fixnum)
              (list-sort (lambda (x y) (< (car x) (car y)))
                         (hash-table->alist ht)))
            '((0 . 0)
              (1 . 1)
              (4 . 2)
              (9 . 3)
              (16 . 4)
              (25 . 5)
              (36 . 6)
              (49 . 7)
              (64 . 8)
              (81 . 9)
              (121 . -11)
              (144 . -12)
              (169 . -13)))

(test-assert (begin (hash-table-union! ht-eqv2 ht-fixnum)
                    (hash-table=? (make-default-comparator) ht-eqv2 ht-fixnum)))

(test-assert (begin (hash-table-intersection! ht-eqv2 ht-fixnum)
                    (hash-table=? (make-default-comparator) ht-eqv2 ht-fixnum)))

(test-assert (begin (hash-table-intersection! ht-eqv2 ht-eqv)
                    (hash-table-empty? ht-eqv2)))

(test-equal (begin (hash-table-intersection! ht-fixnum ht-fixnum2)
                   (list-sort (lambda (x y) (< (car x) (car y)))
                              (hash-table->alist ht-fixnum)))
            '((0 . 0)
              (1 . 1)
              (4 . 2)
              (9 . 3)
              (16 . -4)
              (25 . -5)
              (36 . -6)
              (49 . 7)
              (64 . -8)
              (81 . -9)))

(test-equal (begin (hash-table-intersection!
                     ht-fixnum
                     (alist->hash-table '((-1 . -1) (4 . 202) (25 . 205) (100 . 10))
                                        (make-comparator real? = < (lambda (x) (exact (abs (round x)))))))
                   (list-sort (lambda (x y) (< (car x) (car y)))
                              (hash-table->alist ht-fixnum)))
            '((4 . 2)
              (25 . -5)))

(test-equal (let ((ht (hash-table-copy ht-fixnum2 #t)))
              (hash-table-difference!
                ht
                (alist->hash-table '((-1 . -1) (4 . 202) (25 . 205) (100 . 10))
                                   (make-comparator real? = < (lambda (x) (exact (abs (round x)))))))
              (list-sort (lambda (x y) (< (car x) (car y)))
                         (hash-table->alist ht)))
            '((0 . 0)
              (1 . 1)
              (9 . 3)
              (16 . 4)
              (36 . 6)
              (49 . 7)
              (64 . 8)
              (81 . 9)))

(test-equal (let ((ht (hash-table-copy ht-fixnum2 #t)))
              (hash-table-xor!
                ht
                (alist->hash-table '((-1 . -1) (4 . 202) (25 . 205) (100 . 10))
                                   (make-comparator real? = < (lambda (x) (exact (abs (round x)))))))
              (list-sort (lambda (x y) (< (car x) (car y)))
                         (hash-table->alist ht)))
            '((-1 . -1)
              (0 . 0)
              (1 . 1)
              (9 . 3)
              (16 . 4)
              (36 . 6)
              (49 . 7)
              (64 . 8)
              (81 . 9)
              (100 . 10)))

(test-equal (guard (exn
                     (else 'key-not-found))
                   (hash-table-ref ht-default "this key won't be present"))
            'key-not-found)

(test-end)

