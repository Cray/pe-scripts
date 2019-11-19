#!/bin/sh
#
# Build and install the Boost library.
#
# Copyright 2019 Cray, Inc.
####

PACKAGE=boost
VERSION=1.71.0 ; _VERSION=`echo $VERSION | tr . _`
case $VERSION in
  1.68.0) SHA256SUM=7f6130bc3cf65f56a618888ce9d5ea704fa10b462be126ad053e80e553d6d8b7 ;;
  1.70.0) SHA256SUM=430ae8354789de4fd19ee52f3b1f739e1fba576f0aded0897c3c2bc00fb38778 ;;
  1.71.0) SHA256SUM=d73a8da01e8bf8c7eda40b4c84915071a8c8a0df4a6734537ddde4a8580524ee ;;
esac

# These are the built libraries needed by trilinos
boost_libraries="
  regex
  timer
  chrono
  program_options
  system
"
# We additionally build the following libraries for users:
# Peridigm: thread, filesystem, and unit_test
# Nalu:
#   v1.3.0: program_options
#   else: signals, regex, filesystem, system, mpi, serialization,
#         thread, program_options, and exception.
# deal.II: iostreams, serialization, system, thread
boost_libraries="$boost_libraries
  container
  date_time
  exception
  filesystem
  locale
  log
  random
  serialization
  test
  thread
  wave
  system
  mpi
  iostreams
  atomic
  contract
  fiber
  graph
  graph_parallel
  math
  stacktrace
  type_erasure
  context
  coroutine
"
case $VERSION in
  1.68.0) boost_libraries="$boost_libraries signals" ;; # removed in later versions
  *) : ;;
esac

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## Requirements:
##  - MPI
##

cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"
cat >conftest.c <<EOF
#include <mpi.h>
EOF
{ CC -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
  || fn_error "requires MPI"

test -e boost_$_VERSION.tar.bz2 \
  || $WGET http://dl.bintray.com/boostorg/release/$VERSION/source/boost_$_VERSION.tar.bz2 -O boost_$_VERSION.tar.bz2 \
  || fn_error "could not fetch source"
echo "$SHA256SUM  boost_$_VERSION.tar.bz2" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf boost_$_VERSION.tar.bz2 \
  || fn_error "could not untar source"
cd boost_$_VERSION

{ patch -f -p1 <$top_dir/../patches/boost-context-cray.patch && \
  patch -f -p1 <$top_dir/../patches/boost-cray-default-feature-fix.patch && \
  patch -f -p1 <$top_dir/../patches/boost-math-roots-auto.patch && \
  # The config header Boost has for CCE is not up-to-date with respect
  # to CCE >= 8.6 (and even 8.4 and 8.5), so update some of the values
  # so it can build with 8.6.
  echo "patching file boost/config/compiler/cray.hpp" && \
  sed -n -i '
  /NO_SFINAE_EXPR/b undef
  /NO_CXX11_STATIC_ASSERT/b undef
  /NO_CXX11_AUTO_DECLARATIONS/b undef
  /NO_CXX11_VARIADIC_MACROS/b undef
  /NO_CXX11_VARIADIC_TEMPLATES/b undef
  /NO_CXX11_TEMPLATE_ALIASES/b undef
  /NO_CXX11_RVALUE_REFERENCES/b undef  # important
  /NO_CXX11_NULLPTR/b undef
  /NO_CXX11_NOEXCEPT/b undef           # important
  /NO_CXX11_LAMBDAS/b undef
  /NO_CXX11_LOCAL_CLASS_TEMPLATE_PARAMETERS/b undef
  /NO_CXX11_FUNCTION_TEMPLATE_DEFAULT_ARGS/b undef
  /NO_CXX11_EXPLICIT_CONVERSION_OPERATORS/b undef
  /NO_CXX11_DECLTYPE/b undef
  /NO_CXX11_CONSTEXPR/b undef          # important
  /NO_CXX11_REF_QUALIFIERS/b undef
  # otherwise leave the line be and continue
  p
  d

  :undef
  s/define/undef/p
  ' boost/config/compiler/cray.hpp ;
  # See https://github.com/boostorg/build/commit/3385fe2aa699a45e722a1013658f824b6a7c761f
  sed -i 's/\(emit\|include\)-pth/\1-pch/' tools/build/src/tools/clang-linux.jam ; } \
    || fn_error "could not patch"

unset libraries
for lib in $boost_libraries ; do
  libraries="$libraries${libraries+,}$lib"
done
case $compiler in
  gnu)
    toolset=gcc ;;
  intel)
    toolset=intel-linux ;;
  *clang)
    toolset=clang ;;
  *)
    toolset=$compiler ;;
esac

set -x
./bootstrap.sh --with-libraries=$libraries \
  || fn_error "bootstrap failed"

b2="./b2 --user-config=user-config.jam \
  toolset=$toolset --jobs=$make_jobs \
  threading=multi debug-symbols=off \
  `case $compiler in \
     cray) echo 'optimization=default inlining=on vectorize=default' ;; \
     inte) echo 'cxxflags=-std=c++11' ;; \
   esac` \
  -sNO_BZIP2=1 --disable-icu boost.locale.icu=off"

cat >user-config.jam <<EOF
# Build Boost.MPI.  Auto-configuration does not work, because it
# cannot find mpic++ in the environment and does not recognize the CC
# compiler wrapper.  Instead we let it use the standard compiler with
# an empty set (via idempotent <include> since truly empty reverts to
# defaults) of additional compiler flags.
using mpi : : <include>. : aprun -n ;

# Always use the CC wrapper from CrayPE for compilation.  This is
# especially useful for Boost.MPI build, because trying to synthesize
# the proper preprocessor and linker flags could prove to be fragile.
using $toolset : :`test "$compiler" != "cray" && echo " CC"` : ;
EOF
test "$?" = "0" \
  && $b2 \
  || fn_error "build failed"
$b2 --prefix=$prefix install \
  || fn_error "install failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
