# Common utilities.
#
# Copyright 2019, 2020 Cray, Inc.
####

# Requires the "PACKAGE" variable be defined before sourcing.

prefix=${TMPDIR:-/tmp}/$USER/_install
make_jobs=1
show_help=false

if test "${VERSION+set}" != "set" ; then
  VERSION=`echo "$VERSIONS" | sed -n '/^ *$/!h;${g;s/^ *//;s/ *$//;s/:.*//;p}'`
fi

: ${WGET=wget --tries=2 --progress=dot:mega} # for fetching source tarballs

fn_error()
{
  fn_error_status=$?
  echo "$PACKAGE: error: $1"
  exit $fn_error_status
}

fn_warn()
{
  fn_warn_status=$?
  printf "%s: warning: %s\n" "$PACKAGE" "$@"
  return $fn_warn_status
}

fn_versmin(){
  (echo "$1"; echo "$2") \
    | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -n1
}

fn_versgte(){
  test "$1" = "$2" \
    || test `fn_versmin "$1" "$2"` = "$2"
}

fn_checkpoint_tpsl(){
  if ! test -e $prefix/.tpsl || ! grep -q $PACKAGE $prefix/.tpsl ; then
    printf "%s\n" "$PACKAGE" >>$prefix/.tpsl
  fi
}

fn_check_tar_version(){
  if ${fn_cv_check_tar_version_done+:}; then return; fi
  # Versions of tar < 1.27 produce slightly different header entries
  # for the "devmajor", "devminor", and "cksum" header fields.
  tar --mtime=0 --owner=root --group=root \
      --pax-option=exthdr.name=%d/PaxHeaders/%f,mtime=0,delete=atime,delete=ctime \
      --pax-option=globexthdr.name=/tmp/GlobalHead.%n --pax-option=globexthdr.mtime=0 \
      --files-from=/dev/null -cf - \
    | sha256sum | awk '{print $1}' \
    | test `cat` = 89e86be755e306be8e78b8df6031ed20f693eeacd886af8701c6c534aa94be0f \
    && fn_cv_check_tar_version_done=yes \
    || fn_error "requires tar >= 1.27"
}

fn_pack_git_tarball(){
  dir="$1"
  fn_check_tar_version
  printf "packing tarball";
  # We need reproducible tarball generation.  We'd like to use tar's
  # "--sort=name" option, which was added in tar 1.28, but it's not
  # available on some OS's we need to support.  So instead fall back
  # to providing sorted filenames to tar through the slightly-slower
  # `find | sort`.
  export LC_ALL=POSIX;   # for deterministic sorting
  mtime=`cd $dir && git log -n 1 --pretty=format:"%at"`
  find $dir -name '.git' -prune -o -print | sort \
    | tar --checkpoint=1000 --checkpoint-action=exec='printf .' \
          --mtime=@$mtime \
          --owner=root:0 --group=root:0 \
          --pax-option=globexthdr.name=/tmp/GlobalHead.%n \
          --pax-option=globexthdr.mtime=$mtime \
          --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime,mtime=$mtime \
          --exclude=.gitignore --exclude=.gitmodules --exclude=.gitattributes \
          --no-recursion --files-from=- -cJf $dir.tar.xz \
    && printf "done\n"
}

fn_create_git_tarball()
{
  dir="$1"
  checkout="fn_${PACKAGE}_git_checkout"
  fn_check_tar_version
  case "$(command -v $checkout)" in
    $checkout)
      if ! $checkout $dir ; then
        fn_error "don't know how to make release tarball for version $VERSION"
      fi ;;
    "") fn_error "missing definition of $checkout" ;;
  esac \
    && fn_pack_git_tarball $dir \
    && { printf "removing intermediate source directory..." ;
         rm -rf $dir ;
         printf "done\n" ; } \
    || fn_error "could not create tarball for version $VERSION from git"
}

arg_prev=
for arg_option ; do
  # If the previous option needs an argument, assign it.
  if test -n "$arg_prev" ; then
    eval $arg_prev=\$arg_option
    arg_prev=
    continue
  fi

  case $arg_option in
    *=?*) arg_optarg=`expr "x$arg_option" : '[^=]*=\(.*\)'` ;;
    *=)   arg_optarg= ;;
    *)    arg_optarg=yes ;;
  esac

  case $arg_option in
    -h | --help | --hel | --he | --h | help | HELP)
      show_help=: ;;
    -prefix | --prefix | --prefi | --pref | --pre | --pr | --p)
      arg_prev=prefix ;;
    -prefix=* | --prefix=* | --pref=* | --pref=* | --pre=* | --pr=* | --p=*)
      prefix=$arg_optarg ;;
    -j | --jobs | --job | --jo | --j)
      sh_prev=make_jobs ;;
    -j=* | --jobs=* | --job=* | --jo=* | --j=*)
      make_jobs=$arg_optarg ;;
    -j*)
      make_jobs=`expr "$arg_option" : '-j\([0-9][0-9]*\)'` ;;
    --version | --versio | --versi | --vers | --ver | --ve)
      printf "%s\n" "$VERSION"; exit 0 ;;
    --version=* | --versio=* | --versi=* | --vers=* | --ver=* | --ve=*)
      VERSION=$arg_optarg ;;
    -*) fn_error "unrecognized option: '$arg_option'
Try \`$0 --help' for more information"
  esac
done

if $show_help ; then
  cat <<EOF
Usage: $0 [OPTIONS]

Default for option is specified in brackets.

Options:
  -h, --help        Print this help message
  --prefix=<DIR>    Install package under DIR [$prefix]
  -j[N], --jobs[=N] Build with up to N processes [$make_jobs]
EOF
  if test "${VERSIONS+set}" = "set" ; then
    cat <<EOF
  --version[=<VER>] Build and install version VER of $PACKAGE.
                    Must be one of the available versions
                    listed below.  Without argument: print the
                    current version [$VERSION]

Available versions:
EOF
    for v in `echo $VERSIONS | sed 's/:[^ ]*//g'` ; do
      case $v in
        $VERSION) printf "  - %s (*)\n" $v ;;
        *)        printf "  - %s\n" $v ;;
      esac
    done
  elif test "$VERSION" ; then
    cat <<EOF
  --version         Print the current version [$VERSION]
EOF
  fi
  cat <<EOF

Send bug reports to bavier@cray.com
EOF
  status=$?
fi
if test "$VERSION" -a ! "$SHA256SUM" ; then \
  SHA256SUM=`echo $VERSIONS | sed 's/.*'$VERSION':\([^ ]*\).*/\1/;t;q1'` \
    || fn_error "no known sha256sum for version $VERSION"
fi
$show_help && exit $status

# Check that the install prefix is absolute
case "$prefix" in
  /*) : ;;
  *) fn_error "installation prefix must be absolute" ;;
esac
# Add any "bin" directory from $prefix to PATH
test -d "$prefix/bin" \
  && PATH="$prefix/bin:$PATH"

# Check that our wget "works"
$WGET --version >/dev/null 2>&1 \
  || fn_error "set the WGET variable to a functional wget program"

export CRAYPE_LINK_TYPE=dynamic

# Detect compiler
case $PE_ENV in
  CRAY)
    if cc --version 2>&1 | grep --quiet clang ; then
      compiler=crayclang
    else
      compiler=cray
    fi
    ;;
  GNU|INTEL|PGI|ALLINEA|AOCC)
    compiler=`echo $PE_ENV | tr A-Z a-z` ;;
  *) fn_error "could not detect compiler vendor" ;;
esac

# Set some default compiler flags
case "$compiler" in
  cray) PICFLAG="-hpic" ;;
  pgi)  PICFLAG="-fpic" ;;
  *)    PICFLAG="-fPIC" ;;
esac
case "$compiler" in
  cray)  OMPFLAG="-homp" ;;
  intel) OMPFLAG="-qopenmp" ;;
  pgi)   OMPFLAG="-mp" ;;
  gnu|crayclang|allinea|aocc) OMPFLAG="-fopenmp" ;
esac
case "$compiler" in
  crayclang) FOMPFLAG="-homp" ;;
esac
case "$compiler" in
  cray) C99FLAG="-hstd=c99" ;;
  pgi) C99FLAG="-c99" ;;
  *) C99FLAG="-std=c99" ;;
esac
case "$compiler" in
  cray)
    FFLAGS="-O2 -F -em -ef -hnocaf"
    CFLAGS="-O2 -hnomessage=11709"
    X86FLAGS="-hcpu=x86-64"
    ARCHFLAGS="-hcpu=`echo $CRAY_CPU_TARGET | tr 'A-Z_' 'a-z-'`"
    PE_LIBS="-lfi -lf -lu -lcraymath -lcraymp"
    case %{_arch} in
      aarch64)
        _craylibs_arch="AARCH64"
        LD="$LINKER_AARCH64"
        gcc_aarch64=`find $GCC_AARCH64 -name 'libgcc.a' \
                     | head -n1 \
                     | sed 's,/[^/]*$,,'`
        PE_LIBS="$PE_LIBS -L$gcc_aarch64 -lgcc" ;; # for soft-float symbols
      *) _craylibs_arch="X86_64" ;;
    esac
    PE_LDDIRS="$PE_LDDIRS \
               -L`module show cce/$CRAY_CC_VERSION 2>&1 \
                  | sed -n '/\bCRAYLIBS_'$_craylibs_arch'\b/{s,[^ ]* *[^ ]* *,,;s,:, -L,g;p;q}'`"
    ;;
  crayclang)
    FFLAGS="-O2 -F -em -ef -hnocaf"
    CFLAGS="-O3 -ffast-math"
    PE_LIBS="-lfi -lf -lu -lcraymath -lcraymp -lm"
    ;;
  gnu)
    FFLAGS="-O3 -ffast-math"
    X86FLAGS="-march=x86-64"
    gcc_lib_path=`gcc -print-search-dirs \
                  | sed '/^lib/b 1;d;:1;s|/[^/.][^/]*/\.\./|/|;t 1;s/.*:[^=]*=//'`
    PE_LDDIRS="-L`echo $gcc_lib_path | sed 's/:/ -L/g'`"
    PE_LIBS="-lgfortran -lgcc"
    OMPLIBS="-lgomp"
    case $CRAY_CPU_TARGET in
      x86_64) ARCHFLAGS="$X86FLAGS" ;;
      interlagos) ARCHFLAGS="-march=bdver1" ;;
      sandybridge)
        case $GCC_VERSION in
          4.8.*) ARCHFLAGS="-march=corei7-avx" ;;
          *) ARCHFLAGS="-march=sandybridge" ;;
        esac
        ;;
      haswell)
        case $GCC_VERSION in
          4.8.*) ARCHFLAGS="-march=core-avx2" ;;
          *) ARCHFLAGS="-march=haswell" ;;
        esac
        ;;
      mic-knl)
        case $GCC_VERSION in
          4.8.*) ARCHFLAGS="-march=core-avx2" ;; # no avx512 in 4.8
          4.9.*) ARCHFLAGS="-march=core-avx2 -mavx512f -mavx512pf -mavx512er -mavx512cd" ;;
          *) ARCHFLAGS="-march=knl" ;;
        esac
        ;;
      x86-skylake)
        case $GCC_VERSION in
          4.*|5.*)
            ARCHFLAGS="-march=core-avx2 -madx -mhle -mrtm -mrdseed -mfxsr -mxsave -mxsaveopt"
            case $GCC_VERSION in
              4.9.*|5.*) ARCHFLAGS="-mavx512f -mavx512cd $ARCHFLAGS" ;;
            esac
            case $GCC_VERSION in
              5.*) ARCHFLAGS="-mavx512dq -mavx512bw -mavx512vl $ARCHFLAGS" ;;
            esac
            ;;
          *) ARCHFLAGS="-march=skylake-avx512" ;;
        esac
        ;;
      "") ARCHFLAGS="" ;;
    esac
    CFLAGS="$FFLAGS $ARCHFLAGS"
    FFLAGS="$FFLAGS $ARCHFLAGS"
    ;;
  intel)
    OMPLIBS="-L$INTEL_PATH/compiler/lib/intel64 -liomp5"
    PE_LDDIRS="-L`module show intel/$INTEL_VERSION 2>&1 | sed -n '/\bLIBRARY_PATH\b/{s/.*PATH *//;s/:/ -L/g;p;q}'`"
    # -lirc is for _intel_fast_memset, _intel_fast_memcpy,
    # __intel_ssse3_rep_memcpy, __intel_sse2_strlen, etc...
    PE_LIBS="-lirc -limf -lsvml -lipgo -ldecimal -lifcore"
    ;;
  pgi)
    FFLAGS="-O3 -fast -fastsse"
    X86FLAGS="-tp=x64"
    case $CRAY_CPU_TARGET in
      x86_64) ARCHFLAGS="$X86FLAGS" ;;
      interlagos) ARCHFLAGS="-tp=bulldozer-64" ;;
      sandybridge) ARCHFLAGS="-tp=sandybridge-64" ;;
      # PGI not supported on haswell, mic, or skylake
    esac
    case $PGI_VERS_STR in
      14.*)
        # For PGI 14.* there are static libraries in both the 'lib'
        # and 'libso' directories, the difference being in most cases
        # that the libraries in 'libso' were built with -fpic.  Prefer
        # these libraries by only including the 'libso' directories in
        # PE_LDDIRS.
        lib_regex='\bLD_LIBRARY_PATH.*libso.*\b' ;;
      *) lib_regex='\bLD_LIBRARY_PATH.*lib.*\b' ;;
    esac
    _pgi_libdirs=`module show pgi/$PGI_VERS_STR 2>&1 \
                    | sed -n "/$lib_regex/{s/.*PATH *//;s/:/ /g;p}"`
    PE_LDDIRS=`echo $_pgi_libdirs | sed 's/^/-L/;s/  */ -L/g'`
    PE_LIBS="-lpgc -lpgf90 -lpgf90rtl"
    case $PGI_VERS_STR in
      14.*|15.*) : ;;
      *) PE_LIBS="$PE_LIBS -lpgf902" ;; # __get_size_of
    esac
    OMPLIBS="-lpgmp"
    CFLAGS="$FFLAGS $ARCHFLAGS"
    FFLAGS="$FFLAGS $ARCHFLAGS"
    ;;
  allinea|aocc)
    FFLAGS="-O3 -ffast-math"
    CFLAGS="$FFLAGS"
esac                            # %{compiler}

: ${FOMPFLAG="$OMPFLAG"}

# Local Variables:
# indent-tabs-mode:nil
# sh-basic-offset:2
# End:
