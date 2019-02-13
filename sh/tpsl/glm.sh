#!/bin/sh
#
# Build and install the GLM library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=glm
VERSION=0.9.6.3
SHA256SUM=14651b56b10fa68082446acaf6a1116d56b757c8d375b34b5226a83140acd2b2

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

##
## Requirements:
##  - unzip
##  - cmake
##
unzip >/dev/null 2>&1 \
  || fn_error "requires unzip for source"
cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"

(test -e glm-$VERSION.zip && echo "$SHA256SUM  glm-$VERSION.zip" | sha256sum --check) \
  || $WGET https://github.com/g-truc/glm/releases/download/$VERSION/glm-$VERSION.zip \
  || fn_error "could not fetch source"
unzip glm-$VERSION.zip \
  || fn_error "could not unzip source"
cd glm
cmake \
  -DGLM_TEST_ENABLE=OFF \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_PREFIX=$prefix \
  || fn_error "configuration failed"
make install \
  || fn_error "build failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
