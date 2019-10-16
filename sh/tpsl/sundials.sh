#!/bin/sh
#
# Build and install the SUNDIALS library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=sundials
VERSION=4.1.0
case $VERSION in
  2.7.0) SHA256SUM=d39fcac7175d701398e4eb209f7e92a5b30a78358d4a0c0fcc23db23c11ba104 ;;
  4.1.0) SHA256SUM=280de1c27b2360170a6f46cb3799b2aee9dff3bddbafc8b08c291a47ab258aa5 ;;
esac

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

##
## Requirements:
##  - cmake
##
cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"

test -e sundials-$VERSION.tar.gz \
  || $WGET https://computation.llnl.gov/projects/sundials/download/sundials-$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  sundials-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf sundials-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd sundials-$VERSION
rm -rf _build && mkdir _build && cd _build
cmake \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DCMAKE_Fortran_COMPILER:STRING=ftn \
  -DCMAKE_C_COMPILER:STRING=cc \
  -DCMAKE_Fortran_FLAGS="$FFLAGS" \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DSUNDIALS_RT_LIBRARY:STRING=-lrt \
  -DBUILD_SHARED_LIBS=OFF \
  -DEXAMPLES_ENABLE:BOOL=NO \
  -DEXAMPLES_INSTALL:BOOL=NO \
  -DFCMIX_ENABLE=ON \
  -DSUNDIALS_INDEX_SIZE=32 \
  -DLAPACK_ENABLE=ON \
  -DLAPACK_LIBRARY="" \
  -DLAPACK_FOUND:BOOL=YES \
  -DMPI_ENABLE=ON \
  -DMPI_MPICC:STRING=cc \
  -DMPI_MPIF77:STRING=ftn \
  -DOPENMP_ENABLE:BOOL=ON \
  .. \
  || fn_error "configuration failed"
make --jobs=$make_jobs install \
  || fn_error "build failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
