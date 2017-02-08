# simple batch script for release builds
make clean-obj && make ${*} FLAVOUR=OpenSSL && make clean-obj
make clean-obj && make ${*} FLAVOUR=LibreSSL && make clean-obj
