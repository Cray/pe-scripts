#!/bin/sh
#
# Build and install the SLEPc library.
#
# Copyright 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=slepc
VERSIONS='
  3.12.2:a586ce572a928ed87f04961850992a9b8e741677397cbaa3fb028323eddf4598
  3.13.4:ddc9d58e1a4413218f4e67ea3b255b330bd389d67f394403a27caedf45afa496
  3.14.1:cc78a15e34d26b3e6dde003d4a30064e595225f6185c1975bbd460cb5edd99c7
'

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## Requirements:
##  - petsc
##  - MPI
##  - LAPACK
##

fn_check_includes()
{
  cat >conftest.c <<EOF
#include <$2>
EOF
  { cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}
fn_check_link()
{
  cat >conftest.c <<EOF
int $2();
int main(){ $2(); }
EOF
  { cc -L$prefix/lib conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}

fn_check_link LAPACK dgeevx_
fn_check_includes MPI mpi.h
fn_check_includes PETSc petscversion.h
fn_check_includes PETSc petscconf.h
: ${PETSC_DIR:=$prefix}
export PETSC_DIR

test -e slepc-$VERSION.tar.gz \
  || $WGET https://slepc.upv.es/download/distrib/slepc-$VERSION.tar.gz \
  || fn_error "could not fetch source"
printf "$SHA256SUM  slepc-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismath"
tar xf slepc-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd slepc-$VERSION

cat >configure-slepc.sh <<EOF
#!/bin/sh
exec ./configure --prefix=$prefix
EOF
test "$?" = "0" \
  && chmod +x configure-slepc.sh \
  && ./configure-slepc.sh \
  || fn_error "configuration failed"
make SLEPC_DIR=$PWD MAKE_NP=$make_jobs all \
  || fn_error "build failed"
make SLEPC_DIR=$PWD install \
  || fn_error "install failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
