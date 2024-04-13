cp -r $1 $1_clean
rm -r $1_clean/*/libwebp*
rm -r $1_clean/*/bench/bin
rm $1_clean/*/bench/*
