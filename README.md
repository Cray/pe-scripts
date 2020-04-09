# Cray build scripts

These scripts are intended to be used for building
software products under the Cray PE environment.

## Supported Products

* TPSL - Cray's collection of third-party scientific libraries
  * [HYPRE](https://www.llnl.gov/casc/hypre/)
  * [METIS](http://glaros.dtc.umn.edu/gkhome/metis/metis/overview)
  * [ParMETIS](http://glaros.dtc.umn.edu/gkhome/metis/parmetis/overview)
  * [MUMPS](http://mumps.enseeiht.fr/)
  * [SUNDIALS](https://computation.llnl.gov/projects/sundials)
  * [SuperLU](https://crd-legacy.lbl.gov/~xiaoye/SuperLU/)
  * [SuperLU_DIST](https://crd-legacy.lbl.gov/~xiaoye/SuperLU/)
  * [Scotch](http://www.labri.fr/perso/pelegrin/scotch/)
  * [GLM](https://github.com/g-truc/glm)
  * [Matio](https://sourceforge.net/projects/matio/)
* [Boost](https://www.boost.org/)
* [PETSc](https://www.mcs.anl.gov/petsc/)
* [SLEPc](https://slepc.upv.es)
* [Trilinos](https://www.trilinos.org)
* [ADIOS](https://www.olcf.ornl.gov/center-projects/adios/)

## Usage
These scripts do not handle dependency resolution,
but do rudimentary checks for prerequisites.  They will use system libraries if available.

Each script supports a `--help` option for convenience:
```sh
$ ./sh/tpsl.sh --help
Usage: ./sh/tpsl.sh [OPTIONS]

Default for option is specified in brackets.

Options:
  -h, --help        Print this help message
  --prefix=<DIR>    Install package under DIR [/tmp/jdoe/_install]
  -j[N], --jobs[=N] Build with up to N processes [1]

Send bug reports to bavier@cray.com
```

and can be run to install each product, for example:

```sh
$ git clone https://github.com/Cray/pe-scripts
$ cd pe-scripts
$ module add PrgEnv-gnu cmake cray-mpich cray-hdf5-parallel cray-netcdf-hdf5parallel
$ prefix=`pwd`/_install
$ ./sh/tpsl.sh --prefix=$prefix --jobs=8
$ ./sh/petsc.sh --prefix=$prefix --jobs=8
$ ./sh/boost.sh --prefix=$prefix --jobs=8
$ ./sh/trilinos.sh --prefix=$prefix --jobs=8
```
The TPSL libraries can also be built individually, e.g.:
```sh
$ ./sh/tpsl/superlu.sh --prefix=$prefix --jobs=8
```
The TPSL script has a rudimentary inventory system to avoid installing
TPSL libraries that have already been installed to the given prefix.

### Version selection

Some package scripts can install one of several different versions.
If this is the case, then the output from `--help` will list the
available versions than can be chosen with the `--version=...` option,
e.g.:
```sh
$ ./sh/petsc.sh --help
Usage: ./sh/petsc.sh [OPTIONS]

Default for option is specified in brackets.

Options:
  -h, --help        Print this help message
  --prefix=<DIR>    Install package under DIR [/tmp/jdoe/_install]
  -j[N], --jobs[=N] Build with up to N processes [1]
  --version[=<VER>] Build and install version VER of petsc.
                    Must be one of the available versions
                    listed below.  Without argument: print the
                    current version [3.13.0]

Available versions:
  - 3.10.3
  - 3.10.5
  - 3.11.4
  - 3.12.5
  - 3.13.0 (*)

Send bug reports to bavier@cray.com
$ ./sh/petsc.sh --version=3.12.5 --prefix=$prefix --jobs=4
```

For packages such as PETSc or Trilinos, that can satisfy dependencies
using packages installed from these scripts, there are no guarantees
if using an arbitrary combination of package versions.  Generally, the
default versions should work properly together, and other combinations
may be untested.
