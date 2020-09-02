#!/bin/sh
#
# Build and install the parmetis library.
#
# Copyright 2019, 2020 Cray, Inc.
####

PACKAGE=parmetis
VERSION=4.0.3
SHA256SUM=f2d9a231b7cf97f1fee6e8c9663113ebf6c240d407d3c118c55b3633d6be6e5f

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

##
## Requirements:
##   - cmake
##
cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"
cat >conftest.c <<'EOF'
#include <metis.h>
int main(){}
EOF
{ cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
  || fn_error "requires METIS"

test -e parmetis-$VERSION.tar.gz \
  || $WGET http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/parmetis-4.0.3.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  parmetis-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf parmetis-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd parmetis-$VERSION
patch -p1 <<'EOF'
--- parmetis-4.0.3/CMakeLists.txt
+++ parmetis-4.0.3/CMakeLists.txt
@@ -33,7 +33,6 @@
 include_directories(${METIS_PATH}/include)
 
 # List of directories that cmake will look for CMakeLists.txt
-add_subdirectory(${METIS_PATH}/libmetis ${CMAKE_BINARY_DIR}/libmetis)
 add_subdirectory(include)
 add_subdirectory(libparmetis)
 add_subdirectory(programs)
EOF
test "$?" = "0" \
  || fn_error "could not patch"
patch -p1 <<'EOF'
--- parmetis-4.0.3/libparmetis/CMakeLists.txt
+++ parmetis-4.0.3/libparmetis/CMakeLists.txt
@@ -5,7 +5,7 @@
 # Create libparmetis
 add_library(parmetis ${ParMETIS_LIBRARY_TYPE} ${parmetis_sources})
 # Link with metis and MPI libraries.
-target_link_libraries(parmetis metis ${MPI_LIBRARIES})
+target_link_libraries(parmetis "-L${METIS_PATH}/lib" metis ${MPI_LIBRARIES} m)
 set_target_properties(parmetis PROPERTIES LINK_FLAGS "${MPI_LINK_FLAGS}")
 
 install(TARGETS parmetis

EOF
make config \
  prefix="$prefix" cc=cc cxx=CC \
  metis_path="$prefix" \
  CFLAGS="$CFLAGS $OMPFLAG" \
  CXXFLAGS="$CFLAGS $OMPFLAG" \
  || fn_error "configuration failed"
make --jobs=$make_jobs install \
  || fn_error "build failed"
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
