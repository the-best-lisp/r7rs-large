## Compile Kawa files into bin folder
## and collect into a single jar file

# Reference kawa implementation to use
KAWA=kawa
OPTS="--r7rs -d bin "
export CLASSPATH=bin

# Remove existing files, if present
if [ -d "bin" ]; then
  rm -rf bin
fi
if [ -e "r7rs-large.jar" ]; then
  rm r7rs-large.jar
fi
# Make bin
mkdir bin

for file in scheme/*.sld
do
  ${KAWA} $OPTS -C $file
done

# Create jar file to finish
cd bin
jar cf r7rs-large.jar .
cd ..
mv bin/r7rs-large.jar .

# Tidy up
if [ -d "bin" ]; then
  rm -rf bin
fi
