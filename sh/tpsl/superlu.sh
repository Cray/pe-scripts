#!/bin/sh
#
# Build and install the SUPERLU library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=superlu
VERSION=5.2.1
SHA256SUM=28fb66d6107ee66248d5cf508c79de03d0621852a0ddeba7301801d3d859f463

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

##
## Requirements:
##  - cmake
##  - metis
##
cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"
cat >conftest.c <<'EOF'
#include <metis.h>
int main(){}
EOF
{ cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
  || fn_error "requires METIS"

test -e superlu_$VERSION.tar.gz \
  || $WGET http://crd-legacy.lbl.gov/~xiaoye/SuperLU/superlu_$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  superlu_$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf superlu_$VERSION.tar.gz \
  || fn_error "could not untar source"
cd SuperLU_$VERSION
patch -f -p1 <<'EOF'
Let SuperLU configure with a BLAS library that's available without
adding any additional libraries.  User must configure with
"-DBLAS_FOUND:BOOL=YES".

--- SuperLU_5.2.1/CMakeLists.txt	2016-05-22 10:58:44.000000000 -0500
+++ SuperLU_5.2.1/CMakeLists.txt	2018-09-24 11:03:34.000000000 -0500
@@ -76,7 +76,7 @@
 #
 #--------------------- BLAS ---------------------
 if(NOT enable_blaslib)
-  if (TPL_BLAS_LIBRARIES)
+  if (BLAS_FOUND OR TPL_BLAS_LIBRARIES)
     set(BLAS_FOUND TRUE)
   else()
     find_package(BLAS)

EOF
test "$?" = "0" \
  || fn_error "could not patch"
rm -rf _build && mkdir _build && cd _build
cmake \
  -DCMAKE_BUILD_TYPE:STRING=RELEASE \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_Fortran_COMPILER:STRING=ftn \
  -DCMAKE_C_COMPILER:STRING=cc \
  -DCMAKE_Fortran_FLAGS="$FFLAGS" \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_EXE_LINKER_FLAGS:STRING="$LDFLAGS $OMPFLAG" \
  -Denable_blaslib:BOOL=FALSE \
  -DBLAS_FOUND:BOOL=TRUE \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  .. \
  || fn_error "configuration failed"
make --jobs=$make_jobs install \
  || fn_error "build failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
