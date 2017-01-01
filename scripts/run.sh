# simple batch script for release builds
make clean-obj && make ${1} FLAVOUR=OpenSSL && make clean-obj
make clean-obj && make ${1} FLAVOUR=LibreSSL && make clean-obj
