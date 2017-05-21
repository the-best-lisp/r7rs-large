:: Note, unless you preset bin on your CLASSPATH
:: This will produce 'missing class' errors as you compile on windows

for %%f in (scheme/*.sld) do (
  echo %%f
  call kawa -d bin --r7rs -C "scheme/%%~nf.sld"
)

cd bin
jar cf r7rs-large.jar .
cd ..
move bin\r7rs-large.jar .

