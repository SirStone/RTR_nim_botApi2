NAME="TestBot"
SRC_DIR="tests/$NAME"
OUT_DIR="bin/tests/$NAME"

nim --run --threads:on $SRC_DIR/$NAME.nim #for release