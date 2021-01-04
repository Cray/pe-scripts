#!/bin/sh
#
# Build and install the scotch library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=scotch
VERSIONS='
  6.0.6:686f0cad88d033fe71c8b781735ff742b73a1d82a65b8b1586526d69729ac4cf
  6.0.7:094e7672d7856236777f5d1988c4cdf6c77c3a8d2fac3d8f770e0b42a08d4ccb
  6.0.8:0ba3f145026174304f910c8770a3cbb034f213c91d939573751cfbb4fd46d45e
  6.0.9:e57e16c965bab68c1b03389005ecd8a03745ba20fd9c23081c0bb2336972d879
  6.0.10:fd8b707b8200823312a1571d97d3776ff3dfd3280cfa4b6e38987153cea5dbda
  6.1.0:a3bc3fa3b243fcb52f8d68de4272562a0328afb18a96f535724d284e36730485
'

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
{ case $VERSION in
    6.0.6) patch -f -p1 <$top_dir/../patches/scotch-cce-empty-struct.patch ;
           patch -f -p1 <$top_dir/../patches/scotch-dummysize-cross.patch ;;
    6.0.8) patch -f -p1 <$top_dir/../patches/scotch-6.0.8-dummysize-cross.patch ;;
  esac &&
  patch -f -p1 <$top_dir/../patches/scotch-common-thread-memfence.patch ; } \
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
# libpthread for "pthread_join" and "pthread_create";
# libm for "fmod" in parser.c, etc.
LDFLAGS   = $PE_LDDIRS $PE_LIBS $LDFLAGS -lrt -lpthread -lm
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
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
