#!/bin/sh
#
# Build and install the PETSc library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=petsc
VERSIONS='
  3.10.3:f03650ea5592313dd2b8be7ae9cc498369da660185b58f9e98689a9bc355e982
  3.10.5:6fa0574aebc6e6cb4eea206ef9a3a6037e20e8b54ca91346628a37f79af1407f
  3.11.4:006177b4059cd40310a3e9a4bf475f3a8c276b62d8cca4df272ef88bdfc2f83a
  3.12.5:b4e9aae06b1a343bc5a7fee975f391e7dbc7086fccc684068b5e0204ffa3ecad
  3.13.6:67ca2cf3040d08fdc51d27f660ea3157732b24c2f47aae1b19d63f62a39842c2
  3.14.2:87a04fd05cac20a2ec47094b7d18b96e0651257d8c768ced2ef7db270ecfb9cb
'

_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

##
## Requirements:
##  - cmake
##  - MPI
##  - BLAS
##  - ScaLAPACK
##  - TPSL (superlu, superlu-dist, metis, parmetis, ptscotch, mumps, hypre, sundials)
##  - hdf5
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
  { cc -L$prefix/lib $LDFLAGS conftest.c $LIBS >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}

cmake --version >/dev/null 2>&1 \
  || fn_error "requires cmake"

fn_check_link BLAS dgemm_
fn_check_link ScaLAPACK pdgetrf_
fn_check_includes MPI mpi.h
fn_check_includes METIS metis.h
fn_check_includes ParMETIS parmetis.h
fn_check_includes SuperLU slu_ddefs.h
fn_check_includes SuperLU_DIST superlu_dist_config.h
fn_check_includes PT-Scotch ptscotch.h
fn_check_includes MUMPS mumps_c_types.h
fn_check_includes HYPRE HYPRE.h
fn_check_includes SUNDIALS sundials/sundials_types.h
fn_check_includes HDF5 hdf5.h

test -e petsc-lite-$VERSION.tar.gz \
  || $WGET http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-lite-$VERSION.tar.gz \
  || fn_error "could not fetch source"
echo "$SHA256SUM  petsc-lite-$VERSION.tar.gz" | sha256sum --check \
  || fn_error "source hash mismatch"
tar xf petsc-lite-$VERSION.tar.gz \
  || fn_error "could not untar source"
cd petsc-$VERSION

: ${CRAY_CPU_TARGET=`uname -m`}
case "$CRAY_CPU_TARGET" in
  x86-64|x86_64)
    level1_dcache_assoc=4
    level1_dcache_linesize=64
    level1_dcache_size=16384
    ;;
  sandybridge|ivybridge|haswell|aarch64)
    level1_dcache_assoc=0
    level1_dcache_linesize=32
    level1_dcache_size=32768
    ;;
  *skylake*|mic*)
    configure_flags="$configure_flags --with-avx512-kernels"
    level1_dcache_assoc=8
    level1_dcache_linesize=32
    level1_dcache_size=32768
    ;;
esac
case "$compiler" in
  cray)
    # PETSc will fail to discover some libraries, e.g. MPICH, if the
    # preprocessor issues warnings.
    CPPFLAGS="-hnomessage=11709 $CPPFLAGS"
    ;;
  crayclang)
    # Similarly:
    CPPFLAGS="-Wno-unused-command-line-argument $CPPFLAGS"
    ;;
  intel)
    # For proper linking of fortran against c++
    LIBS="-lstdc++"
    ;;
esac
case "$compiler" in
  cray|pgi) mpi_long_double=0 ;;
  *) mpi_long_double=1 ;;
esac

cat >configure-petsc.sh <<EOF
#!/bin/sh
exec ./configure \\
  --known-has-attribute-aligned=1 \\
  --known-mpi-int64_t=0 \\
  --known-bits-per-byte=8 \\
  --known-64-bit-blas-indices=0 \\
  --known-sdot-returns-double=0 \\
  --known-snrm2-returns-double=0 \\
  --known-level1-dcache-assoc=${level1_dcache_assoc:-4} \\
  --known-level1-dcache-linesize=${level1_dcache_linesize:-64} \\
  --known-level1-dcache-size=${level1_dcache_size:-16384} \\
  --known-memcmp-ok=1 \\
  --known-mpi-c-double-complex=1 \\
  --known-mpi-long-double=$mpi_long_double \\
  --known-mpi-shared-libraries=0 \\
  --known-sizeof-MPI_Comm=4 \\
  --known-sizeof-MPI_Fint=4 \\
  --known-sizeof-char=1 \\
  --known-sizeof-double=8 \\
  --known-sizeof-float=4 \\
  --known-sizeof-int=4 \\
  --known-sizeof-long-long=8 \\
  --known-sizeof-long=8 \\
  --known-sizeof-short=2 \\
  --known-sizeof-size_t=8 \\
  --known-sizeof-void-p=8 \\
  --with-ar=ar \\
  --with-batch=1 \\
  --with-cc=cc \\
  --with-clib-autodetect=0 \\
  --with-cxx=CC \\
  --with-cxxlib-autodetect=0 \\
  --with-debugging=0 \\
  --with-dependencies=0 \\
  --with-fc=ftn \\
  --with-fortran-datatypes=0 \\
  --with-fortran-interfaces=0 \\
  --with-fortranlib-autodetect=1 \\
  --with-ranlib=ranlib \\
  --with-scalar-type=real \\
  --with-shared-ld=ar \\
  --with-etags=0 \\
  --with-x=0 \\
  --with-ssl=0 \\
  --with-shared-libraries=0 \\
  --with-mpi-lib=[] \\
  --with-mpi-include=[] \\
  --with-blas-lapack=1 \\
  --with-superlu=1 \\
  --with-superlu-dir=$prefix \\
  --with-superlu_dist=1 \\
  --with-superlu_dist-dir=$prefix \\
  --with-parmetis=1 \\
  --with-metis=1 \\
  --with-metis-dir=$prefix \\
  --with-scalapack=1 \\
  --with-ptscotch=1 \\
  --with-ptscotch-include=$prefix/include \\
  --with-ptscotch-lib="-L$prefix/lib -lptscotch -lscotch -lptscotcherr -lscotcherr" \\
  --with-mumps=1 \\
  --with-mumps-include=$prefix/include \\
  --with-mumps-lib="-L$prefix/lib -lcmumps -ldmumps -lesmumps -lsmumps -lzmumps -lmumps_common -lptesmumps -lesmumps -lpord" \\
  --with-hdf5=1 \\
  --CFLAGS="$CFLAGS $OMPFLAG" \\
  --CPPFLAGS="-I$prefix/include $CPPFLAGS" \\
  --CXXFLAGS="$CFLAGS $OMPFLAG" \\
  --with-cxx-dialect=C++11 \\
  --FFLAGS="$FFLAGS $FOMPFLAG" \\
  --LDFLAGS="-L$prefix/lib $OMPFLAG" \\
  --LIBS="$PE_LIBS $LIBS -lstdc++" \\
  --PETSC_ARCH="$CRAY_CPU_TARGET" \\
  --prefix=$prefix${configure_flags+ \\
  $configure_flags}
EOF
test "$?" = "0" \
  && chmod +x configure-petsc.sh \
  && ./configure-petsc.sh \
  || fn_error "configuration failed"
make MAKE_NP=$make_jobs PETSC_DIR=`pwd` PETSC_ARCH=$CRAY_CPU_TARGET all \
  || fn_error "build failed"
make PETSC_DIR=`pwd` PETSC_ARCH=$CRAY_CPU_TARGET install \
  || fn_error "install failed"

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
