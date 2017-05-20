# R7RS-Large Libraries

The Red Edition of libraries is now frozen:
http://trac.sacrideo.us/wg/wiki/RedEdition

This repository collects implementations of the libraries together using the
`(scheme NAME)` import form.  Tests (written in srfi-64 form) are run against a
range of R7RS Scheme implementations.  

Tested against:

* Chibi 0.7.3: https://github.com/ashinn/chibi-scheme/
* Gauche 0.9.5: http://practical-scheme.net/gauche/
  * ensure the environment variable GAUCHE_KEYWORD_IS_SYMBOL is set so that 
    keywords are treated as symbols
* Kawa 2.4: https://www.gnu.org/software/kawa/
* Larceny 0.99: http://www.larcenists.org/
* Sagittarius 0.8.4: https://bitbucket.org/ktakashi/sagittarius-scheme/wiki/Home
  * Sagittarius already has built-in support for R7RS large

## Libraries

1. `(scheme list)` from SRFI 1
2. `(scheme vector)` from SRFI 133
3. `(scheme sort)` from SRFI 132
4. `(scheme set)` from SRFI 113 
5. `(scheme charset)` from SRFI 14 - TODO
6. `(scheme hash-table)` from SRFI 125
7. `(scheme ilist)` from SRFI 116
8. `(scheme rlist)` from SRFI 101 
9. `(scheme ideque)` from SRFI 134
10. `(scheme text)` from SRFI 135
11. `(scheme generator)` from SRFI 121
12. `(scheme lseq)` from SRFI 127
13. `(scheme stream)` from SRFI 41
14. `(scheme box)` from SRFI 111
15. `(scheme list-queue)` from SRFI 117
16. `(scheme ephemeron)` from SRFI 124
17. `(scheme comparator)` from SRFI 128

## Notes

`(scheme generator)` does not work on Kawa due to its continuations being 
unsuitable for implementing coroutines.

`(scheme ephemeron)` requires implementation-specific code.  The trivial 
implementation is provided here, to write code against.

`(scheme hash-table)` is based solely on SRFI 69 as this is available and
implemented efficiently in the Schemes I have targetted.  For a non-SRFI 69
implementation the functions prefixed 's69:' will need replacing.  All
hash-tables are mutable.

The usual SRFI license applies: http://srfi.schemers.org/

