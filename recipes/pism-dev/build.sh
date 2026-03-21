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
# The python executable and libpython both contain _PyRuntime; with
# two-level namespaces, _cpp.so bound to libpython uses the uninitialized
# copy, causing a segfault on import. Remove ${Python3_LIBRARIES} from
# the SWIG module's link line so symbols resolve from the interpreter.
if [[ "${target_platform}" == osx-* ]]; then
    sed -i.bak 's|${Python3_LIBRARIES} ||g' \
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
      -D Pism_USE_PARALLEL_NETCDF4=YES \
      -D Pism_USE_PROJ=YES \
      -D Pism_USE_YAC=YES \
      "${SRC_DIR}"


make -j"${CPU_COUNT}"

make install

# On macOS, the python executable and libpython both contain _PyRuntime.
# With two-level namespaces, _cpp.so bound to libpython uses the
# uninitialized copy, causing a segfault on import. Tell CMake to use
# Python3::Module (no libpython link) instead of Python3::Python.
if [[ "${target_platform}" == osx-* ]]; then
    _cpp="${PREFIX}/lib/python${PY_VER}/site-packages/PISM/_cpp.so"
    if otool -L "${_cpp}" | grep -q libpython; then
        echo "ERROR: _cpp.so still links to libpython — import PISM will segfault"
        exit 1
    fi
fi
