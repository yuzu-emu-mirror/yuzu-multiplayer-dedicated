#!/bin/bash -e

FMT_VERSION="8.1.1"
JSON_VERSION="3.11.2"
ZLIB_VERSION="1.2.12"
ZSTD_VERSION="1.5.2"
LZ4_VERSION="1.9.4"
BOOST_VERSION="1.80.0"

cmake_install() {
    cmake . -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON "$@"
    ninja install
}

# $1: url $2: dir name $3: sha256sum
download_extract() {
    local filename
    filename="$(basename "$1")"
    wget "$1" -O "$filename"
    echo "$3 $filename" > "$filename".sha256sum
    sha256sum -c "$filename".sha256sum
    bsdtar xf "$filename"
    pushd "$2"
}

info() {
    echo -e "\e[1m--> Downloading and building $1...\e[0m"
}

info "fmt ${FMT_VERSION}"
download_extract "https://github.com/fmtlib/fmt/releases/download/${FMT_VERSION}/fmt-${FMT_VERSION}.zip" "fmt-${FMT_VERSION}" 23778bad8edba12d76e4075da06db591f3b0e3c6c04928ced4a7282ca3400e5d
cmake_install -DFMT_DOC=OFF -DFMT_TEST=OFF
popd

info "nlohmann_json ${JSON_VERSION}"
download_extract "https://github.com/nlohmann/json/releases/download/v${JSON_VERSION}/json.tar.xz" json 8c4b26bf4b422252e13f332bc5e388ec0ab5c3443d24399acb675e68278d341f
cmake_install -DJSON_BuildTests=OFF
popd

info "zlib ${ZLIB_VERSION}"
download_extract "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" "zlib-${ZLIB_VERSION}" d8688496ea40fb61787500e863cc63c9afcbc524468cedeb478068924eb54932
cmake_install -DCMAKE_POLICY_DEFAULT_CMP0069=NEW
# delete shared libraies as we can't use them in the final image
rm -v /usr/local/lib/libz.so*
popd

info "zstd ${ZSTD_VERSION}"
download_extract "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" "zstd-${ZSTD_VERSION}"/build/cmake 7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0
cmake_install -DZSTD_BUILD_PROGRAMS=OFF -DBUILD_TESTING=OFF -GNinja -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_SHARED=OFF
popd

info "lz4 ${LZ4_VERSION}"
download_extract "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz" "lz4-${LZ4_VERSION}/build/cmake" 0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b
cmake_install -DLZ4_BUILD_CLI=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF
# we need to adjust the exported name of the static library
cat << EOF >> /usr/local/lib/cmake/lz4/lz4Targets.cmake
# Injected commands by yuzu-room builder script
add_library(lz4::lz4 ALIAS LZ4::lz4_static)
EOF
popd

info "boost ${BOOST_VERSION}"
download_extract "https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//\./_}.tar.gz" "boost_${BOOST_VERSION//\./_}" 4b2136f98bdd1f5857f1c3dea9ac2018effe65286cf251534b6ae20cc45e1847
# Boost use its own ad-hoc build system
# we only enable what yuzu needs
./bootstrap.sh --with-libraries=context,container,system,headers
./b2 -j "$(nproc)" install --prefix=/usr/local
popd
