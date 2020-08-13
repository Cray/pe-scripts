#!/bin/sh
#
# Build and install the GLM library.
#
# Copyright 2019, 2020 Cray, Inc.
####

PACKAGE=glm
VERSIONS='
  0.9.6.3:14651b56b10fa68082446acaf6a1116d56b757c8d375b34b5226a83140acd2b2
  0.9.9.6:9db7339c3b8766184419cfe7942d668fecabe9013ccfec8136b39e11718817d0
'

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

test -e glm-$VERSION.zip \
  || $WGET https://github.com/g-truc/glm/releases/download/$VERSION/glm-$VERSION.zip \
  || fn_error "could not fetch source"
echo "$SHA256SUM  glm-$VERSION.zip" | sha256sum --check \
  || fn_error "source hash mismatch"
unzip -d glm-$VERSION glm-$VERSION.zip \
  || fn_error "could not unzip source"
cd glm-$VERSION/glm
{ printf "converting to unix line-endings..." ;
  find . -type f -exec sed -i 's/$//' {} \; && echo "done" ; } \
    || fn_error "could not patch line endings"
case $VERSION in
  0.9.9.6) patch --reverse -p1 <$top_dir/../patches/glm-cmake-install.patch \
             || fn_error "could not patch source" ;;
esac
cmake \
  -DGLM_TEST_ENABLE=OFF \
  -DCMAKE_CXX_COMPILER:STRING=CC \
  -DCMAKE_CXX_FLAGS="$CFLAGS" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_PREFIX=$prefix \
  || fn_error "configuration failed"
make install \
  || fn_error "build failed"
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
