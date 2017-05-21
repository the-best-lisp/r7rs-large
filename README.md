# R7RS-Large Libraries

The Red Edition of libraries is now frozen:
http://trac.sacrideo.us/wg/wiki/RedEdition

This repository collects implementations of the libraries together using the
`(scheme NAME)` import form.  Tests (written in SRFI 64 form) are checked
against the following R7RS Scheme implementations:

* Chibi 0.7.3: https://github.com/ashinn/chibi-scheme/
* Gauche 0.9.5: http://practical-scheme.net/gauche/
  * ensure the environment variable GAUCHE_KEYWORD_IS_SYMBOL is set so that 
    keywords are treated as symbols
* Kawa 2.4: https://www.gnu.org/software/kawa/
* Larceny 0.99: http://www.larcenists.org/
* Sagittarius 0.8.4: https://bitbucket.org/ktakashi/sagittarius-scheme/wiki/Home
  * Sagittarius already has built-in support for R7RS large

## Notes

`(scheme hash-table)` is based solely on SRFI 69 as this is available and
implemented efficiently in the Schemes I have targetted.  For a non-SRFI 69
implementation the functions prefixed 's69:' will need replacing, perhaps by 
a native implementation of hash tables.  All hash-tables are treated as mutable.

`(scheme generator)` does not work on Kawa due to its continuations being 
unsuitable for implementing coroutines.

`(scheme ephemeron)` requires implementation-specific code.  The trivial 
implementation is provided here, to write code against.

The usual SRFI license applies: http://srfi.schemers.org/

## Requirements

The following are required beyond R7RS-small and R7RS-large:

* `(srfi 27)` for `(scheme hash-table)` and `(scheme sort)`
* `(srfi 64)` for the tests
* `(srfi 69)` for `(scheme hash-table)`
* `(srfi 151)` for `(scheme charset)` and `(scheme rlist)`

For those Schemes which do not already support the above SRFIs,
an implementation can be found at https://github.com/petercrlane/r7rs-libs

To install the libraries, follow the instructions at: 
https://github.com/petercrlane/r7rs-libs/INSTALL.md
