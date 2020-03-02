#!/bin/sh
#
# Build and install the Adios library.
#
# Copyright 2020 Cray, Inc.
####

PACKAGE=adios
VERSION=1.13.1
SHA256SUM=684096cd7e5a7f6b8859601d4daeb1dfaa416dfc2d9d529158a62df6c5bcd7a0

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## Requirements:
##  - MPI
##  - Python 2.x or 3.x
##
## Optional:
##  - Serial HDF5 (api vers 1.6)
##  - Parallel HDF5
##  - Netcdf4 Parallel (i.e. netcdf w/ parallel hdf5)
##  - Lustreapi
##  - Networking Libraries
##    - Infiniband
##    - DataSpaces (also DIMES)
##    - Flexpath
##  - Data transformation plugins:
##    - zlib
##    - bzip2
##    - szip
##    - sz
##  - Query methods
##    - FastBit
##    - Alacrity (NCSU)
##

fn_check_includes()
{
  cat >conftest.c <<EOF
#include <$2>
EOF
  { cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}

fn_check_includes MPI mpi.h
python2 --version >/dev/null 2>&1 \
  || python3 --version >/dev/null 2>&1 \
  || fn_error "requires Python 2.x or 3.x"

test -e adios-$VERSION.tar.gz \
  || $WGET https://users.nccs.gov/~pnorbert/adios-$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  adios-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf adios-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd adios-$VERSION

cat >configure-adios.sh <<EOF
#!/bin/sh
exec ./configure \\
  cross_compiling=yes \\
  CC=cc CXX=CC FC=ftn \\
  CFLAGS="$CFLAGS" \\
  CXXFLAGS="$CXXFLAGS" \\
  FCFLAGS="$FFLAGS" \\
  FCLIBS=" " \
  --prefix=$prefix \\
  --with-pic --disable-shared \\
  --with-zlib
EOF

test "$?" = "0" \
  && chmod +x configure-adios.sh \
  && ./configure-adios.sh \
  || fn_error "configuration failed"
make --jobs=$make_jobs \
  || fn_error "build failed"
make --jobs=$make_jobs install \
  || fn_error "install failed"
printf "adios: done!  Installed to $prefix\n"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
