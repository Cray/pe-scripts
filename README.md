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

## Usage
These scripts do not handle dependency resolution,
but do rudimentary checks for prerequisites.  They will use system libraries if available.

Each script supports a `--help` option for convenience:
```sh
$ ./sh/petsc.sh --help
Usage: ./sh/petsc.sh [OPTIONS]

Default for option is specified in brackets.

Options:
  -h, --help        Print this help message
  --prefix=<DIR>    Install package under DIR [/lus/scratch/bavier/tmp/bavier/_install]
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
