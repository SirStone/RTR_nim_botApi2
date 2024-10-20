NAME="CrashTest"
OUT_DIR="../../bin/tests/$NAME"

nim c --outdir:$OUT_DIR $NAME.nim # for debugging
# nim c -d:release -d:danger --outdir:$OUT_DIR $NAME.nim #for release

# GOING FORWARD ONLY IF COMPILE IS OK
if [ $? -eq 0 ]; then
    cp $NAME.json $OUT_DIR
    cp $NAME.sh $OUT_DIR
    chmod +x $OUT_DIR/$NAME.sh
fi