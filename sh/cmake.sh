#!/bin/sh
#
# Build and install the Cmake tool.
#
# Copyright 2020 Hewlett Packard Enterprise Development LP.
####

PACKAGE=cmake
VERSION=3.18.2
SHA256SUM=5d4e40fc775d3d828c72e5c45906b4d9b59003c9433ff1b36a1cb552bbd51d7e

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## Requirements:
##

version_major_minor=$(printf "%s" $VERSION | sed 's/\.[^.]*$//')
test -e cmake-$VERSION.tar.gz \
  || $WGET https://www.cmake.org/files/v$version_major_minor/cmake-$VERSION.tar.gz \
  || fn_error "could not fetch source"
printf "$SHA256SUM  cmake-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismath"
tar xf cmake-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd cmake-$VERSION

cat >configure-cmake.sh <<EOF
#!/bin/sh
exec ./configure \\
  --prefix=$prefix \\
  --parallel=${JOBS:-1} \\
  --mandir=share/man \\
  --docdir=share/doc/cmake-$version_major_minor \\
  -- -DCMAKE_USE_OPENSSL:BOOL=OFF
EOF
test "$?" = "0" \
  && chmod +x configure-cmake.sh \
  && ./configure-cmake.sh \
  || fn_error "configuration failed"
make \
  || fn_error "build failed"
make install \
  || fn_error "install failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
