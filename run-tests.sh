# Run tests: chibi/gauche/kawa/larceny/sagittarius argument selects implementation

if [ "$1" = "kawa" ]; then
  PROG="kawa --r7rs -Dkawa.import.path=$(cd "$(dirname "$0")" ; pwd)/*.sld -f "
else if [ "$1" = "larceny" ]; then
  PROG="larceny -r7rs -program "
else if [ "$1" = "chibi" ]; then
  PROG="chibi-scheme -I ../r7rs-libs -I ../r7rs-libs/srfis/chibi/ "
else if [ "$1" = "sagittarius" ]; then
  PROG="sagittarius -r7 -L . -L ../r7rs-libs -L ../r7rs-libs/srfis/sagittarius "
else if [ "$1" = "gauche" ]; then
  export GAUCHE_KEYWORD_IS_SYMBOL=1
  PROG="gosh -r7 -I . -I ../r7rs-libs/ -I ../r7rs-libs/srfis/gauche/ "
else
  echo "Unknown implementation"
  exit
fi
fi
fi
fi
fi

for file in scheme-tests/*-test.sps
do
  $PROG $file
done

