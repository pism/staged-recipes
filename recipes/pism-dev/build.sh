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
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"

export CMAKE_BUILD_PARALLEL_LEVEL="${CPU_COUNT}"

# Bake the FINAL conda-prefix path for pism_config.nc into the binary so
# conda's prefix-replacement machinery rewrites it at install time.
# Without this, scikit-build-core's wheel-staging temp dir (e.g.
# /tmp/tmpXXXX/wheel/data/share/pism/pism_config.nc) gets baked in and
# the binary fails at runtime with "No such file or directory".
${PYTHON} -m pip install . -vv \
          --no-build-isolation \
          --no-deps \
          --prefix="${PREFIX}" \
          --config-settings=cmake.build-type=Release \
          --config-settings=cmake.define.Pism_CONFIG_FILE="${PREFIX}/share/pism/pism_config.nc"
