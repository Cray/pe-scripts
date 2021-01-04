#!/bin/sh
#
# Build and install the Superlu_DIST library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=superlu-dist
VERSIONS="
  6.1.1:4ae956e57aa6c1c3a3a9627f5e464409e9a120e39f3a6e0c75aa021ac37759aa
  6.3.1:713b1993fc5426229c5ccd4be499defb1b040ff9209adb7fe97bbec880dcbc52
  6.4.0:cb9c0b2ba4c28e5ed5817718ba19ae1dd63ccd30bc44c8b8252b54f5f04a44cc
"

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

##
## Requirements:
##  - cmake
##  - metis
##  - parmetis
##
cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"
cat >conftest.c <<'EOF'
#include <metis.h>
EOF
{ cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
  || fn_error "requires METIS"
cat >conftest.c <<'EOF'
#include <parmetis.h>
EOF
{ cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
  || fn_error "requires ParMETIS"

test -e superlu_dist_$VERSION.tar.gz \
  || $WGET https://portal.nersc.gov/project/sparse/superlu/superlu_dist_$VERSION.tar.gz \
  || $WGET https://github.com/xiaoyeli/superlu_dist/archive/v$VERSION.tar.gz -O superlu_dist_$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  superlu_dist_$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf superlu_dist_$VERSION.tar.gz \
  || fn_error "could not untar source"
cd SuperLU_DIST_$VERSION 2>/dev/null || cd superlu_dist-$VERSION
patch -f -p1 <$top_dir/../patches/superlu-dist-omp.patch \
  || fn_error "could not patch"
patch -f -p1 <<'EOF'
Let SuperLU_DIST configure with a BLAS library that's available
without adding any additional libraries.  User must configure with
"-DBLAS_FOUND:BOOL=YES".

--- SuperLU_DIST_6.1.1/CMakeLists.txt
+++ SuperLU_DIST_6.1.1/CMakeLists.txt
@@ -164,7 +164,7 @@
 if(NOT TPL_ENABLE_BLASLIB)
 #  set(TPL_BLAS_LIBRARIES "" CACHE FILEPATH
 #    "Override of list of absolute path to libs for BLAS.")
-  if(TPL_BLAS_LIBRARIES)
+  if(BLAS_FOUND OR TPL_BLAS_LIBRARIES)
     set(BLAS_FOUND TRUE)
   else()
     find_package(BLAS)
@@ -195,7 +195,7 @@
 
 #--------------------- LAPACK ---------------------
 if(TPL_ENABLE_LAPACKLIB)  ## want to use LAPACK
-  if(TPL_LAPACK_LIBRARIES)
+  if(LAPACK_FOUND OR TPL_LAPACK_LIBRARIES)
     set(LAPACK_FOUND TRUE)
   else()
     find_package(LAPACK)

EOF
test "$?" = "0" \
  || fn_error "could not patch"
rm -rf _build && mkdir _build && cd _build
cmake \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_Fortran_COMPILER:STRING=ftn \
  -DCMAKE_C_COMPILER:STRING=cc \
  -DCMAKE_Fortran_FLAGS="$FFLAGS $FOMPFLAG" \
  -DCMAKE_C_FLAGS="$CFLAGS $C99FLAG $OMPFLAG $CPPFLAGS" \
  -DOpenMP_CXX_FLAGS="$OMPFLAG" \
  -DBUILD_SHARED_LIBS:BOOL=OFF \
  -DCMAKE_EXE_LINKER_FLAGS:STRING="$LDFLAGS $OMPFLAG -L$prefix/lib" \
  -DTPL_ENABLE_BLASLIB:BOOL=YES \
  -DTPL_BLAS_LIBRARIES="" \
  -DBLAS_FOUND:BOOL=YES \
  -DTPL_ENABLE_LAPACKLIB:BOOL=YES \
  -DTPL_LAPACK_LIBRARIES="" \
  -DLAPACK_FOUND:BOOL=YES \
  -DTPL_PARMETIS_LIBRARIES="parmetis;metis" \
  -DTPL_PARMETIS_INCLUDE_DIRS="$prefix/include" \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DMPIEXEC="${MPIEXEC:-`which mpiexec`}" \
  .. \
  || fn_error "configuration failed"
case "$compiler" in
  cray)
    find . \( -name 'link.txt' -o -name 'flags.make' \) \
      -exec sed -i 's/-std=c++11/-hstd=c++11/g' {} \+ \
      || fn_error "patching C++11 flags for CCE"
    ;;
esac
make --jobs=$make_jobs install \
  || fn_error "build failed"
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
