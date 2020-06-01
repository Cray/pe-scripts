#!/bin/sh
#
# Build and install the SLEPc library.
#
# Copyright 2020 Cray, Inc.
####

PACKAGE=slepc
VERSIONS='
  3.12.2:a586ce572a928ed87f04961850992a9b8e741677397cbaa3fb028323eddf4598
  3.13.2:04cb8306cb5d4d990509710d7f8ae949bdc2c7eb850930b8d0b0b5ca99f6c70d
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
