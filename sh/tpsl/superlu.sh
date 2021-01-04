#!/bin/sh
#
# Build and install the SUPERLU library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=superlu
VERSION=5.2.2
SHA256SUM=470334a72ba637578e34057f46948495e601a5988a602604f5576367e606a28c

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
  || $WGET https://portal.nersc.gov/project/sparse/superlu/superlu_$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  superlu_$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf superlu_$VERSION.tar.gz \
  || fn_error "could not untar source"
cd SuperLU_$VERSION 2>/dev/null || cd superlu-$VERSION
patch -f -p1 <<'EOF'
Let SuperLU configure with a BLAS library that's available without
adding any additional libraries.  User must configure with
"-DBLAS_FOUND:BOOL=YES".

--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -76,4 +76,4 @@
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
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
