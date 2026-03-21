#!/bin/bash
set -ex

if [[ "${target_platform}" == linux-* ]]; then
    export LDFLAGS="-pthread -fopenmp ${LDFLAGS}"
    export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"
elif [[ "${target_platform}" == osx-* ]]; then
    export LDFLAGS="${LDFLAGS} -undefined dynamic_lookup"
fi

optimization_flags="-O3"

export CC="mpicc"
export CXX="mpicxx"


# On macOS, Python extension modules must not link libpython directly.
# See pism-dev/build.sh for details.
if [[ "${target_platform}" == osx-* ]]; then
    sed -i.bak 's|TARGET_LINK_LIBRARIES(cpp ${Python3_LIBRARIES}|TARGET_LINK_LIBRARIES(cpp|' \
        "${SRC_DIR}/src/pythonbindings/CMakeLists.txt"
fi

cmake -D CMAKE_CXX_FLAGS="${optimization_flags}" \
      -D CMAKE_C_FLAGS="${optimization_flags}" \
      -D CMAKE_PREFIX_PATH="${PREFIX}" \
      -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
      -D CMAKE_INSTALL_LIBDIR=lib \
      -D Python3_EXECUTABLE=${PREFIX}/bin/python \
      -D Pism_DEBUG=YES \
      -D Pism_BUILD_PYTHON_BINDINGS=YES \
      -D Pism_ENABLE_DOCUMENTATION=NO \
      -D Pism_PKG_CONFIG_STATIC=NO \
      -D Pism_USE_JANSSON=NO \
      -D Pism_USE_PARALLEL_NETCDF4=YES \
      -D Pism_USE_PROJ=YES \
      -D Pism_USE_YAC=YES \
      "${SRC_DIR}"


make -j"${CPU_COUNT}"

make install
