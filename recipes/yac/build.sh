#!/bin/bash

set -x

autoreconf -vfi

export CC=mpicc
export FC=mpifort

if [[ "${mpi}" == "openmpi" ]]; then
  export MPI_LAUNCH="${PREFIX}/bin/mpirun --oversubscribe"
  export OMPI_MCA_plm_rsh_agent=""
else
  export MPI_LAUNCH="${PREFIX}/bin/mpirun"
fi

./configure --prefix=${PREFIX} \
            --with-yaxt-root=${PREFIX} \
            --disable-netcdf \
            --disable-examples \
            --disable-tools \
            --disable-deprecated \
            --enable-python-bindings \
            --with-pic

make -j ${CPU_COUNT} all

make install

if [[ "${target_platform}" == osx-* ]]; then
    export DL_TYPE="-dynamiclib"
    export DL_EXT="dylib"
    export LDFLAGS="-Wl,-no_compact_unwind"
elif [[ "${target_platform}" == linux-* ]]; then
    export DL_TYPE="-shared"
    export DL_EXT="so"
fi

export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:${PREFIX}/lib/pkgconfig
${CC} ${DL_TYPE} ./src/core/*.o ./src/core/ppm/*.o ./src/core/grids/*.o ./src/core/interpolation/*.o ./src/core/interpolation/methods/*.o ./src/core/interpolation/operators/*.o $(pkg-config yac-core --variable clibs) -I${PREFIX}/include -o libyac_core.${DL_EXT}
cp libyac_core.${DL_EXT} ${PREFIX}/lib/

${CC} ${DL_TYPE} ./src/mci/*.o -lyac_core $(pkg-config yac-mci --variable clibs) -I${PREFIX}/include -lgfortran -o libyac_mci.${DL_EXT}
${CC} ${DL_TYPE} ./src/utils/*.o -lyac_core $(pkg-config yac-utils --variable clibs) -I${PREFIX}/include  -o libyac_utils.${DL_EXT}

cp libyac_mci.${DL_EXT} ${PREFIX}/lib/
cp libyac_utils.${DL_EXT} ${PREFIX}/lib/
