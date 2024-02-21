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

optimization_flags="-O3"

# scrub debug-prefix-map args, which cause problems in pkg-config
export CFLAGS=$(echo ${CFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-fdebug\-prefix\-map[^ ]*@@g')
export CC="mpicc"
export CXX="mpicxx"


cmake -DCMAKE_CXX_FLAGS="${optimization_flags}" \
      -DCMAKE_C_FLAGS="${optimization_flags}" \
      -DCMAKE_INSTALL_PREFIX=$PISM_DIR \
      -DPism_BUILD_PYTHON_BINDINGS=ON \
      -DPism_USE_JANSSON=NO \
      -DPism_PKG_CONFIG_STATIC=OFF \
      -DPism_USE_PARALLEL_NETCDF4=YES \
      -DPism_USE_PROJ=YES \
      $PISM_DIR || (cat configure.log && exit 1)



make MAKE_NP=${CPU_COUNT}

make install

