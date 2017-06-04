;; Files from SRFI 132 collected and simplified somewhat

;;; Copyright (c) 1998 by Olin Shivers.
;;; This code is open-source; see the end of the file for porting and
;;; more copyright information.
;;; Olin Shivers 11/98.

(define-library
  (scheme sort)
  (export list-sorted?               vector-sorted?
          list-sort                  vector-sort
          list-stable-sort           vector-stable-sort
          list-sort!                 vector-sort!
          list-stable-sort!          vector-stable-sort!
          list-merge                 vector-merge
          list-merge!                vector-merge!
          list-delete-neighbor-dups  vector-delete-neighbor-dups
          list-delete-neighbor-dups! vector-delete-neighbor-dups!
          vector-find-median         vector-find-median!
          vector-select!             vector-separate!
          )

  (import (scheme base) 
          (scheme cxr)
          (only (srfi 27) random-integer))

  (begin

    (define (assert x)
      (when (not x)
        (error "assertion failure")))

    ;;; Problem:
    ;;; vector-delete-neighbor-dups pushes N stack frames, where N is the number
    ;;; of elements in the answer vector. This is arguably a very efficient thing
    ;;; to do, but it might blow out on a system with a limited stack but a big
    ;;; heap. We could rewrite this to "chunk" up answers in temp vectors if we
    ;;; push more than a certain number of frames, then allocate a final answer,
    ;;; copying all the chunks into the answer. But it's much more complex code.

    ;;; Exports:
    ;;; (list-delete-neighbor-dups  = lis) -> list
    ;;; (list-delete-neighbor-dups! = lis) -> list
    ;;; (vector-delete-neighbor-dups  = v [start end]) -> vector
    ;;; (vector-delete-neighbor-dups! = v [start end]) -> end'

    ;;; These procedures delete adjacent duplicate elements from a list or
    ;;; a vector, using a given element equality procedure. The first or leftmost
    ;;; element of a run of equal elements is the one that survives. The list
    ;;; or vector is not otherwise disordered.
    ;;;
    ;;; These procedures are linear time -- much faster than the O(n^2) general 
    ;;; duplicate-elt deletors that do not assume any "bunching" of elements.
    ;;; If you want to delete duplicate elements from a large list or vector,
    ;;; sort the elements to bring equal items together, then use one of these
    ;;; procedures -- for a total time of O(n lg n). 

    ;;; LIST-DELETE-NEIGHBOR-DUPS
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; Below are multiple versions of the LIST-DELETE-NEIGHBOR-DUPS procedure,
    ;;; from simple to complex. RECUR's contract: Strip off any leading X's from 
    ;;; LIS, and return that list neighbor-dup-deleted.
    ;;;
    ;;; The final version
    ;;; - shares a common subtail between the input & output list, up to 1024 
    ;;;   elements;
    ;;; - Needs no more than 1024 stack frames.

    #;
    ;;; Simplest version. 
    ;;; - Always allocates a fresh list / never shares storage.
    ;;; - Needs N stack frames, if answer is length N.
    (define (list-delete-neighbor-dups = lis)
      (if (pair? lis)
        (let ((x0 (car lis)))
          (cons x0 (let recur ((x0 x0) (xs (cdr lis)))
                     (if (pair? xs)
                       (let ((x1  (car xs))
                             (x2+ (cdr xs)))
                         (if (= x0 x1)
                           (recur x0 x2+) ; Loop, actually.
                           (cons x1 (recur x1 x2+))))
                       xs))))
        lis))

    ;;; This version tries to use cons cells from input by sharing longest
    ;;; common tail between input & output. Still needs N stack frames, for ans
    ;;; of length N.
    (define (list-delete-neighbor-dups = lis)
      (if (pair? lis)
        (let* ((x0 (car lis))
               (xs (cdr lis))
               (ans (let recur ((x0 x0) (xs xs))
                      (if (pair? xs)
                        (let ((x1  (car xs))
                              (x2+ (cdr xs)))
                          (if (= x0 x1)
                            (recur x0 x2+)
                            (let ((ans-tail (recur x1 x2+)))
                              (if (eq? ans-tail x2+) xs
                                (cons x1 ans-tail)))))
                        xs))))
          (if (eq? ans xs) lis (cons x0 ans)))

        lis))

    ;;; LIST-DELETE-NEIGHBOR-DUPS!
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; This code runs in constant list space, constant stack, and also
    ;;; does only the minimum SET-CDR!'s necessary.

    (define (list-delete-neighbor-dups! = lis)
      (if (pair? lis)
        (let lp1 ((prev lis) (prev-elt (car lis)) (lis (cdr lis)))
          (if (pair? lis)
            (let ((lis-elt (car lis))
                  (next (cdr lis)))
              (if (= prev-elt lis-elt)

                ;; We found the first elts of a run of dups, so we know
                ;; we're going to have to do a SET-CDR!. Scan to the end of
                ;; the run, do the SET-CDR!, and loop on LP1.
                (let lp2 ((lis next))
                  (if (pair? lis)
                    (let ((lis-elt (car lis))
                          (next (cdr lis)))
                      (if (= prev-elt lis-elt)
                        (lp2 next)
                        (begin (set-cdr! prev lis)
                               (lp1 lis lis-elt next))))
                    (set-cdr! prev lis)))	; Ran off end => quit.

                (lp1 lis lis-elt next))))))
      lis)


    (define (vector-delete-neighbor-dups elt= v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)
          (if (< start end)
            (let* ((x (vector-ref v start))
                   (ans (let recur ((x x) (i start) (j 1))
                          (if (< i end)
                            (let ((y (vector-ref v i))
                                  (nexti (+ i 1)))
                              (if (elt= x y)
                                (recur x nexti j)
                                (let ((ansvec (recur y nexti (+ j 1))))
                                  (vector-set! ansvec j y)
                                  ansvec)))
                            (make-vector j)))))
              (vector-set! ans 0 x)
              ans)
            '#()))))


    ;;; Packs the surviving elements to the left, in range [start,end'),
    ;;; and returns END'.
    (define (vector-delete-neighbor-dups! elt= v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)

          (if (>= start end)
            end
            ;; To eliminate unnecessary copying (read elt i then write the value 
            ;; back at index i), we scan until we find the first dup.
            (let skip ((j start) (vj (vector-ref v start)))
              (let ((j+1 (+ j 1)))
                (if (>= j+1 end)
                  end
                  (let ((vj+1 (vector-ref v j+1)))
                    (if (not (elt= vj vj+1))
                      (skip j+1 vj+1)

                      ;; OK -- j & j+1 are dups, so we're committed to moving
                      ;; data around. In lp2, v[start,j] is what we've done;
                      ;; v[k,end) is what we have yet to handle.
                      (let lp2 ((j j) (vj vj) (k (+ j 2)))
                        (let lp3 ((k k))
                          (if (>= k end)
                            (+ j 1) ; Done.
                            (let ((vk (vector-ref v k))
                                  (k+1 (+ k 1)))
                              (if (elt= vj vk)
                                (lp3 k+1)
                                (let ((j+1 (+ j 1)))
                                  (vector-set! v j+1 vk)
                                  (lp2 j+1 vk k+1))))))))))))))))

    ;;; A stable list merge sort of my own device
    ;;; Two variants: pure & destructive
    ;;;
    ;;; This list merge sort is opportunistic (a "natural" sort) -- it exploits
    ;;; existing order in the input set. Instead of recursing all the way down to
    ;;; individual elements, the leaves of the merge tree are maximal contiguous
    ;;; runs of elements from the input list. So the algorithm does very well on
    ;;; data that is mostly ordered, with a best-case time of O(n) when the input
    ;;; list is already completely sorted. In any event, worst-case time is
    ;;; O(n lg n).
    ;;;
    ;;; The destructive variant is "in place," meaning that it allocates no new
    ;;; cons cells at all; it just rearranges the pairs of the input list with
    ;;; SET-CDR! to order it.
    ;;;
    ;;; The interesting control structure is the combination recursion/iteration
    ;;; of the core GROW function that does an "opportunistic" DFS walk of the
    ;;; merge tree, adaptively subdividing in response to the length of the
    ;;; merges, without requiring any auxiliary data structures beyond the
    ;;; recursion stack. It's actually quite simple -- ten lines of code.
    ;;;	-Olin Shivers 10/20/98

    ;;; (mlet ((var-list mv-exp) ...) body ...)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; A LET* form that handles multiple values. Move this into the two clients
    ;;; if you don't have a module system handy to restrict its visibility...
    (define-syntax mlet ; Multiple-value LET*
      (syntax-rules ()
                    ((mlet ((() exp) rest ...) body ...)
                     (begin exp (mlet (rest ...) body ...)))

                    ((mlet (((var) exp) rest ...) body ...)
                     (let ((var exp)) (mlet (rest ...) body ...)))

                    ((mlet ((vars exp) rest ...) body ...)
                     (call-with-values (lambda () exp) 
                                       (lambda vars (mlet (rest ...) body ...))))

                    ((mlet () body ...) (begin body ...))))


    ;;; (list-merge-sort < lis)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; A natural, stable list merge sort. 
    ;;; - natural: picks off maximal contiguous runs of pre-ordered data.
    ;;; - stable: won't invert the order of equal elements in the input list.

    (define (list-merge-sort elt< lis)

      ;; (getrun lis) -> run runlen rest
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; Pick a run of non-decreasing data off of non-empty list LIS. 
      ;; Return the length of this run, and the following list.
      (define (getrun lis)
        (let lp ((ans '())  (i 1)  (prev (car lis))  (xs (cdr lis)))
          (if (pair? xs)
            (let ((x (car xs)))
              (if (elt< x prev) 
                (values (append-reverse ans (cons prev '())) i xs)
                (lp (cons prev ans) (+ i 1) x (cdr xs))))
            (values (append-reverse ans (cons prev '())) i xs))))

      (define (append-reverse rev-head tail)
        (let lp ((rev-head rev-head) (tail tail))
          (if (null-list? rev-head) tail
            (lp (cdr rev-head) (cons (car rev-head) tail)))))

      (define (null-list? l)
        (cond ((pair? l) #f)
              ((null? l) #t)
              (else (error  "argument out of domain" l))))

      ;; (merge a b) -> list
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; List merge -- stably merge lists A (length > 0) & B (length > 0).
      ;; This version requires up to |a|+|b| stack frames.
      (define (merge a b)
        (let recur ((x (car a)) (a a)
                                (y (car b)) (b b))
          (if (elt< y x)
            (cons y (let ((b (cdr b)))
                      (if (pair? b)
                        (recur x a (car b) b)
                        a)))
            (cons x (let ((a (cdr a)))
                      (if (pair? a)
                        (recur (car a) a y b)
                        b))))))

      ;; (grow s ls ls2 u lw) -> [a la unused]
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; The core routine. Read the next 20 lines of comments & all is obvious.
      ;; - S is a sorted list of length LS > 1.
      ;; - LS2 is some power of two <= LS.
      ;; - U is an unsorted list.
      ;; - LW is a positive integer.
      ;; Starting with S, and taking data from U as needed, produce
      ;; a sorted list of *at least* length LW, if there's enough data
      ;; (LW <= LS + length(U)), or use all of U if not.
      ;;
      ;; GROW takes maximal contiguous runs of data from U at a time;
      ;; it is allowed to return a list *longer* than LW if it gets lucky
      ;; with a long run.
      ;;
      ;; The key idea: If you want a merge operation to "pay for itself," the two
      ;; lists being merged should be about the same length. Remember that.
      ;;
      ;; Returns:
      ;;   - A:      The result list
      ;;   - LA:     The length of the result list
      ;;   - UNUSED: The unused tail of U.

      (define (grow s ls ls2 u lw)	; The core of the sort algorithm.
        (if (or (<= lw ls) (not (pair? u)))	; Met quota or out of data?
          (values s ls u)			; If so, we're done.
          (mlet (((ls2) (let lp ((ls2 ls2))
                          (let ((ls2*2 (+ ls2 ls2)))
                            (if (<= ls2*2 ls) (lp ls2*2) ls2))))
                 ;; LS2 is now the largest power of two <= LS.
                 ;; (Just think of it as being roughly LS.)
                 ((r lr u2)  (getrun u))			; Get a run, then
                 ((t lt u3)  (grow r lr 1 u2 ls2))) 	; grow it up to be T.
                (grow (merge s t) (+ ls lt)	 		; Merge S & T, 
                      (+ ls2 ls2) u3 lw))))	     		;   and loop.

      ;; Note: (LENGTH LIS) or any constant guaranteed 
      ;; to be greater can be used in place of INFINITY.
      (if (pair? lis)				; Don't sort an empty list.
        (mlet (((r lr tail)  (getrun lis))	; Pick off an initial run,
               ((infinity)   #o100000000)		; then grow it up maximally.
               ((a la v)     (grow r lr 1 tail infinity)))
              a)
        '()))


    ;;; (list-merge-sort! < lis)
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; A natural, stable, destructive, in-place list merge sort. 
    ;;; - natural: picks off maximal contiguous runs of pre-ordered data.
    ;;; - stable: won't invert the order of equal elements in the input list.
    ;;; - destructive, in-place: this routine allocates no extra working memory; 
    ;;;   it simply rearranges the list with SET-CDR! operations.

    (define (list-merge-sort! elt< lis)
      ;; (getrun lis) -> runlen last rest
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; Pick a run of non-decreasing data off of non-empty list LIS. 
      ;; Return the length of this run, the last cons cell of the run,
      ;; and the following list.
      (define (getrun lis)
        (let lp ((lis lis) (x (car lis)) (i 1) (next (cdr lis)))
          (if (pair? next)
            (let ((y (car next)))
              (if (elt< y x) 
                (values i lis next)
                (lp next y (+ i 1) (cdr next))))
            (values i lis next))))

      ;; (merge! a enda b endb) -> [m endm]
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; Destructively and stably merge non-empty lists A & B.
      ;; The last cons of A is ENDA. (The cdr of ENDA can be non-nil.)
      ;; the last cons of B is ENDB. (The cdr of ENDB can be non-nil.)
      ;;
      ;; Return the first and last cons cells of the merged list.
      ;; This routine is iterative & in-place: it runs in constant stack and 
      ;; doesn't allocate any cons cells. It is also tedious but simple; don't
      ;; bother reading it unless necessary.
      (define (merge! a enda b endb)
        ;; The logic of these two loops is completely driven by these invariants:
        ;;   SCAN-A: (CDR PREV) = A. X = (CAR A). Y = (CAR B).
        ;;   SCAN-B: (CDR PREV) = B. X = (CAR A). Y = (CAR B).
        (letrec ((scan-a (lambda (prev  x a  y b)     ; Zip down A until we
                           (cond ((elt< y x)          ; find an elt > (CAR B).
                                  (set-cdr! prev b)
                                  (let ((next-b (cdr b)))
                                    (if (eq? b endb)
                                      (begin (set-cdr! b a) enda) ; Done.
                                      (scan-b b x a (car next-b) next-b))))

                                 ((eq? a enda) (maybe-set-cdr! a b) endb) ; Done.

                                 (else (let ((next-a (cdr a)))  ; Continue scan.
                                         (scan-a a (car next-a) next-a y b))))))

                 (scan-b (lambda (prev  x a  y b)     ; Zip down B while its
                           (cond ((elt< y x)          ; elts are < (CAR A).
                                  (if (eq? b endb) 
                                    (begin (set-cdr! b a) enda)      ; Done.
                                    (let ((next-b (cdr b))) ; Continue scan.
                                      (scan-b b x a (car next-b) next-b))))

                                 (else (set-cdr! prev a)
                                       (if (eq? a enda) 
                                         (begin (maybe-set-cdr! a b) endb) ; Done.
                                         (let ((next-a (cdr a)))
                                           (scan-a a (car next-a) next-a y b)))))))

                 ;; This guy only writes if he has to. Called at most once.
                 ;; Pointer equality rules; pure languages are for momma's boys.
                 (maybe-set-cdr! (lambda (pair val) (if (not (eq? (cdr pair) val)) 
                                                      (set-cdr! pair val)))))

          (let ((x (car a))  (y (car b)))
            (if (elt< y x)

              ;; B starts the answer list.
              (values b (if (eq? b endb)
                          (begin (set-cdr! b a) enda)
                          (let ((next-b (cdr b)))
                            (scan-b b x a (car next-b) next-b))))

              ;; A starts the answer list.
              (values a (if (eq? a enda) 
                          (begin (maybe-set-cdr! a b) endb)
                          (let ((next-a (cdr a)))
                            (scan-a a (car next-a) next-a y b))))))))

      ;; (grow s ends ls ls2 u lw) -> [a enda la unused]
      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      ;; The core routine.
      ;; - S is a sorted list of length LS > 1, with final cons cell ENDS.
      ;;   (CDR ENDS) doesn't have to be nil.
      ;; - LS2 is some power of two <= LS.
      ;; - U is an unsorted list. 
      ;; - LW is a positive integer.
      ;; Starting with S, and taking data from U as needed, produce
      ;; a sorted list of *at least* length LW, if there's enough data
      ;; (LW <= LS + length(U)), or use all of U if not.
      ;;
      ;; GROW takes maximal contiguous runs of data from U at a time;
      ;; it is allowed to return a list *longer* than LW if it gets lucky
      ;; with a long run.
      ;;
      ;; The key idea: If you want a merge operation to "pay for itself," the two
      ;; lists being merged should be about the same length. Remember that.
      ;; 
      ;; Returns:
      ;;   - A:      The result list (not properly terminated)
      ;;   - ENDA:   The last cons cell of the result list.
      ;;   - LA:     The length of the result list
      ;;   - UNUSED: The unused tail of U.
      (define (grow s ends ls ls2 u lw)
        (if (and (pair? u) (< ls lw))

          ;; We haven't met the LW quota but there's still some U data to use.
          (mlet (((ls2) (let lp ((ls2 ls2))
                          (let ((ls2*2 (+ ls2 ls2)))
                            (if (<= ls2*2 ls) (lp ls2*2) ls2))))
                 ;; LS2 is now the largest power of two <= LS.
                 ;; (Just think of it as being roughly LS.)
                 ((lr endr u2)   (getrun u))		  ; Get a run from U;
                 ((t endt lt u3) (grow u endr lr 1 u2 ls2)) ; grow it up to be T.
                 ((st end-st)    (merge! s ends t endt)))	  ; Merge S & T,
                (grow st end-st (+ ls lt) (+ ls2 ls2) u3 lw))	  ; then loop.

          (values s ends ls u))) ; Done -- met LW quota or ran out of data.

      ;; Note: (LENGTH LIS) or any constant guaranteed
      ;; to be greater can be used in place of INFINITY.
      (if (pair? lis)
        (mlet (((lr endr rest)  (getrun lis))	; Pick off an initial run.
               ((infinity)      #o100000000)	; Then grow it up maximally.
               ((a enda la v)   (grow lis endr lr 1 rest infinity)))
              (set-cdr! enda '())			; Nil-terminate answer.
              a)					; We're done.

        '()))					; Don't sort an empty list.


    ;;; Merge
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; These two merge procedures are stable -- ties favor list A.

    (define (list-merge < a b)
      (cond ((not (pair? a)) b)
            ((not (pair? b)) a)
            (else (let recur ((x (car a)) (a a)	; A is a pair; X = (CAR A).
                                          (y (car b)) (b b))	; B is a pair; Y = (CAR B).
                    (if (< y x)

                      (let ((b (cdr b)))
                        (if (pair? b)
                          (cons y (recur x a (car b) b))
                          (cons y a)))

                      (let ((a (cdr a)))
                        (if (pair? a)
                          (cons x (recur (car a) a y b))
                          (cons x b))))))))


    ;;; This destructive merge does as few SET-CDR!s as it can -- for example, if
    ;;; the list is already sorted, it does no SET-CDR!s at all. It is also
    ;;; iterative, running in constant stack.

    (define (list-merge! < a b)
      ;; The logic of these two loops is completely driven by these invariants:
      ;;   SCAN-A: (CDR PREV) = A. X = (CAR A). Y = (CAR B).
      ;;   SCAN-B: (CDR PREV) = B. X = (CAR A). Y = (CAR B).
      (letrec ((scan-a (lambda (prev a x b y)		; Zip down A doing
                         (if (< y x)			; no SET-CDR!s until
                           (let ((next-b (cdr b)))	; we hit a B elt that
                             (set-cdr! prev b)		; has to be inserted.
                             (if (pair? next-b)
                               (scan-b b a x next-b (car next-b))
                               (set-cdr! b a)))

                           (let ((next-a (cdr a)))
                             (if (pair? next-a)
                               (scan-a a next-a (car next-a) b y)
                               (set-cdr! a b))))))

               (scan-b (lambda (prev a x b y)		; Zip down B doing
                         (if (< y x)			; no SET-CDR!s until 
                           (let ((next-b (cdr b)))	; we hit an A elt that
                             (if (pair? next-b)			  ; has to be
                               (scan-b b a x next-b (car next-b)) ; inserted.
                               (set-cdr! b a))) 

                           (let ((next-a (cdr a)))
                             (set-cdr! prev a)
                             (if (pair? next-a)
                               (scan-a a next-a (car next-a) b y)
                               (set-cdr! a b)))))))

        (cond ((not (pair? a)) b)
              ((not (pair? b)) a)

              ;; B starts the answer list.
              ((< (car b) (car a))
               (let ((next-b (cdr b)))
                 (if (null? next-b)
                   (set-cdr! b a)
                   (scan-b b a (car a) next-b (car next-b))))
               b)

              ;; A starts the answer list.
              (else (let ((next-a (cdr a)))
                      (if (null? next-a)
                        (set-cdr! a b)
                        (scan-a a next-a (car next-a) b (car b))))
                    a))))

    ;;; (list-sorted? < lis) -> boolean
    ;;; (vector-sorted? < v [start end]) -> boolean

    (define (list-sorted? < list)
      (or (not (pair? list))
          (let lp ((prev (car list)) (tail (cdr list)))
            (or (not (pair? tail))
                (let ((next (car tail)))
                  (and (not (< next prev))
                       (lp next (cdr tail))))))))

    (define (vector-sorted? elt< v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)
          (or (>= start end)			; Empty range
              (let lp ((i (+ start 1)) (vi-1 (vector-ref v start)))
                (or (>= i end)
                    (let ((vi (vector-ref v i)))
                      (and (not (elt< vi vi-1))
                           (lp (+ i 1) vi)))))))))

    (define (vector-portion-copy! target src start end)
      (let ((len (- end start)))
        (do ((i (- len 1) (- i 1))
             (j (- end 1) (- j 1)))
          ((< i 0))
          (vector-set! target i (vector-ref src j)))))

    (define (has-element list index)
      (cond
        ((zero? index)
         (if (pair? list)
           (values #t (car list))
           (values #f #f)))
        ((null? list)
         (values #f #f))
        (else
          (has-element (cdr list) (- index 1)))))

    (define (list-ref-or-default list index default)
      (call-with-values
        (lambda () (has-element list index))
        (lambda (has? maybe)
          (if has?
            maybe
            default))))

    (define (vector-start+end vector maybe-start+end)
      (let ((start (list-ref-or-default maybe-start+end
                                        0 0))
            (end (list-ref-or-default maybe-start+end
                                      1 (vector-length vector))))
        (values start end)))

    (define (vectors-start+end-2 vector-1 vector-2 maybe-start+end)
      (let ((start-1 (list-ref-or-default maybe-start+end
                                          0 0))
            (end-1 (list-ref-or-default maybe-start+end
                                        1 (vector-length vector-1)))
            (start-2 (list-ref-or-default maybe-start+end
                                          2 0))
            (end-2 (list-ref-or-default maybe-start+end
                                        3 (vector-length vector-2))))
        (values start-1 end-1
                start-2 end-2)))

    ;;; Two key facts
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; If a heap structure is embedded into a vector at indices [start,end), then:
    ;;;   1. The two children of index k are start + 2*(k-start) + 1 = k*2-start+1
    ;;;                                  and start + 2*(k-start) + 2 = k*2-start+2.
    ;;;
    ;;;   2. The first index of a leaf node in the range [start,end) is
    ;;;          first-leaf = floor[(start+end)/2]
    ;;;      (You can deduce this from fact #1 above.) 
    ;;;      Any index before FIRST-LEAF is an internal node.

    (define (really-vector-heap-sort! elt< v start end)
      ;; Vector V contains a heap at indices [START,END). The heap is in heap
      ;; order in the range (I,END) -- i.e., every element in this range is >=
      ;; its children. Bubble HEAP[I] down into the heap to impose heap order on
      ;; the range [I,END).
      (define (restore-heap! end i)
        (let* ((vi (vector-ref v i))
               (first-leaf (quotient (+ start end) 2)) ; Can fixnum overflow.
               (final-k (let lp ((k i))
                          (if (>= k first-leaf)
                            k		; Leaf, so done.
                            (let* ((k*2-start (+ k (- k start))) ; Don't overflow.
                                   (child1 (+ 1 k*2-start))
                                   (child2 (+ 2 k*2-start))
                                   (child1-val (vector-ref v child1)))
                              (call-with-values
                                (lambda ()
                                  (if (< child2 end)
                                    (let ((child2-val (vector-ref v child2)))
                                      (if (elt< child2-val child1-val)
                                        (values child1 child1-val)
                                        (values child2 child2-val)))
                                    (values child1 child1-val)))
                                (lambda (max-child max-child-val)
                                  (cond ((elt< vi max-child-val)
                                         (vector-set! v k max-child-val)
                                         (lp max-child))
                                        (else k))))))))) ; Done.
          (vector-set! v final-k vi)))

      ;; Put the unsorted subvector V[start,end) into heap order.
      (let ((first-leaf (quotient (+ start end) 2)))  ; Can fixnum overflow.
        (do ((i (- first-leaf 1) (- i 1)))
          ((< i start))
          (restore-heap! end i)))

      (do ((i (- end 1) (- i 1)))
        ((<= i start))
        (let ((top (vector-ref v start)))
          (vector-set! v start (vector-ref v i))
          (vector-set! v i top)
          (restore-heap! i start))))

    ;;; Here are the two exported interfaces.

    (define (vector-heap-sort! elt< v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)
          (really-vector-heap-sort! elt< v start end))))

    ;;; Notes on porting
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; 
    ;;; Bumming the code for speed
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; If you can use a module system to lock up the internal function
    ;;; REALLY-VECTOR-HEAP-SORT! so that it can only be called from VECTOR-HEAP-SORT and
    ;;; VECTOR-HEAP-SORT!, then you can hack the internal functions to run with no safety
    ;;; checks. The safety checks performed by the exported functions VECTOR-HEAP-SORT &
    ;;; VECTOR-HEAP-SORT! guarantee that there will be no type errors or array-indexing
    ;;; errors. In addition, with the exception of the two computations of
    ;;; FIRST-LEAF, all arithmetic will be fixnum arithmetic that never overflows
    ;;; into bignums, assuming your Scheme provides that you can't allocate an
    ;;; array so large you might need a bignum to index an element, which is
    ;;; definitely the case for every implementation with which I am familiar. 
    ;;;
    ;;; If you want to code up the first-leaf = (quotient (+ s e) 2) computation
    ;;; so that it will never fixnum overflow when S & E are fixnums, you can do
    ;;; it this way:
    ;;;   - compute floor(e/2), which throws away e's low-order bit.
    ;;;   - add e's low-order bit to s, and divide that by two:
    ;;;     floor[(s + e mod 2) / 2]
    ;;;   - add these two parts together.
    ;;; giving you
    ;;;   (+ (quotient e 2)
    ;;;      (quotient (+ s (modulo e 2)) 2))
    ;;; If we know that e & s are fixnums, and that 0 <= s <= e, then this
    ;;; can only fixnum-overflow when s = e = max-fixnum. Note that the
    ;;; two divides and one modulo op can be done very quickly with two 
    ;;; right-shifts and a bitwise and.
    ;;;
    ;;; I suspect there has never been a heapsort written in the history of
    ;;; the world in C that got this detail right.

    ;;; Merge
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; (vector-merge < v1 v2 [start1 end1 start2 end2]) -> vector
    ;;; (vector-merge! < v v1 v2 [start start1 end1 start2 end2]) -> unspecific
    ;;;
    ;;; Stable vector merge -- V1's elements come out ahead of equal V2 elements.

    (define (vector-merge < v1 v2 . maybe-starts+ends)
      (call-with-values
        (lambda () (vectors-start+end-2 v1 v2 maybe-starts+ends))
        (lambda (start1 end1 start2 end2)
          (let ((ans (make-vector (+ (- end1 start1) (- end2 start2)))))
            (%vector-merge! < ans v1 v2 0 start1 end1 start2 end2)
            ans))))

    (define (vector-merge! < v v1 v2 . maybe-starts+ends)
      (call-with-values
        (lambda ()
          (if (pair? maybe-starts+ends)
            (values (car maybe-starts+ends)
                    (cdr maybe-starts+ends))
            (values 0
                    '())))
        (lambda (start rest)
          (call-with-values
            (lambda () (vectors-start+end-2 v1 v2 rest))
            (lambda (start1 end1 start2 end2)
              (%vector-merge! < v v1 v2 start start1 end1 start2 end2))))))


    ;;; This routine is not exported. The code is tightly bummed.
    ;;;
    ;;; If these preconditions hold, the routine can be bummed to run with 
    ;;; unsafe vector-indexing and fixnum arithmetic ops:
    ;;;   - V V1 V2 are vectors.
    ;;;   - START START1 END1 START2 END2 are fixnums.
    ;;;   - (<= 0 START END0 (vector-length V),
    ;;;     where end0 = start + (end1 - start1) + (end2 - start2)
    ;;;   - (<= 0 START1 END1 (vector-length V1))
    ;;;   - (<= 0 START2 END2 (vector-length V2))
    ;;; If you put these error checks in the two client procedures above, you can
    ;;; safely convert this procedure to use unsafe ops -- which is why it isn't
    ;;; exported. This will provide *huge* speedup.

    (define (%vector-merge! elt< v v1 v2 start start1 end1 start2 end2)
      (letrec ((vblit (lambda (fromv j i end) ; Blit FROMV[J,END) to V[I,?].
                        (let lp ((j j) (i i))
                          (vector-set! v i (vector-ref fromv j))
                          (let ((j (+ j 1)))
                            (if (< j end) (lp j (+ i 1))))))))

        (cond ((<= end1 start1) (if (< start2 end2) (vblit v2 start2 start end2)))
              ((<= end2 start2) (vblit v1 start1 start end1))

              ;; Invariants: I is next index of V to write; X = V1[J]; Y = V2[K].
              (else (let lp ((i start)
                             (j start1)  (x (vector-ref v1 start1))
                             (k start2)  (y (vector-ref v2 start2)))
                      (let ((i1 (+ i 1)))	; "i+1" is a complex number in R4RS!
                        (if (elt< y x)
                          (let ((k (+ k 1)))
                            (vector-set! v i y)
                            (if (< k end2)
                              (lp i1 j x k (vector-ref v2 k))
                              (vblit v1 j i1 end1)))
                          (let ((j (+ j 1)))
                            (vector-set! v i x)
                            (if (< j end1)
                              (lp i1 j (vector-ref v1 j) k y)
                              (vblit v2 k i1 end2))))))))))


    ;;; (vector-merge-sort  < v [start end temp]) -> vector
    ;;; (vector-merge-sort! < v [start end temp]) -> unspecific
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; Stable natural vector merge sort

    (define (vector-merge-sort! < v . maybe-args)
      (call-with-values
        (lambda () (vector-start+end v maybe-args))
        (lambda (start end)
          (let ((temp (if (and (pair? maybe-args) ; kludge
                               (pair? (cdr maybe-args))
                               (pair? (cddr maybe-args)))
                        (caddr maybe-args)
                        (vector-copy v))))
            (%vector-merge-sort! < v start end temp)))))

    (define (vector-merge-sort < v . maybe-args)
      (call-with-values
        (lambda () (vector-start+end v maybe-args))
        (lambda (start end)
          (let ((ans (vector-copy v start end)))
            (vector-merge-sort! < ans)
            ans))))


    ;;; %VECTOR-MERGE-SORT! is not exported.
    ;;; Preconditions:
    ;;;   V TEMP vectors
    ;;;   START END fixnums
    ;;;   START END legal indices for V and TEMP
    ;;; If these preconditions are ensured by the cover functions, you
    ;;; can safely change this code to use unsafe fixnum arithmetic and vector
    ;;; indexing ops, for *huge* speedup.

    ;;; This merge sort is "opportunistic" -- the leaves of the merge tree are
    ;;; contiguous runs of already sorted elements in the vector. In the best
    ;;; case -- an already sorted vector -- it runs in linear time. Worst case
    ;;; is still O(n lg n) time.

    (define (%vector-merge-sort! elt< v0 l r temp0)
      (define (xor a b) (not (eq? a b)))

      ;; Merge v1[l,l+len1) and v2[l+len1,l+len1+len2) into target[l,l+len1+len2)
      ;; Merge left-to-right, so that TEMP may be either V1 or V2
      ;; (that this is OK takes a little bit of thought).
      ;; V2=TARGET? is true if V2 and TARGET are the same, which allows
      ;; merge to punt the final blit half of the time.

      (define (merge target v1 v2 l len1 len2 v2=target?)
        (letrec ((vblit (lambda (fromv j i end)    ; Blit FROMV[J,END) to TARGET[I,?]
                          (let lp ((j j) (i i))    ; J < END. The final copy.
                            (vector-set! target i (vector-ref fromv j))
                            (let ((j (+ j 1)))
                              (if (< j end) (lp j (+ i 1))))))))

          (let* ((r1 (+ l  len1))
                 (r2 (+ r1 len2)))
            ; Invariants:
            (let lp ((n l)					; N is next index of 
                     (j l)   (x (vector-ref v1 l))		;   TARGET to write.   
                     (k r1)  (y (vector-ref v2 r1)))	; X = V1[J]          
              (let ((n+1 (+ n 1)))				; Y = V2[K]          
                (if (elt< y x)
                  (let ((k (+ k 1)))
                    (vector-set! target n y)
                    (if (< k r2)
                      (lp n+1 j x k (vector-ref v2 k))
                      (vblit v1 j n+1 r1)))
                  (let ((j (+ j 1)))
                    (vector-set! target n x)
                    (if (< j r1)
                      (lp n+1 j (vector-ref v1 j) k y)
                      (if (not v2=target?) (vblit v2 k n+1 r2))))))))))


      ;; Might hack GETRUN so that if the run is short it pads it out to length
      ;; 10 with insert sort...

      ;; Precondition: l < r.
      (define (getrun v l r)
        (let lp ((i (+ l 1))  (x (vector-ref v l)))
          (if (>= i r)
            (- i l)
            (let ((y (vector-ref v i)))
              (if (elt< y x)
                (- i l)
                (lp (+ i 1) y))))))

      ;; RECUR: Sort V0[L,L+LEN) for some LEN where 0 < WANT <= LEN <= (R-L).
      ;;   That is, sort *at least* WANT elements in V0 starting at index L.
      ;;   May put the result into either V0[L,L+LEN) or TEMP0[L,L+LEN).
      ;;   Must not alter either vector outside this range.
      ;;   Return:
      ;;     - LEN -- the number of values we sorted
      ;;     - ANSVEC -- the vector holding the value
      ;;     - ANS=V0? -- tells if ANSVEC is V0 or TEMP
      ;;
      ;; LP: V[L,L+PFXLEN) holds a sorted prefix of V0.
      ;;     TEMP = if V = V0 then TEMP0 else V0. (I.e., TEMP is the other vec.)
      ;;     PFXLEN2 is a power of 2 <= PFXLEN.
      ;;     Solve RECUR's problem.
      (if (< l r) ; Don't try to sort an empty range.
        (call-with-values
          (lambda ()
            (let recur ((l l) (want (- r l)))
              (let ((len (- r l)))
                (let lp ((pfxlen (getrun v0 l r)) (pfxlen2 1)
                                                  (v v0) (temp temp0)
                                                  (v=v0? #t))
                  (if (or (>= pfxlen want) (= pfxlen len))
                    (values pfxlen v v=v0?)
                    (let ((pfxlen2 (let lp ((j pfxlen2))
                                     (let ((j*2 (+ j j)))
                                       (if (<= j pfxlen) (lp j*2) j))))
                          (tail-len (- len pfxlen)))
                      ;; PFXLEN2 is now the largest power of 2 <= PFXLEN.
                      ;; (Just think of it as being roughly PFXLEN.)
                      (call-with-values
                        (lambda ()
                          (recur (+ pfxlen l) pfxlen2))
                        (lambda (nr-len nr-vec nrvec=v0?)
                          (merge temp v nr-vec l pfxlen nr-len
                                 (xor nrvec=v0? v=v0?))
                          (lp (+ pfxlen nr-len) (+ pfxlen2 pfxlen2)
                              temp v (not v=v0?))))))))))
          (lambda (ignored-len ignored-ansvec ansvec=v0?)
            (if (not ansvec=v0?)
              (vector-copy! v0 l temp0 l r))))))

    ;;; (quick-sort  < v [start end]) -> vector
    ;;; (quick-sort! < v [start end]) -> unspecific
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;; The algorithm is a standard quicksort, but the partition loop is fancier,
    ;;; arranging the vector into a left part that is <, a middle region that is
    ;;; =, and a right part that is > the pivot. Here's how it is done:
    ;;;   The partition loop divides the range being partitioned into five 
    ;;;   subranges:
    ;;;       =======<<<<<<<<<?????????>>>>>>>=======
    ;;;   where = marks a value that is equal the pivot, < marks a value that
    ;;;   is less than the pivot, ? marks a value that hasn't been scanned, and
    ;;;   > marks a value that is greater than the pivot. Let's consider the 
    ;;;   left-to-right scan. If it checks a ? value that is <, it keeps scanning.
    ;;;   If the ? value is >, we stop the scan -- we are ready to start the
    ;;;   right-to-left scan and then do a swap. But if the rightward scan checks 
    ;;;   a ? value that is =, we swap it *down* to the end of the initial chunk
    ;;;   of ====='s -- we exchange it with the leftmost < value -- and then
    ;;;   continue our rightward scan. The leftwards scan works in a similar 
    ;;;   fashion, scanning past > elements, stopping on a < element, and swapping
    ;;;   up = elements. When we are done, we have a picture like this
    ;;;       ========<<<<<<<<<<<<>>>>>>>>>>=========
    ;;;   Then swap the = elements up into the middle of the vector to get
    ;;;   this:
    ;;;       <<<<<<<<<<<<=================>>>>>>>>>>
    ;;;   Then recurse on the <'s and >'s. Work out all the tricky little
    ;;;   boundary cases, and you're done.
    ;;;
    ;;; Other tricks:
    ;;; - This quicksort also makes some effort to pick the pivot well -- it uses
    ;;;   the median of three elements as the partition pivot, so pathological n^2
    ;;;   run time is much rarer (but not eliminated completely). If you really
    ;;;   wanted to get fancy, you could use a random number generator to choose
    ;;;   pivots. The key to this trick is that you only need to pick one random
    ;;;   number for each *level* of recursion -- i.e. you only need (lg n) random
    ;;;   numbers. 
    ;;; - After the partition, we *recurse* on the smaller of the two pending
    ;;;   regions, then *tail-recurse* (iterate) on the larger one. This guarantees
    ;;;   we use no more than lg(n) stack frames, worst case.
    ;;; - There are two ways to finish off the sort.
    ;;;   A Recurse down to regions of size 10, then sort each such region using
    ;;;     insertion sort.
    ;;;   B Recurse down to regions of size 10, then sort *the entire vector*
    ;;;     using insertion sort.
    ;;;   We do A. Each choice has a cost. Choice A has more overhead to invoke
    ;;;   all the separate insertion sorts -- choice B only calls insertion sort
    ;;;   once. But choice B will call the comparison function *more times* --
    ;;;   it will unnecessarily compare elt 9 of one segment to elt 0 of the
    ;;;   following segment. The overhead of choice A is linear in the length
    ;;;   of the vector, but *otherwise independent of the algorithm's parameters*.
    ;;;   I.e., it's a *fixed*, *small* constant factor. The cost of the extra 
    ;;;   comparisons made by choice B, however, is dependent on an externality: 
    ;;;   the comparison function passed in by the client. This can be made 
    ;;;   arbitrarily bad -- that is, the constant factor *isn't* fixed by the
    ;;;   sort algorithm; instead, it's determined by the comparison function.
    ;;;   If your comparison function is very, very slow, you want to eliminate
    ;;;   every single one that you can. Choice A limits the potential badness, 
    ;;;   so that is what we do.

    (define (%vector-insert-sort! elt< v start end)
      (do ((i (+ 1 start) (+ i 1)))	; Invariant: [start,i) is sorted.
        ((>= i end))
        (let ((val (vector-ref v i)))
          (vector-set! v (let lp ((j i))		; J is the location of the
                           (if (<= j start)
                             start	; "hole" as it bubbles down.
                             (let* ((j-1 (- j 1))
                                    (vj-1 (vector-ref v j-1)))
                               (cond ((elt< val vj-1)
                                      (vector-set! v j vj-1)
                                      (lp j-1))
                                     (else j)))))
                       val))))

    (define (vector-quick-sort! < v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)
          (%quick-sort! < v start end))))

    (define (vector-quick-sort < v . maybe-start+end)
      (call-with-values
        (lambda () (vector-start+end v maybe-start+end))
        (lambda (start end)
          (let ((ans (make-vector (- end start))))
            (vector-portion-copy! ans v start end)
            (%quick-sort! < ans 0 (- end start))
            ans))))

    ;;; %QUICK-SORT is not exported.
    ;;; Preconditions:
    ;;;   V vector
    ;;;   START END fixnums
    ;;;   0 <= START, END <= (vector-length V)
    ;;; If these preconditions are ensured by the cover functions, you
    ;;; can safely change this code to use unsafe fixnum arithmetic and vector
    ;;; indexing ops, for *huge* speedup.
    ;;;
    ;;; We bail out to insertion sort for small ranges; feel free to tune the
    ;;; crossover -- it's just a random guess. If you don't have the insertion
    ;;; sort routine, just kill that branch of the IF and change the recursion
    ;;; test to (< 1 (- r l)) -- the code is set up to work that way.

    (define (%quick-sort! elt< v start end)
      ;; Swap the N outer pairs of the range [l,r).
      (define (swap l r n)
        (if (> n 0)
          (let ((x   (vector-ref v l))
                (r-1 (- r 1)))
            (vector-set! v l   (vector-ref v r-1))
            (vector-set! v r-1 x)
            (swap (+ l 1) r-1 (- n 1)))))

      ;; Choose the median of V[l], V[r], and V[middle] for the pivot.
      (define (median v1 v2 v3)
        (call-with-values
          (lambda () (if (elt< v1 v2) (values v1 v2) (values v2 v1)))
          (lambda (little big)
            (if (elt< big v3)
              big
              (if (elt< little v3) v3 little)))))

      (let recur ((l start) (r end))	; Sort the range [l,r).
        (if (< 10 (- r l))	     ; Ten: the gospel according to Sedgewick.

          (let ((pivot (median (vector-ref v l)
                               (vector-ref v (quotient (+ l r) 2))
                               (vector-ref v (- r 1)))))

            ;; Everything in these loops is driven by the invariants expressed
            ;; in the little pictures & the corresponding l,i,j,k,m,r indices
            ;; and the associated ranges.

            ;; =======<<<<<<<<<?????????>>>>>>>=======
            ;; l      i        j       k      m       r
            ;; [l,i)  [i,j)      [j,k]    (k,m]  (m,r)
            (letrec ((lscan (lambda (i j k m) ; left-to-right scan
                              (let lp ((i i) (j j))
                                (if (> j k)
                                  (done i j m)
                                  (let ((x (vector-ref v j)))
                                    (cond ((elt< x pivot) (lp i (+ j 1)))

                                          ((elt< pivot x) (rscan i j k m))

                                          (else ; Equal
                                            (if (< i j)
                                              (begin (vector-set! v j (vector-ref v i))
                                                     (vector-set! v i x)))
                                            (lp (+ i 1) (+ j 1)))))))))

                     ;; =======<<<<<<<<<>????????>>>>>>>=======
                     ;; l      i        j       k      m       r
                     ;; [l,i)  [i,j)    j (j,k]    (k,m]  (m,r)
                     (rscan (lambda (i j k m) ; right-to-left scan
                              (let lp ((k k) (m m))	
                                (if (<= k j)
                                  (done i j m)
                                  (let* ((x (vector-ref v k)))
                                    (cond ((elt< pivot x) (lp (- k 1) m))

                                          ((elt< x pivot) ; Swap j & k & lscan.
                                           (vector-set! v k (vector-ref v j))
                                           (vector-set! v j x)
                                           (lscan i (+ j 1) (- k 1) m))

                                          (else	; x=pivot
                                            (if (< k m)
                                              (begin (vector-set! v k (vector-ref v m))
                                                     (vector-set! v m x)))
                                            (lp (- k 1) (- m 1)))))))))


                     ;; =======<<<<<<<<<<<<<>>>>>>>>>>>=======
                     ;; l      i            j         m       r
                     ;; [l,i)  [i,j)        [j,m]        (m,r)
                     (done (lambda (i j m)
                             (let ((num< (- j i))
                                   (num> (+ 1 (- m j)))
                                   (num=l (- i l))
                                   (num=r (- (- r m) 1)))
                               (swap l j (min num< num=l)) ; Swap ='s into
                               (swap j r (min num> num=r)) ; the middle.
                               ;; Recur on the <'s and >'s. Recurring on the
                               ;; smaller range and iterating on the bigger 
                               ;; range ensures O(lg n) stack frames, worst case.
                               (cond ((<= num< num>)
                                      (recur l          (+ l num<))
                                      (recur (- r num>) r))
                                     (else
                                       (recur (- r num>) r)
                                       (recur l          (+ l num<))))))))

              (let ((r-1 (- r 1)))
                (lscan l l r-1 r-1))))

          ;; Small segment => punt to insert sort.
          ;; Use the dangerous subprimitive.
          (%vector-insert-sort! elt< v l r))))

    ;;; This file just defines the general sort API in terms of some
    ;;; algorithm-specific calls.

    (define (list-sort < l)			; Sort lists by converting to
      (let ((v (list->vector l)))		; a vector and sorting that.
        (vector-heap-sort! < v)
        (vector->list v)))

    (define list-sort! list-merge-sort!)

    (define list-stable-sort  list-merge-sort)
    (define list-stable-sort! list-merge-sort!)

    (define vector-sort  vector-quick-sort)
    (define vector-sort! vector-quick-sort!)

    (define vector-stable-sort  vector-merge-sort)
    (define vector-stable-sort! vector-merge-sort!)

    ;;; Linear-time (average case) algorithms for:
    ;;;
    ;;; Selecting the kth smallest element from an unsorted vector.
    ;;; Selecting the kth and (k+1)st smallest elements from an unsorted vector.
    ;;; Selecting the median from an unsorted vector.

    ;;; These procedures are part of SRFI 132 but are missing from
    ;;; its reference implementation as of 10 March 2016.

    ;;; SRFI 132 says this procedure runs in O(n) time.
    ;;; As implemented, however, the worst-case time is O(n^2) because
    ;;; vector-select is implemented using randomized quickselect.
    ;;; The average time is O(n), and you'd have to be unlucky
    ;;; to approach the worst case.

    (define (vector-find-median < v knil . rest)
      (let* ((mean (if (null? rest)
                     (lambda (a b) (/ (+ a b) 2))
                     (car rest)))
             (n (vector-length v)))
        (cond ((zero? n)
               knil)
              ((odd? n)
               (%vector-select < v (quotient n 2) 0 n))
              (else
                (call-with-values
                  (lambda () (%vector-select2 < v (- (quotient n 2) 1) 0 n))
                  (lambda (a b)
                    (mean a b)))))))

    ;;; For this procedure, the SRFI 132 specification
    ;;; demands the vector be sorted (by side effect).

    (define (vector-find-median! < v knil . rest)
      (let* ((mean (if (null? rest)
                     (lambda (a b) (/ (+ a b) 2))
                     (car rest)))
             (n (vector-length v)))
        (vector-sort! < v)
        (cond ((zero? n)
               knil)
              ((odd? n)
               (vector-ref v (quotient n 2)))
              (else
                (mean (vector-ref v (- (quotient n 2) 1))
                      (vector-ref v (quotient n 2)))))))

    ;;; SRFI 132 says this procedure runs in O(n) time.
    ;;; As implemented, however, the worst-case time is O(n^2).
    ;;; The average time is O(n), and you'd have to be unlucky
    ;;; to approach the worst case.
    ;;;
    ;;; After rest argument processing, calls the private version defined below.

    (define (vector-select < v k . rest)
      (let* ((start (if (null? rest)
                      0
                      (car rest)))
             (end (if (and (pair? rest)
                           (pair? (cdr rest)))
                    (car (cdr rest))
                    (vector-length v))))
        (%vector-select < v k start end)))

    ;;; The vector-select procedure is needed internally to implement
    ;;; vector-find-median, but SRFI 132 has been changed (for no good
    ;;; reason) to export vector-select! instead of vector-select.
    ;;; Fortunately, vector-select! is not required to have side effects.

    (define vector-select! vector-select)

    ;;; This could be made slightly more efficient, but who cares?

    (define (vector-separate! < v k . rest)
      (let* ((start (if (null? rest)
                      0
                      (car rest)))
             (end (if (and (pair? rest)
                           (pair? (cdr rest)))
                    (car (cdr rest))
                    (vector-length v))))
        (if (and (> k 0)
                 (> end start))
          (let ((pivot (vector-select < v (- k 1) start end)))
            (call-with-values
              (lambda () (count-smaller < pivot v start end 0 0))
              (lambda (count count2)
                (let* ((v2 (make-vector count))
                       (v3 (make-vector (- end start count count2))))
                  (copy-smaller! < pivot v2 0 v start end)
                  (copy-bigger! < pivot v3 0 v start end)
                  (vector-copy! v start v2)
                  (vector-fill! v pivot (+ start count) (+ start count count2))
                  (vector-copy! v (+ start count count2) v3))))))))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;;; For small ranges, sorting may be the fastest way to find the kth element.
    ;;; This threshold is not at all critical, and may not even be worthwhile.

    (define just-sort-it-threshold 50)

    ;;; Given
    ;;;     an irreflexive total order <?
    ;;;     a vector v
    ;;;     an index k
    ;;;     an index start
    ;;;     an index end
    ;;; with
    ;;;     0 <= k < (- end start)
    ;;;     0 <= start < end <= (vector-length v)
    ;;; returns
    ;;;     (vector-ref (vector-sort <? (vector-copy v start end)) (+ start k))
    ;;; but is usually faster than that.

    (define (%vector-select <? v k start end)
      (assert (and 'vector-select
                   (procedure? <?)
                   (vector? v)
                   (exact-integer? k)
                   (exact-integer? start)
                   (exact-integer? end)
                   (<= 0 k (- end start 1))
                   (<= 0 start end (vector-length v))))
      (%%vector-select <? v k start end))

    ;;; Given
    ;;;     an irreflexive total order <?
    ;;;     a vector v
    ;;;     an index k
    ;;;     an index start
    ;;;     an index end
    ;;; with
    ;;;     0 <= k < (- end start 1)
    ;;;     0 <= start < end <= (vector-length v)
    ;;; returns two values:
    ;;;     (vector-ref (vector-sort <? (vector-copy v start end)) (+ start k))
    ;;;     (vector-ref (vector-sort <? (vector-copy v start end)) (+ start k 1))
    ;;; but is usually faster than that.

    (define (%vector-select2 <? v k start end)
      (assert (and 'vector-select
                   (procedure? <?)
                   (vector? v)
                   (exact-integer? k)
                   (exact-integer? start)
                   (exact-integer? end)
                   (<= 0 k (- end start 1 1))
                   (<= 0 start end (vector-length v))))
      (%%vector-select2 <? v k start end))

    ;;; Like %vector-select, but its preconditions have been checked.

    (define (%%vector-select <? v k start end)
      (let ((size (- end start)))
        (cond ((= 1 size)
               (vector-ref v (+ k start)))
              ((= 2 size)
               (cond ((<? (vector-ref v start)
                          (vector-ref v (+ start 1)))
                      (vector-ref v (+ k start)))
                     (else
                       (vector-ref v (+ (- 1 k) start)))))
              ((< size just-sort-it-threshold)
               (vector-ref (vector-sort <? (vector-copy v start end)) k))
              (else
                (let* ((ip (random-integer size))
                       (pivot (vector-ref v (+ start ip))))
                  (call-with-values
                    (lambda () (count-smaller <? pivot v start end 0 0))
                    (lambda (count count2)
                      (cond ((< k count)
                             (let* ((n count)
                                    (v2 (make-vector n)))
                               (copy-smaller! <? pivot v2 0 v start end)
                               (%%vector-select <? v2 k 0 n)))
                            ((< k (+ count count2))
                             pivot)
                            (else
                              (let* ((n (- size count count2))
                                     (v2 (make-vector n))
                                     (k2 (- k count count2)))
                                (copy-bigger! <? pivot v2 0 v start end)
                                (%%vector-select <? v2 k2 0 n)))))))))))

    ;;; Like %%vector-select, but returns two values:
    ;;;
    ;;;     (vector-ref (vector-sort <? (vector-copy v start end)) (+ start k))
    ;;;     (vector-ref (vector-sort <? (vector-copy v start end)) (+ start k 1))
    ;;;
    ;;; Returning two values is useful when finding the median of an even
    ;;; number of things.

    (define (%%vector-select2 <? v k start end)
      (let ((size (- end start)))
        (cond ((= 2 size)
               (let ((a (vector-ref v start))
                     (b (vector-ref v (+ start 1))))
                 (cond ((<? a b)
                        (values a b))
                       (else
                         (values b a)))))
              ((< size just-sort-it-threshold)
               (let ((v2 (vector-sort <? (vector-copy v start end))))
                 (values (vector-ref v2 k)
                         (vector-ref v2 (+ k 1)))))
              (else
                (let* ((ip (random-integer size))
                       (pivot (vector-ref v (+ start ip))))
                  (call-with-values
                    (lambda () (count-smaller <? pivot v start end 0 0))
                    (lambda (count count2)
                      (cond ((= (+ k 1) count)
                             (values (%%vector-select <? v k start end)
                                     pivot))
                            ((< k count)
                             (let* ((n count)
                                    (v2 (make-vector n)))
                               (copy-smaller! <? pivot v2 0 v start end)
                               (%%vector-select2 <? v2 k 0 n)))
                            ((< k (+ count count2))
                             (values pivot
                                     (if (< (+ k 1) (+ count count2))
                                       pivot
                                       (%%vector-select <? v (+ k 1) start end))))
                            (else
                              (let* ((n (- size count count2))
                                     (v2 (make-vector n))
                                     (k2 (- k count count2)))
                                (copy-bigger! <? pivot v2 0 v start end)
                                (%%vector-select2 <? v2 k2 0 n)))))))))))

    ;;; Counts how many elements within the range are less than the pivot
    ;;; and how many are equal to the pivot, returning both of those counts.

    (define (count-smaller <? pivot v i end count count2)
      (cond ((= i end)
             (values count count2))
            ((<? (vector-ref v i) pivot)
             (count-smaller <? pivot v (+ i 1) end (+ count 1) count2))
            ((<? pivot (vector-ref v i))
             (count-smaller <? pivot v (+ i 1) end count count2))
            (else
              (count-smaller <? pivot v (+ i 1) end count (+ count2 1)))))

    ;;; Like vector-copy! but copies an element only if it is less than the pivot.
    ;;; The destination vector must be large enough.

    (define (copy-smaller! <? pivot dst at src start end)
      (cond ((= start end) dst)
            ((<? (vector-ref src start) pivot)
             (vector-set! dst at (vector-ref src start))
             (copy-smaller! <? pivot dst (+ at 1) src (+ start 1) end))
            (else
              (copy-smaller! <? pivot dst at src (+ start 1) end))))

    ;;; Like copy-smaller! but copies only elements that are greater than the pivot.

    (define (copy-bigger! <? pivot dst at src start end)
      (cond ((= start end) dst)
            ((<? pivot (vector-ref src start))
             (vector-set! dst at (vector-ref src start))
             (copy-bigger! <? pivot dst (+ at 1) src (+ start 1) end))
            (else
              (copy-bigger! <? pivot dst at src (+ start 1) end))))

    ))

;;; Copyright
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; This code is
;;;     Copyright (c) 1998 by Olin Shivers.
;;; The terms are: You may do as you please with this code, as long as
;;; you do not delete this notice or hold me responsible for any outcome
;;; related to its use.
;;;
;;; Blah blah blah. Don't you think source files should contain more lines
;;; of code than copyright notice?
;;;
;;; Code porting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; If your Scheme has a faster mechanism for handling optional arguments
;;; (e.g., Chez), you should definitely port over to it. Note that argument
;;; defaulting and error-checking are interleaved -- you don't have to
;;; error-check defaulted START/END args to see if they are fixnums that are
;;; legal vector indices for the corresponding vector, etc.


