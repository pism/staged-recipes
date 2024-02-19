#!/bin/bash
set -ex

export PISM_DIR=$SRC_DIR

unset F90
unset F77
unset CC
unset CXX

if [[ "$target_platform" == linux-* ]]; then
    export LDFLAGS="-pthread -fopenmp $LDFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
fi

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export FFLAGS=$(echo ${FFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')

if [[ $mpi == "openmpi" ]]; then
  export LIBS="-Wl,-rpath,$PREFIX/lib -lmpi_mpifh -lgfortran"
elif [[ $mpi == "mpich" ]]; then
  export LIBS="-lmpifort -lgfortran"
fi

if [[ $mpi == "openmpi" ]]; then
  export OMPI_MCA_plm=isolated
  export OMPI_MCA_rmaps_base_oversubscribe=yes
  export OMPI_MCA_btl_vader_single_copy_mechanism=none

  export OMPI_CC=$CC
  export OPAL_PREFIX=$PREFIX
elif [[ $mpi == "mpich" ]]; then
  export HYDRA_LAUNCHER=fork
fi

cmake -DCMAKE_CXX_FLAGS="${optimization_flags}" \
      -DCMAKE_C_FLAGS="${optimization_flags}" \
      -DCMAKE_INSTALL_PREFIX=$PISM_DIR \
      -DPism_BUILD_PYTHON_BINDINGS=ON \
      -DPism_USE_JANSSON=NO \
      -DPism_PKG_CONFIG_STATIC=OFF \
      -DPism_USE_PARALLEL_NETCDF4=YES \
      -DPism_USE_PROJ=YES \
      $PISM_DIR/sources || (cat configure.log && exit 1)


# Verify that gcc_ext isn't linked
for f in $PETSC_ARCH/lib/petsc/conf/petscvariables $PETSC_ARCH/lib/pkgconfig/PETSc.pc; do
  if grep gcc_ext $f; then
    echo "gcc_ext found in $f"
    exit 1
  fi
done

sedinplace() {
  if [[ $(uname) == Darwin ]]; then
    sed -i "" "$@"
  else
    sed -i"" "$@"
  fi
}

# Remove abspath of ${BUILD_PREFIX}/bin/python
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/include/petscconf.h
sedinplace "s%${BUILD_PREFIX}/bin/python%python%g" $PETSC_ARCH/lib/petsc/conf/petscvariables
sedinplace "s%${BUILD_PREFIX}/bin/python%/usr/bin/env python%g" $PETSC_ARCH/lib/petsc/conf/reconfigure-arch-conda-c-opt.py

# Replace abspath of ${PETSC_DIR} and ${BUILD_PREFIX} with ${PREFIX}
for path in $PETSC_DIR $BUILD_PREFIX; do
    for f in $(grep -l "${path}" $PETSC_ARCH/include/petsc*.h); do
        echo "Fixing ${path} in $f"
        sedinplace s%$path%\${PREFIX}%g $f
    done
done

make MAKE_NP=${CPU_COUNT}

if [[ "$CONDA_BUILD_CROSS_COMPILATION" != "1" ]]; then
  # FIXME: Workaround mpiexec setting O_NONBLOCK in std{in|out|err}
  # See https://github.com/conda-forge/conda-smithy/pull/337
  # See https://github.com/pmodels/mpich/pull/2755
  if [[ $(uname) != Darwin ]]; then
  # FIXME: Failures in some macOS builds
  # ** On entry to DGEMM parameter number 13 had an illegal value
  make check MPIEXEC="${RECIPE_DIR}/mpiexec.sh"
  fi
fi

make install

# Remove unneeded files
rm -f ${PREFIX}/lib/petsc/conf/configure-hash
find $PREFIX/lib/petsc -name '*.pyc' -delete

# Replace ${BUILD_PREFIX} after installation,
# otherwise 'make install' above may fail
for f in $(grep -l "${BUILD_PREFIX}" -R "${PREFIX}/lib/petsc"); do
  echo "Fixing ${BUILD_PREFIX} in $f"
  sedinplace s%${BUILD_PREFIX}%${PREFIX}%g $f
done

echo "Removing example files"
du -hs $PREFIX/share/petsc/examples/src
rm -fr $PREFIX/share/petsc/examples/src
echo "Removing data files"
du -hs $PREFIX/share/petsc/datafiles/*
rm -fr $PREFIX/share/petsc/datafiles
