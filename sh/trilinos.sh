#!/bin/sh
#
# Build and install the Trilinos library.
#
# Copyright 2019, 2020, 2021 Hewlett Packard Enterprise Development LP.
####

PACKAGE=trilinos
VERSIONS='
  12.14.1:10a88f034b8f91904a98970c00fa88b7f4acd59429d2c4870a60c6e297fc044a
  12.18.1:8a6b8e676c548ca9da0c02671bad2169380bc59d8bd12f9960948898dea18d77
'


_pwd(){ CDPATH= cd -- $1 && pwd; }
_dirname(){ _d=`dirname -- "$1"`;  _pwd $_d; }
top_dir=`_dirname "$0"`

. $top_dir/.preamble.sh

fn_trilinos_git_checkout(){
  dir="$1"
  case $VERSION in
    12.14.1)
      # Note: Use shallow clone to save ~80% of bandwidth
      git clone --branch trilinos-release-12-14-1 --depth 1 https://github.com/Trilinos/Trilinos.git $dir \
        && (cd $dir/packages \
              && git clone https://github.com/Trilinos/ForTrilinos.git \
              && (cd ForTrilinos ; git checkout 808293ee1a751f0413955a7e0cae710414cc330e))
      ;;
    12.18.1)
      git clone --branch trilinos-release-12-18-1 --depth 1 https://github.com/Trilinos/Trilinos.git $dir \
        && (cd $dir/packages \
              && git clone https://github.com/Trilinos/ForTrilinos.git \
              && (cd ForTrilinos ; git checkout 66c45b1d1491af75146abe3b611147fd896a4f56))
      ;;
    *) return 1 ;;              # cannot checkout for this version
  esac
}

##
## Requirements:
##  - cmake
##  - MPI
##  - BLAS
##  - ScaLAPACK
##  - TPSL (superlu, superlu-dist, metis, parmetis, scotch, mumps, glm, matio)
##  - boost
##  - hdf5
##  - netcdf
##  - tar >= 1.27 for source verification
##

fn_check_includes()
{
  cat >conftest.c <<EOF
#include <$2>
EOF
  { CC -E -I$prefix/include $CPPFLAGS conftest.c >/dev/null 2>&1 && rm conftest.* ; } \
    || fn_error "requires $1"
}
fn_check_link()
{
  cat >conftest.c <<EOF
extern "C" { int $2(); }
int main(){ $2(); }
EOF
  { CC -L$prefix/lib $LDFLAGS conftest.c $LIBS >/dev/null 2>&1 && rm conftest.* ; } \
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
fn_check_includes Scotch scotch.h
fn_check_includes PT-Scotch ptscotch.h
fn_check_includes MUMPS mumps_c_types.h
fn_check_includes GLM glm/glm.hpp
fn_check_includes Matio matio.h
fn_check_includes HDF5 hdf5.h
fn_check_includes NetCDF netcdf.h
fn_check_includes Boost::regex boost/regex.hpp
fn_check_includes Boost::timer boost/timer.hpp
fn_check_includes Boost::chrono boost/chrono.hpp
fn_check_includes Boost::program_options boost/program_options.hpp
fn_check_includes Boost::system boost/system/error_code.hpp

test -e trilinos-$VERSION-Source.tar.xz \
  || fn_create_git_tarball trilinos-$VERSION-Source \
  || fn_error "could not fetch source"
echo "$SHA256SUM  trilinos-$VERSION-Source.tar.xz" | sha256sum --check \
  || fn_error "source hash mismatch"
printf "unpacking source" \
  && tar --checkpoint=1000 --checkpoint-action=exec='printf .' \
         -xf trilinos-$VERSION-Source.tar.xz \
  && echo "done" \
  || fn_error "could not untar source"
cd trilinos-$VERSION-Source

patches="
  trilinos-fortran-arg-mismatch.patch
  trilinos-amesos-superlu-dist-6.4.patch
  trilinos-amesos2-adapters-cce.patch
  trilinos-boostlib-tpl-lib-list.patch
  trilinos-stk-platform.patch
  trilinos-fei-test-utils.patch
"
fn_versgte $VERSION 12.14.1 \
  || patches="
       trilinos-amesos2-mumps-fix.patch
       trilinos-kokkos-bitops-cce.patch
       trilinos-kokkos-traits-cce.patch
       trilinos-stk-mallinfo.patch
       trilinos-stk-util-env.patch
       trilinos-sundance-vector.patch
       trilinos-sundance-vecmat.patch
       trilinos-superlu5.patch
       trilinos-superlu-dist-5.4-fix.patch
       trilinos-epetraext-hdf5-1.10-compat.patch
       trilinos-fortrilinos-line-length.patch
       trilinos-fortrilinos-gcc8.patch
       $patches"
fn_versgte $VERSION 12.18.1 \
  || {
  case $compiler:$GCC_VERSION in
    crayclang:*|gnu:9.*)
      patches="$patches
        trilinos-omp-shared-epetra.patch
        trilinos-omp-shared-stk.patch"
      ;;
  esac
  patches="
    trilinos-stk-classic-cv.patch
    trilinos-stk-classic-platform.patch
    $patches" ; }
{ echo "Applying patches:"; for p in $patches ; do echo "  $p"; done ; }
for p in $patches ; do
  patch -f -p1 <$top_dir/../patches/$p \
    || fn_error "patching failed"
done

trilinos_enable_packages="
  Amesos
  Amesos2
  Anasazi
  AztecOO
  Belos
  Epetra
  EpetraExt
  FEI
  ForTrilinos
  Galeri
  GlobiPack
  Ifpack
  Ifpack2
  Intrepid
  Isorropia
  Kokkos
  Komplex
  Mesquite
  ML
  Moertel
  MOOCHO
  MueLu
  NOX
  OptiPack
  Pamgen
  Phalanx
  Piro
  Pliris
  ROL
  RTOp
  Rythmos
  Sacado
  Shards
  ShyLU
  STK
  STKSearch
  STKTopology
  STKUtil
  Stokhos
  Stratimikos
  Sundance
  Teko
  Teuchos
  ThreadPool
  Thyra
  Tpetra
  TrilinosCouplings
  Triutils
  Xpetra
  Zoltan
  Zoltan2
  SEACAS
  SEACASExo2mat
  SEACASMat2exo
"


# The SuperLU and SuperLU_DIST interfaces in Amesos2 don't build well
# with CCE (and possibly newer versions of gcc), so we disable those.
amesos2_OPTIONS="\
Amesos2_ENABLE_SuperLU:BOOL=OFF,\
Amesos2_ENABLE_SuperLUDist:BOOL=OFF,\
Amesos2_ENABLE_KLU2:BOOL=ON,\
Amesos2_ENABLE_Basker:BOOL=ON,\
Amesos2_ENABLE_MUMPS:BOOL=ON"
epetra_OPTIONS="Epetra_ENABLE_THREADS:BOOL=ON"
ifpack_OPTIONS="Ifpack_ENABLE_METIS:BOOL=OFF"
kokkos_OPTIONS="Kokkos_ENABLE_Serial:BOOL=ON,Kokkos_ENABLE_OpenMP:BOOL=ON"
# Use ParMETIS in ML and Zoltan, instead of METIS
ml_OPTIONS="ML_ENABLE_METIS:BOOL=OFF"
case $VERSION in
  12.12.1) ml_OPTIONS="ML_ENABLE_SuperLU:BOOL=ON,$ml_OPTIONS" ;;
  # Version 12.14 ML and ShyLU support only SuperLU < 5.0
  *) ml_OPTIONS="ML_ENABLE_SuperLU:BOOL=OFF,$ml_OPTIONS"
     shylu_OPTIONS="ShyLU_DDBDDC_ENABLE_SuperLU:BOOL=OFF" ;;
esac
# According to RELEASE_NOTES for 11.10: "It it is not advisable to enable
# both [STK and STKClassic] in a single build of Trilinos"
stk_OPTIONS="Trilinos_ENABLE_STKClassic:BOOL=OFF"
zoltan_OPTIONS="Zoltan_ENABLE_METIS:BOOL=OFF,Zoltan_ENABLE_F90INTERFACE:BOOL=ON"
# CCE aborts when compiling one of Zoltan2's source if OpenMP is enabled.
zoltan2_OPTIONS="Zoltan2_ENABLE_OpenMP:BOOL=OFF"
# Workaround for https://github.com/trilinos/Trilinos/issues/244
zoltan2_OPTIONS="$zoltan2_OPTIONS,Zoltan2_ENABLE_Scotch:BOOL=OFF"

: ${CRAY_CPU_TARGET=`uname -m`}
case "$compiler" in
  crayclang)
    FFLAGS="-ef -hnocaf $FFLAGS"
    ;;
  cray)
    FFLAGS="-ef -hnocaf $FFLAGS"
    # 1836 and 1838 to suppress warnings about LaTeX tables embedded
    # in comments.
    CFLAGS="-hnodwarf -hnomessage=554:511:10144:1836:1838 $CFLAGS"
    # 12489 to suppress warnings about constexpr.
    CXXFLAGS="-hnomessage=10143:12489 $CXXFLAGS"
    ;;
  intel)
    CPPFLAGS="-DGTEST_USE_OWN_TR1_TUPLE $CPPFLAGS"
    ;;
  aocc)
    LIBS="$LIBS${LIBS+ }-lm"
    ;;
esac
case "$compiler" in
  cray|pgi) mpi_long_double=0 ;;
  *) mpi_long_double=1 ;;
esac

mkdir -p _build && cd _build
cat >configure-trilinos.sh <<EOF
#!/bin/sh
: \${CMAKE=`command -v cmake`}
rm -rf CMakeFiles CMakeCache.txt
unset DESTDIR # Prevent installing into anything but \$CMAKE_INSTALL_PREFIX
\$CMAKE \\
  -D CMAKE_BUILD_TYPE:STRING=RELEASE \\
  -D Trilinos_ENABLE_DEVELOPMENT_MODE:BOOL=OFF \\
  -D Trilinos_ASSERT_MISSING_PACKAGES:BOOL=OFF \\
  -D Trilinos_ENABLE_EXPLICIT_INSTANTIATION:BOOL=OFF \\
  -D Trilinos_ENABLE_TESTS:BOOL=OFF \\
  -D Trilinos_ENABLE_ALL_PACKAGES:BOOL=OFF \\
  -D Trilinos_ENABLE_ALL_OPTIONAL_PACKAGES:BOOL=OFF \\
  -D Trilinos_ENABLE_Fortran:BOOL=ON \\
  -D Trilinos_ENABLE_OpenMP:BOOL=ON \\
  -D BUILD_SHARED_LIBS:BOOL=NO \\
  -D TPL_FIND_SHARED_LIBS:BOOL=YES \\
  -D Trilinos_LINK_SEARCH_START_STATIC:BOOL=YES \\
  -D CMAKE_SKIP_INSTALL_RPATH:BOOL=ON \\
  -D Trilinos_ENABLE_EXPORT_MAKEFILES:BOOL=ON \\
  -D Trilinos_DEPS_XML_OUTPUT_FILE:FILEPATH="" \\
  -D CMAKE_C_SIZEOF_DATA_PTR=8 \\
  -D CMAKE_CXX_COMPILER:STRING=CC \\
  -D CMAKE_C_COMPILER:STRING=cc \\
  -D CMAKE_Fortran_COMPILER:STRING=ftn \\
  -D CMAKE_C_FLAGS:STRING="$CPPFLAGS $CFLAGS $CPPFLAGS $CFLAGS" \\
  -D CMAKE_CXX_FLAGS:STRING="$CPPFLAGS $CFLAGS $CXXFLAGS $CPPFLAGS $CXXFLAGS" \\
  -D CMAKE_Fortran_FLAGS:STRING="$CPPFLAGS $FFLAGS $CPPFLAGS $FFLAGS" \\
  -D CMAKE_EXE_LINKER_FLAGS:STRING="$LIBS${LIBS+ }\$LIBS $LDFLAGS${LDFLAGS+ }\$LDFLAGS" \\
  -D CMAKE_C_FLAGS_RELEASE_OVERRIDE="$OPTFLAGS -DNDEBUG" \\
  -D CMAKE_CXX_FLAGS_RELEASE_OVERRIDE="$OPTFLAGS -DNDEBUG" \\
  -D CMAKE_Fortran_FLAGS_RELEASE_OVERRIDE="$OPTFLAGS -DNDEBUG" \\
  -D Trilinos_EXTRA_LINK_FLAGS:STRING="$LIBS${LIBS+ }\$LIBS" ${OMPFLAG+\\
  -D OpenMP_C_FLAGS:STRING="$OMPFLAG" \\
  -D OpenMP_CXX_FLAGS:STRING="$OMPFLAG" \\
  -D OpenMP_Fortran_FLAGS:STRING="$FOMPFLAG" }\\
  -D TPL_ENABLE_BLAS:BOOL=ON \\
  -D TPL_ENABLE_LAPACK:BOOL=ON \\
  -D TPL_ENABLE_SCALAPACK:BOOL=ON \\
  -D BLAS_LIBRARY_NAMES="" \\
  -D LAPACK_LIBRARY_NAMES="" \\
  -D SCALAPACK_LIBRARY_NAMES="" \\
  -D TPL_ENABLE_Scotch:BOOL=ON \\
  -D TPL_Scotch_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D Scotch_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D TPL_ENABLE_SuperLU:BOOL=ON \\
  -D TPL_SuperLU_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D SuperLU_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D HAVE_SUPERLU_GLOBALLU_T_ARG:BOOL=YES \\
  -D TPL_ENABLE_SuperLUDist:BOOL=ON \\
  -D TPL_SuperLUDist_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D SuperLUDist_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D HAVE_SUPERLUDIST_ENUM_NAMESPACE:BOOL=YES \\
  -D HAVE_SUPERLUDIST_LUSTRUCTINIT_2ARG:BOOL=YES \\
  -D TPL_ENABLE_METIS:BOOL=ON \\
  -D TPL_METIS_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D METIS_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D TPL_ENABLE_ParMETIS:BOOL=ON \\
  -D TPL_ParMETIS_INCLUDE_DIRS:FILEPATH="$prefix/include" \\
  -D ParMETIS_LIBRARY_DIRS:FILEPATH="$prefix/lib" \\
  -D ParMETIS_LIBRARY_NAMES:STRING="parmetis;metis" \\
  -D TPL_ENABLE_MUMPS:BOOL=ON \\
  -D TPL_MUMPS_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D MUMPS_LIBRARY_DIRS:FILEPATH="$prefix/lib" \\
  -D MUMPS_LIBRARY_NAMES:STRING="dmumps;zmumps;smumps;cmumps;mumps_common;esmumps;ptesmumps;parmetis;ptscotch;scotch;scotcherr;pord" \\
  -D TPL_ENABLE_Matio:BOOL=ON \\
  -D TPL_Matio_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D Matio_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D TPL_ENABLE_GLM:BOOL=ON \\
  -D TPL_GLM_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D TPL_ENABLE_HDF5:BOOL=ON \\
  -D TPL_HDF5_INCLUDE_DIRS:FILEPATH=\$HDF5_DIR/include \\
  -D HDF5_LIBRARY_DIRS:FILEPATH="\$HDF5_DIR/lib" \\
  -D HDF5_LIBRARY_NAMES:STRING="hdf5_hl_parallel;hdf5_parallel;z;dl" \\
  -D TPL_ENABLE_Netcdf:BOOL=ON \\
  -D TPL_Netcdf_INCLUDE_DIRS:FILEPATH=\$NETCDF_DIR/include \\
  -D Netcdf_LIBRARY_DIRS:FILEPATH="\$NETCDF_DIR/lib;\$HDF5_DIR/lib" \\
  -D Netcdf_LIBRARY_NAMES:STRING="netcdf_parallel;hdf5_hl_parallel;hdf5_parallel;z;dl" \\
  -D TPL_ENABLE_Boost:BOOL=ON \\
  -D TPL_Boost_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D TPL_ENABLE_BoostLib:BOOL=ON \\
  -D TPL_BoostLib_INCLUDE_DIRS:FILEPATH=$prefix/include \\
  -D BoostLib_LIBRARY_DIRS:FILEPATH=$prefix/lib \\
  -D TPL_ENABLE_X11:BOOL=OFF \\
  -D TPL_ENABLE_MPI:BOOL=ON \\
  -D MPI_BASE_DIR:FILEPATH=$mpich \\
  -D MPI_EXEC:STRING=\${MPIEXEC:-aprun} \\
  -D MPI_EXEC_NUMPROCS_FLAG:STRING="-n" \\
  -D CMAKE_INSTALL_PREFIX:PATH=$prefix \\
EOF

for package in $trilinos_enable_packages; do
  cat >>configure-trilinos.sh <<EOF
  -D Trilinos_ENABLE_$package:BOOL=ON \\
EOF
  pkg=`echo $package | tr "A-Z" "a-z"`
  eval pkg_options=\$${pkg}_OPTIONS
  if test -n "$pkg_options"; then
    echo "  -D $pkg_options \\" | sed 's/,/ \\\n  -D /g' >>configure-trilinos.sh
  fi
done

# Flags for cross-compilation.  Many of the cmake checks for these
# features require execution of code, which does not always work in
# cross-compilation environments.  Provide default values here:
cat >>configure-trilinos.sh <<EOF
  -D HAVE_TEUCHOS_BLASFLOAT:BOOL=YES \\
  -D LAPACK_SLAPY2_WORKS:BOOL=YES \\
  -D HAVE_TEUCHOS_LAPACKLARND:BOOL=YES \\
EOF

# Include any additional cmake configuration options specified
cat >>configure-trilinos.sh <<EOF
  \$CMAKEFLAGS \\
  ..
EOF

# Additional configuration-level work that needs to be done for some compiler
# environments.
case $compiler in
  cray|crayclang)
    cat >>configure-trilinos.sh <<EOF
# When compiling fortran code, cmake or trilinos likes to insert -i8
# and -r8 compiler options for the intel compiler and mistakenly
# applies the same flags when cce is being used.  I (bavier) have not
# yet found a way to tell cmake how to use the appropriate commands
# for Fortran linking.
echo -n "Fixing CCE integer and real size compiler flags... "
find . \( -name link.txt -or -name flags.make \) -print |	\\
  xargs --no-run-if-empty sed -r --in-place=~~			\\
  -e "s/-i8/-sinteger64/g"					\\
  -e "s/-r8/-sreal64/g" ;
echo "done"
# Workaround for Bug 835225.  XXX: This overrides flags for all
# objects in stk_mesh_base; ideally we would like to override the
# flags for only the ElemElemGraph.ccp.o target.
_flags=packages/stk/stk_mesh/stk_mesh/base/CMakeFiles/stk_mesh_base.dir/flags.make
test -e \$_flags && \\
  sed --in-place=~ "s/-hpic\(.*-hpic\)/\1/;s/-O[0-3]/-O0/g" \$_flags
EOF
    ;;
esac
cat >>configure-trilinos.sh <<EOF
# Let the CrayPE compiler drivers determine whether libraries are
# linked statically or dynamically.
echo -n "Removing -Wl,-B... from link lines... "
find . -name link.txt |					\\
  xargs --no-run-if-empty sed --in-place=~		\\
  -e "s/-Wl,-B\(dynamic\|static\)//g" ;
echo "done"
# Work around linker errors about "undefined reference to __dlopen".
# This seems to be caused by the particular linking order that cmake
# produces, but can be worked around by leaving only the final
# reference to libdl on the link line.  Also turn absolute references
# into relative.
find . -name link.txt -print |                         \\
  xargs --no-run-if-empty sed --in-place=~~~           \\
  -e ":a;s,\([^ ]*/libdl\.[^ ]*\)\(.*\1\),\2,;t a"     \\
  -e "s,[^ ]*/libdl\.[^ ]*,-ldl,g" ;
EOF

test "$?" = "0" \
  && chmod +x configure-trilinos.sh \
  && ./configure-trilinos.sh \
  || fn_error "configuration failed"
make --jobs=$make_jobs install \
  || fn_error "build failed"


# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:

