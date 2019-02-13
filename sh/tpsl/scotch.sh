#!/bin/sh
#
# Build and install the scotch library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=scotch
VERSION=6.0.6
SHA256SUM=686f0cad88d033fe71c8b781735ff742b73a1d82a65b8b1586526d69729ac4cf

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

case "$compiler" in
  cray) CFLAGS_NATIVE="-hcpu=`uname -m`" ;;
  gnu|intel|crayclang) CFLAGS_NATIVE="-march=native" ;;
  pgi) CFLAGS_NATIVE="-tp=x86" ;; # only supported on x86
esac

##
## Optional:
##   - hdf5
##

test -e scotch_$VERSION.tar.gz \
  || $WGET https://gforge.inria.fr/frs/download.php/latestfile/298/scotch_$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  scotch_$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf scotch_$VERSION.tar.gz \
  || fn_error "could not untar source"
cd scotch_$VERSION
{ patch -f -p1 <$top_dir/../patches/scotch-cce-empty-struct.patch ;
  patch -f -p1 <$top_dir/../patches/scotch-common-thread-memfence.patch ;
  patch -f -p1 <$top_dir/../patches/scotch-dummysize-cross.patch ; } \
    || fn_error "coult not patch source"
cat >src/Makefile.inc <<EOF
EXE            =
LIB            = .a
OBJ            = .o
AR             = ar
ARFLAGS        = ruv
RANLIB         = ranlib
CCS            = cc
CCP            = cc
CCD            = cc
LEX            = flex -Pscotchyy -olex.yy.c
YACC           = bison -pscotchyy -y -b y

CAT            = cat
CP             = cp
LN             = ln
MKDIR          = mkdir
MV             = mv

# - Do not set the SCOTCH_PTHREAD flag because it requires that the
#   MPI environment be initialized with MPI_Init_thread, which is not
#   always the case in user applications.
# - Install the scotch/metis interface libraries, which include
#   bindings with the prefix "SCOTCH_METIS"
CPPFLAGS = $CPPFLAGS \\
  -DSCOTCH_METIS_PREFIX \\
  -DCOMMON_RANDOM_FIXED_SEED \\
  -DSCOTCH_RENAME \\
  -DCOMMON_PTHREAD \\
  -DSCOTCH_RENAME_PARSER \\
  -Drestrict=__restrict

CFLAGS    = \$(CPPFLAGS) $CFLAGS
CFLAGS_DS = \$(CPPFLAGS) $CFLAGS_NATIVE
# The librt library is needed for the "clock_gettime" calls;
# libpthread for "pthread_join" and "pthread_create".
LDFLAGS   = $PE_LDDIRS $PE_LIBS $LDFLAGS -lrt -lpthread
EOF
test "$?" = "0" \
  && mkdir -p "$prefix/lib" "$prefix/include" \
  || fn_error "configuration failed"
# -j1 due to race conditions on generated headers
make --jobs=1 -C src \
  prefix="$prefix" \
  scotch ptscotch esmumps ptesmumps \
  || fn_error "build failed"
make -C src prefix="$prefix" install \
  && cp include/esmumps.h "$prefix/include" \
  && cp lib/*esmumps* "$prefix/lib" \
  || fn_error "install failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
