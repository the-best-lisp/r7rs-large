# R7RS-Large Libraries

The Red Edition of libraries is now frozen:
http://trac.sacrideo.us/wg/wiki/RedEdition

This repository collects implementations of the libraries together using 
the `(scheme NAME)` import form.  Tests are performed on a range of R7RS 
Scheme implementations.  

Tested against:

* Chibi 0.7.3: https://github.com/ashinn/chibi-scheme/
* Gauche 0.9.5: http://practical-scheme.net/gauche/
  * ensure the environment variable GAUCHE_KEYWORD_IS_SYMBOL is set so that 
    keywords are treated as symbols
* Kawa 2.4: https://www.gnu.org/software/kawa/
* Larceny 0.99: http://www.larcenists.org/
* Sagittarius 0.8.3: https://bitbucket.org/ktakashi/sagittarius-scheme/wiki/Home


## Libraries

1. `(scheme list)` from SRFI 1
2. `(scheme vector)` from SRFI 133
3. `(scheme sort)` from SRFI 132
4. `(scheme set)` from SRFI 113 - TODO, relies on hash-table
5. `(scheme charset)` from SRFI 14 - TODO
6. `(scheme hash-table)` from SRFI 125 - TODO, relies on rnrs/srfi-60 htables
7. `(scheme ilist)` from SRFI 116
8. `(scheme rlist)` from SRFI 101
9. `(scheme ideque)` from SRFI 134
10. `(scheme text)` from SRFI 135 - TODO (rnrs)
11. `(scheme generator)` from SRFI 121
12. `(scheme lseq)` from SRFI 127
13. `(scheme stream)` from SRFI 41 - TODO
14. `(scheme box)` from SRFI 111
15. `(scheme list-queue)` from SRFI 117
16. `(scheme ephemeron)` from SRFI 124
17. `(scheme comparator)` from SRFI 128

## Notes

`(scheme generator)` does not work on Kawa due to its continuations being 
unsuitable for implementing coroutines.

`(scheme ephemeron)` requires implementation-specific code.  The trivial 
implementation is provided here, to write code against.

The usual SRFI license applies: http://srfi.schemers.org/

