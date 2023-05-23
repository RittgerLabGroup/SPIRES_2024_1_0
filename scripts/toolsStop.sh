#Clean up temporary directory for matlab job storage
echo "${PROGNAME}: Removing TMPDIR=$TMPDIR..."
rm -rf $TMPDIR

log_level_1 "end:DONE"
