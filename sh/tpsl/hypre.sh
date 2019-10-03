#!/bin/sh
#
# Build and install the HYPRE library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=hypre
VERSION=2.14.0
SHA256SUM=10cfcd555618137c194958f84f44724fece45b58c59002d1195fed354e2ca16c

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

(test -e hypre-$VERSION.tar.gz && echo "$SHA256SUM  hypre-$VERSION.tar.gz" | sha256sum --check) \
  || $WGET https://github.com/LLNL/hypre/archive/v$VERSION.tar.gz -O hypre-$VERSION.tar.gz \
  || fn_error "could not fetch source"
tar xf hypre-$VERSION.tar.gz \
  || fn_error "could not unzip source"
cd hypre-$VERSION
{ patch -f -p1 <$top_dir/../patches/hypre-hopscotch-no-builtins.patch ;
  patch -f -p1 <$top_dir/../patches/hypre-mpi-comm-f2c-interface.patch ;
  patch -f -p1 <$top_dir/../patches/hypre-struct-mv-pragmas.patch ; } \
    || fn_error "could not patch source"
cd src
./configure \
  cross_compiling=yes \
  --prefix=$prefix \
  F77=ftn FC=ftn CC=cc CXX=CC \
  FFLAGS="$FFLAGS $FOMPFLAG" \
  F77FLAGS="$FFLAGS $FOMPFLAG" \
  CFLAGS="$CFLAGS $OMPFLAG" \
  CXXFLAGS="$CXXFLAGS $OMPFLAG" \
  FCLIBS=" " \
  --with-openmp \
  --with-MPI-include= \
  --with-MPI-lib-dirs= \
  --with-blas-lib= \
  --with-lapack-lib= \
  --without-fei \
  --without-mli \
  --enable-persistent \
  --enable-hopscotch \
  || fn_error "configuration failed"
# Do not build blas and lapack code
make --jobs=$make_jobs HYPRE_BASIC_DIRS=utilities BLASFILES= LAPACKFILES= install \
  || fn_error "build failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
