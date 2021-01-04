#!/bin/sh
#
# Build and install the MUMPS library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=mumps
VERSIONS='
  5.1.2:eb345cda145da9aea01b851d17e54e7eef08e16bfa148100ac1f7f046cd42ae9
  5.2.1:d988fc34dfc8f5eee0533e361052a972aa69cc39ab193e7f987178d24981744a
  5.3.5:e5d665fdb7043043f0799ae3dbe3b37e5b200d1ab7a6f7b2a4e463fd89507fa4
'

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname \`_dirname "$0"\``

. $top_dir/.preamble.sh

case "$compiler:$GCC_VERSION" in
  gnu:10.*)
    # See https://listes.ens-lyon.fr/sympa/arc/mumps-users/2020-05/msg00006.html
    FFLAGS="-fallow-argument-mismatch $FFLAGS"
    ;;
esac

##
## Requirements:
##  - scotch
##  - metis
##  - parmetis
##
fn_check_includes()
{
  cat >conftest.c <<EOF
#include <$2>
EOF
  { cc -E -I$prefix/include conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}
fn_check_includes METIS metis.h
fn_check_includes ParMETIS parmetis.h
fn_check_includes PT-Scotch ptscotch.h

test -e MUMPS_$VERSION.tar.gz \
  || $WGET http://mumps.enseeiht.fr/MUMPS_$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  MUMPS_$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf MUMPS_$VERSION.tar.gz \
  || fn_error "could not untar source"
cd MUMPS_$VERSION
# Cannot build precision libraries in parallel due to shared
# dependency on ana_ordering_wrappers object, leading to race
# condition.  This was fixed in release 5.3.5.
fn_versgte $VERSION 5.3.5 \
  || sed 's/^c:/.NOTPARALLEL: c z s d\n&/' -i Makefile \
  || fn_error "could not patch Makefile"
cat >Makefile.inc <<EOF
LPORDDIR = \$(topdir)/PORD/lib/
IPORD = -I\$(topdir)/PORD/include/
LPORD = -L\$(LPORDDIR) -lpord
IMETIS = -I$prefix/include
LMETIS = -L$prefix/lib -lparmetis -lmetis
ISCOTCH = -I$prefix/include
LSCOTCH = -L$prefix/lib -lesmumps -lptscotch -lscotch -lptscotcherr -lscotcherr
ORDERINGSC = -Dpord -Dscotch -Dptscotch -Dmetis -Dparmetis
ORDERINGSF = -Dpord -Dscotch -Dptscotch -Dmetis -Dparmetis
LORDERINGS = \$(LMETIS) \$(LPORD) \$(LSCOTCH)
IORDERINGSF = \$(ISCOTCH)
IORDERINGSC = \$(IMETIS) \$(IPORD) \$(ISCOTCH)

CC = cc
OPTC = $CPPFLAGS $CFLAGS $OMPFLAG
FC = ftn
FL = ftn
OPTF = $FFLAGS $FOMPFLAG
CDEFS = -DAdd_

LIBEXT = .a
OUTC = -o #
OUTF = -o #
RM = rm -f #
AR = ar cr #
RANLIB = ranlib #
SCALAP = #
INCPAR =
LIBPAR = \$(SCALAP)
INCSEQ = -I\$(topdir)/libseq
LIBSEQ = \$(LAPACK) -L\$(topdir)/libseq -lmpiseq
LIBBLAS = #
OPTL = $LDFLAGS $OMPFLAG
INCS = \$(INCPAR)
LIBS = \$(LIBPAR)
LIBSEQNEEDED =
EOF
test "$?" = "0" \
  && mkdir -p "$prefix/lib" "$prefix/include" \
  || fn_error "configuration failed"
make --jobs=$make_jobs alllib \
  || fn_error "build failed"
cp lib/lib*.a "$prefix/lib" \
  && cp include/*.h "$prefix/include" \
  || fn_error "install failed"
fn_checkpoint_tpsl

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
