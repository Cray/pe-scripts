#!/bin/sh
#
# Build and install the metis library.
#
# Copyright 2019, 2020 Cray, Inc.
####

PACKAGE=metis
VERSION=5.1.0
SHA256SUM=76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2

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

test -e metis-$VERSION.tar.gz \
  || $WGET http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/metis-$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  metis-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf metis-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd metis-$VERSION
make config \
  prefix="$prefix" cc=cc CFLAGS="$CFLAGS $OMPFLAG" \
  || fn_error "configuration failed"
make --jobs=$make_jobs install \
  || fn_error "build failed"
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
