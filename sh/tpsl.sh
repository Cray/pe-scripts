#!/bin/sh
#
# Build and install Cray's TPSL library collection.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=tpsl

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## TPSL is a collection of libraries.  Install each.
##

for lib in glm hypre matio metis scotch parmetis mumps sundials superlu superlu-dist ; do
  $top_dir/tpsl/$lib.sh --jobs=$make_jobs --prefix=$prefix \
    || fn_error "failed to install $lib"
done

echo "tpsl: done!  Installed to $prefix"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
