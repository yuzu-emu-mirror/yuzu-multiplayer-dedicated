#!/bin/bash -e

FMT_VERSION="9.1.0"
JSON_VERSION="3.11.2"
ZLIB_VERSION="1.2.13"
ZSTD_VERSION="1.5.4"
LZ4_VERSION="1.9.4"
BOOST_VERSION="1.81.0"

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
download_extract "https://github.com/fmtlib/fmt/releases/download/${FMT_VERSION}/fmt-${FMT_VERSION}.zip" "fmt-${FMT_VERSION}" cceb4cb9366e18a5742128cb3524ce5f50e88b476f1e54737a47ffdf4df4c996
cmake_install -DFMT_DOC=OFF -DFMT_TEST=OFF
popd

info "nlohmann_json ${JSON_VERSION}"
download_extract "https://github.com/nlohmann/json/releases/download/v${JSON_VERSION}/json.tar.xz" json 8c4b26bf4b422252e13f332bc5e388ec0ab5c3443d24399acb675e68278d341f
cmake_install -DJSON_BuildTests=OFF
popd

info "zlib ${ZLIB_VERSION}"
download_extract "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.xz" "zlib-${ZLIB_VERSION}" d14c38e313afc35a9a8760dadf26042f51ea0f5d154b0630a31da0540107fb98
cmake_install -DCMAKE_POLICY_DEFAULT_CMP0069=NEW
# delete shared libraies as we can't use them in the final image
rm -v /usr/local/lib/libz.so*
popd

info "zstd ${ZSTD_VERSION}"
download_extract "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" "zstd-${ZSTD_VERSION}"/build/cmake 0f470992aedad543126d06efab344dc5f3e171893810455787d38347343a4424
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
download_extract "https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//\./_}.tar.gz" "boost_${BOOST_VERSION//\./_}" 205666dea9f6a7cfed87c7a6dfbeb52a2c1b9de55712c9c1a87735d7181452b6
# Boost use its own ad-hoc build system
# we only enable what yuzu needs
./bootstrap.sh --with-libraries=context,container,system,headers
./b2 -j "$(nproc)" install --prefix=/usr/local
popd

# fake xbyak for non-amd64 (workaround a CMakeLists bug in yuzu)
echo '!<arch>' > /usr/local/lib/libxbyak.a
