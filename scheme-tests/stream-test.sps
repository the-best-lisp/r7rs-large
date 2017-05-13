(import (scheme base)
        (scheme file)
        (scheme write)
        (scheme stream)
        (srfi 64))

(test-begin "scheme-stream")

(define strm123 (stream 1 2 3))

(define (lsec proc . args) (lambda x (apply proc (append args x))))

(define (rsec proc . args) (lambda x (apply proc (reverse (append (reverse args) (reverse x))))))

; stream-null
(test-equal (stream? stream-null) #t)
(test-equal (stream-null? stream-null) #t)
(test-equal (stream-pair? stream-null) #f)

; stream-cons
(test-equal (stream? (stream-cons 1 stream-null)) #t)
(test-equal (stream-null? (stream-cons 1 stream-null)) #f)
(test-equal (stream-pair? (stream-cons 1 stream-null)) #t)

; stream?
(test-equal (stream? stream-null) #t)
(test-equal (stream? (stream-cons 1 stream-null)) #t)
(test-equal (stream? "four") #f)

; stream-null?
(test-equal (stream-null? stream-null) #t)
(test-equal (stream-null? (stream-cons 1 stream-null)) #f)
(test-equal (stream-null? "four") #f)

; stream-pair?
(test-equal (stream-pair? stream-null) #f)
(test-equal (stream-pair? (stream-cons 1 stream-null)) #t)
(test-equal (stream-pair? "four") #f)

; stream-car
(test-error (stream-car "four"))
(test-error (stream-car stream-null))
(test-equal (stream-car strm123) 1)

; stream-cdr
(test-error (stream-cdr "four"))
(test-error (stream-cdr stream-null))
(test-equal (stream-car (stream-cdr strm123)) 2)

; stream-lambda
(test-equal
  (stream->list
    (letrec ((double
               (stream-lambda (strm)
                              (if (stream-null? strm)
                                stream-null
                                (stream-cons
                                  (* 2 (stream-car strm))
                                  (double (stream-cdr strm)))))))
      (double strm123)))
  '(2 4 6))

; define-stream
(test-equal
  (stream->list
    (let ()
      (define-stream (double strm)
                     (if (stream-null? strm)
                       stream-null
                       (stream-cons
                         (* 2 (stream-car strm))
                         (double (stream-cdr strm)))))
      (double strm123)))
  '(2 4 6))

; list->stream
(test-error (list->stream "four"))
(test-equal (stream->list (list->stream '())) '())
(test-equal (stream->list (list->stream '(1 2 3))) '(1 2 3))

; port->stream
(let* ((p (open-input-file "scheme-tests/stream-file.txt"))
       (s (port->stream p)))
  (test-error (port->stream "four"))
  (test-equal (string=? (list->string (stream->list 11 s)) "; Copyright") #t)
  (close-input-port p))

; stream
(test-equal (stream->list (stream)) '())
(test-equal (stream->list (stream 1)) '(1))
(test-equal (stream->list (stream 1 2 3)) '(1 2 3))

; stream->list
(test-error (stream->list '()))
(test-error (stream->list "four" strm123))
(test-error (stream->list -1 strm123))
(test-equal (stream->list (stream)) '())
(test-equal (stream->list strm123) '(1 2 3))
(test-equal (stream->list 5 strm123) '(1 2 3))
(test-equal (stream->list 3 (stream-from 1)) '(1 2 3))

; stream-append
(test-error (stream-append "four"))
(test-equal (stream->list (stream-append strm123)) '(1 2 3))
(test-equal (stream->list (stream-append strm123 strm123)) '(1 2 3 1 2 3))
(test-equal (stream->list (stream-append strm123 strm123 strm123)) '(1 2 3 1 2 3 1 2 3))
(test-equal (stream->list (stream-append strm123 stream-null)) '(1 2 3))
(test-equal (stream->list (stream-append stream-null strm123)) '(1 2 3))

; stream-concat
(test-error (stream-concat "four"))
(test-equal (stream->list (stream-concat (stream strm123))) '(1 2 3))
(test-equal (stream->list (stream-concat (stream strm123 strm123))) '(1 2 3 1 2 3))

; stream-constant
(test-equal (stream-ref (stream-constant 1) 100) 1)
(test-equal (stream-ref (stream-constant 1 2) 100) 1)
(test-equal (stream-ref (stream-constant 1 2 3) 3) 1)

; stream-drop
(test-error (stream-drop "four" strm123))
(test-error (stream-drop -1 strm123))
(test-error (stream-drop 2 "four"))
(test-equal (stream->list (stream-drop 0 stream-null)) '())
(test-equal (stream->list (stream-drop 0 strm123)) '(1 2 3))
(test-equal (stream->list (stream-drop 1 strm123)) '(2 3))
(test-equal (stream->list (stream-drop 5 strm123)) '())

; stream-drop-while
(test-error (stream-drop-while "four" strm123))
(test-error (stream-drop-while odd? "four"))
(test-equal (stream->list (stream-drop-while odd? stream-null)) '())
(test-equal (stream->list (stream-drop-while odd? strm123)) '(2 3))
(test-equal (stream->list (stream-drop-while even? strm123)) '(1 2 3))
(test-equal (stream->list (stream-drop-while positive? strm123)) '())
(test-equal (stream->list (stream-drop-while negative? strm123)) '(1 2 3))

; stream-filter
(test-error (stream-filter "four" strm123))
(test-error (stream-filter odd? '()))
(test-equal (stream-null? (stream-filter odd? (stream))) #t)
(test-equal (stream->list (stream-filter odd? strm123)) '(1 3))
(test-equal (stream->list (stream-filter even? strm123)) '(2))
(test-equal (stream->list (stream-filter positive? strm123)) '(1 2 3))
(test-equal (stream->list (stream-filter negative? strm123)) '())
(let loop ((n 10))
  (test-equal (odd? (stream-ref (stream-filter odd? (stream-from 0)) n)) #t)
  (if (positive? n) (loop (- n 1))))
(let loop ((n 10))
  (test-equal (even? (stream-ref (stream-filter odd? (stream-from 0)) n)) #f)
  (if (positive? n) (loop (- n 1))))

; stream-fold
(test-error (stream-fold "four" 0 strm123))
(test-error (stream-fold + 0 '()))
(test-equal (stream-fold + 0 strm123) 6)

; stream-for-each
(test-error (stream-for-each "four" strm123))
(test-error (stream-for-each display))
(test-error (stream-for-each display "four"))
(test-equal (let ((sum 0)) (stream-for-each (lambda (x) (set! sum (+ sum x))) strm123) sum) 6)

; stream-from
(test-error (stream-from "four"))
(test-error (stream-from 1 "four"))
(test-equal (stream-ref (stream-from 0) 100) 100)
(test-equal (stream-ref (stream-from 1 2) 100) 201)
(test-equal (stream-ref (stream-from 0 -1) 100) -100)

; stream-iterate
(test-error (stream-iterate "four" 0))
(test-equal (stream->list 3 (stream-iterate (lsec + 1) 1)) '(1 2 3))

; stream-length
(test-error (stream-length "four"))
(test-equal (stream-length (stream)) 0)
(test-equal (stream-length strm123) 3)

; stream-let
(test-equal (stream->list
          (stream-let loop ((strm strm123))
                      (if (stream-null? strm)
                        stream-null
                        (stream-cons
                          (* 2 (stream-car strm))
                          (loop (stream-cdr strm))))))
        '(2 4 6))

; stream-map
(test-error (stream-map "four" strm123))
(test-error (stream-map odd?))
(test-error (stream-map odd? "four"))
(test-equal (stream->list (stream-map - strm123)) '(-1 -2 -3))
(test-equal (stream->list (stream-map + strm123 strm123)) '(2 4 6))
(test-equal (stream->list (stream-map + strm123 (stream-from 1))) '(2 4 6))
(test-equal (stream->list (stream-map + (stream-from 1) strm123)) '(2 4 6))
(test-equal (stream->list (stream-map + strm123 strm123 strm123)) '(3 6 9))

; stream-match
(guard (err 
         (else (display err) (newline)
               (test-assert #f)))
       (test-error (stream-match '(1 2 3) (_ 'ok)))
       (test-error (stream-match strm123 (() 42)))
       (test-equal (stream-match stream-null (() 'ok)) 'ok)
       (test-equal (stream-match strm123 (() 'no) (else 'ok)) 'ok)
       (test-equal (stream-match (stream 1) (() 'no) ((a) a)) 1)
       (test-equal (stream-match (stream 1) (() 'no) ((_) 'ok)) 'ok)
       (test-equal (stream-match strm123 ((a b c) (list a b c))) '(1 2 3))
       (test-equal (stream-match strm123 ((a . _) a)) 1)
       (test-equal (stream-match strm123 ((a b . _) (list a b))) '(1 2))
       (test-equal (stream-match strm123 ((a b . c) (list a b (stream-car c)))) '(1 2 3))
       (test-equal (stream-match strm123 (s (stream->list s))) '(1 2 3))
       (test-equal (stream-match strm123 ((a . _) (= a 1) 'ok)) 'ok)
       (test-equal (stream-match strm123 ((a . _) (= a 2) 'yes) (_ 'no)) 'no)
       (test-equal (stream-match strm123 ((a b c) (= a b) 'yes) (_ 'no)) 'no)
       (test-equal (stream-match (stream 1 1 2) ((a b c) (= a b) 'yes) (_ 'no)) 'yes))

; stream-of
(test-equal (stream->list
          (stream-of (+ y 6)
                     (x in (stream-range 1 6))
                     (odd? x)
                     (y is (* x x)))) '(7 15 31))
(test-equal (stream->list
          (stream-of (* x y)
                     (x in (stream-range 1 4))
                     (y in (stream-range 1 5))))
        '(1 2 3 4 2 4 6 8 3 6 9 12))
(test-equal (stream-car (stream-of 1)) 1)

; stream-range
(test-error (stream-range "four" 0))
(test-error (stream-range 0 "four"))
(test-error (stream-range 1 2 "three"))
(test-equal (stream->list (stream-range 0 5)) '(0 1 2 3 4))
(test-equal (stream->list (stream-range 5 0)) '(5 4 3 2 1))
(test-equal (stream->list (stream-range 0 5 2)) '(0 2 4))
(test-equal (stream->list (stream-range 5 0 -2)) '(5 3 1))
(test-equal (stream->list (stream-range 0 1 -1)) '())

(define nats
  (stream-cons 0
    (stream-map (lambda (n) (+ 1 n)) nats)))

; stream-ref
(test-error (stream-ref '() 4))
(test-error (stream-ref nats 3.5))
(test-error (stream-ref nats -3))
(test-error (stream-ref strm123 5))
(test-equal (stream-ref strm123 0) 1)
(test-equal (stream-ref strm123 1) 2)
(test-equal (stream-ref strm123 2) 3)

; stream-reverse
(test-error (stream-reverse '()))
(test-equal (stream->list (stream-reverse (stream))) '())
(test-equal (stream->list (stream-reverse strm123)) '(3 2 1))

; stream-scan
(test-error (stream-scan "four" 0 strm123))
(test-error (stream-scan + 0 '()))
(test-equal (stream->list (stream-scan + 0 strm123)) '(0 1 3 6))

; stream-take
(test-error (stream-take 5 "four"))
(test-error (stream-take "four" strm123))
(test-error (stream-take -4 strm123))
(test-equal (stream->list (stream-take 5 stream-null)) '())
(test-equal (stream->list (stream-take 0 stream-null)) '())
(test-equal (stream->list (stream-take 0 strm123)) '())
(test-equal (stream->list (stream-take 2 strm123)) '(1 2))
(test-equal (stream->list (stream-take 3 strm123)) '(1 2 3))
(test-equal (stream->list (stream-take 5 strm123)) '(1 2 3))

; stream-take-while
(test-error (stream-take-while odd? "four"))
(test-error (stream-take-while "four" strm123))
(test-equal (stream->list (stream-take-while odd? strm123)) '(1))
(test-equal (stream->list (stream-take-while even? strm123)) '())
(test-equal (stream->list (stream-take-while positive? strm123)) '(1 2 3))
(test-equal (stream->list (stream-take-while negative? strm123)) '())

; stream-unfold
(test-error (stream-unfold "four" odd? + 0))
(test-error (stream-unfold + "four" + 0))
(test-error (stream-unfold + odd? "four" 0))
(test-equal (stream->list (stream-unfold (rsec expt 2) (rsec < 10) (rsec + 1) 0))
        '(0 1 4 9 16 25 36 49 64 81))

; stream-unfolds
(test-equal
  (stream->list
    (stream-unfolds
      (lambda (x)
        (let ((n (car x)) (s (cdr x)))
          (if (zero? n)
            (values 'dummy '())
            (values
              (cons (- n 1) (stream-cdr s))
              (list (stream-car s))))))
      (cons 5 (stream-from 0))))
  '(0 1 2 3 4))

; stream-zip
(test-error (stream-zip))
(test-error (stream-zip "four"))
(test-error (stream-zip strm123 "four"))
(test-equal (stream->list (stream-zip strm123 stream-null)) '())
(test-equal (stream->list (stream-zip strm123)) '((1) (2) (3)))
(test-equal (stream->list (stream-zip strm123 strm123)) '((1 1) (2 2) (3 3)))
(test-equal (stream->list (stream-zip strm123 (stream-from 1))) '((1 1) (2 2) (3 3)))
(test-equal (stream->list (stream-zip strm123 strm123 strm123)) '((1 1 1) (2 2 2) (3 3 3)))

; other tests
(define primes (let ()
  (define-stream (next base mult strm)
    (let ((first (stream-car strm))
          (rest (stream-cdr strm)))
      (cond ((< first mult)
              (stream-cons first
                (next base mult rest)))
            ((< mult first)
              (next base (+ base mult) strm))
            (else (next base
                    (+ base mult) rest)))))
  (define-stream (sift base strm)
    (next base (+ base base) strm))
  (define-stream (sieve strm)
    (let ((first (stream-car strm))
          (rest (stream-cdr strm)))
      (stream-cons first
        (sieve (sift first rest)))))
  (sieve (stream-from 2))))

(test-equal
  (stream-car
    (stream-reverse
      (stream-take-while
        (rsec < 1000)
        primes)))
  997)

(define-stream (qsort lt? strm)
  (if (stream-null? strm)
      stream-null
      (let ((x (stream-car strm))
            (xs (stream-cdr strm)))
        (stream-append
          (qsort lt?
            (stream-filter
              (lambda (u) (lt? u x))
              xs))
          (stream x)
          (qsort lt?
            (stream-filter
              (lambda (u) (not (lt? u x)))
              xs))))))

(define-stream (isort lt? strm)
    (define-stream (insert strm x)
      (stream-match strm
        (() (stream x))
        ((y . ys)
          (if (lt? y x)
              (stream-cons y (insert ys x))
              (stream-cons x strm)))))
    (stream-fold insert stream-null strm))

(define-stream (stream-merge lt? . strms)
  (define-stream (merge xx yy)
    (stream-match xx (() yy) ((x . xs)
      (stream-match yy (() xx) ((y . ys)
        (if (lt? y x)
            (stream-cons y (merge xx ys))
            (stream-cons x (merge xs yy))))))))
  (stream-let loop ((strms strms))
    (cond ((null? strms) stream-null)
          ((null? (cdr strms)) (car strms))
          (else (merge (car strms)
                       (apply stream-merge lt?
                         (cdr strms)))))))

(define-stream (msort lt? strm)
  (let* ((n (quotient (stream-length strm) 2))
         (ts (stream-take n strm))
         (ds (stream-drop n strm)))
    (if (zero? n)
        strm
        (stream-merge lt?
          (msort < ts) (msort < ds)))))

(define-stream (stream-unique eql? strm)
  (if (stream-null? strm)
      stream-null
      (stream-cons (stream-car strm)
        (stream-unique eql?
          (stream-drop-while
            (lambda (x)
              (eql? (stream-car strm) x))
            strm)))))

(guard (err
         (else
           (display err) (newline)
           (test-assert #f)))
       (test-equal
         (stream->list (qsort < (stream 3 1 5 2 4)))
         (stream->list (isort < (stream 2 5 1 4 3)))))

(guard (err
         (else
           (display err) (newline)
           (test-assert #f)))
       (test-equal
         (stream->list (msort < (stream 3 1 5 2 4)))
         (stream->list (isort < (stream 2 5 1 4 3)))))

; http://www.research.att.com/~njas/sequences/A051037
(define hamming
  (stream-unique =
                 (stream-cons 1
                              (stream-merge <
                                            (stream-map (lsec * 2) hamming)
                                            (stream-merge <
                                                          (stream-map (lsec * 3) hamming)
                                                          (stream-map (lsec * 5) hamming))))))

(guard (err
         (else
           (display err) (newline)
           (test-assert #f)))
       (test-equal (stream-ref hamming 999) 51200000))

(test-end)

