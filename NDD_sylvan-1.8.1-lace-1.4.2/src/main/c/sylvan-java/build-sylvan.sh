#!/usr/bin/env bash
#
# Copyright 2018 Tom van Dijk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -ex

SYLVAN_CMAKE_ARGS=${SYLVAN_CMAKE_ARGS:-}
SYLVAN_C_FLAGS_EXTRA=${SYLVAN_C_FLAGS_EXTRA:-}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"

GIT_REMOTE=$1
GIT_REVISION=$2

if [ -z "$GIT_REMOTE" ] || [ -z "$GIT_REVISION" ]; then
    echo "Usage: $0 <git-remote> <git-revision>"
    exit 1
fi

mkdir -p "$PROJECT_ROOT/target"
pushd "$PROJECT_ROOT/target"

echo "Downloading Sylvan from $GIT_REMOTE"

if [ ! -d "sylvan" ]; then
    git clone "$GIT_REMOTE" sylvan
fi

pushd sylvan
git fetch origin --tags

echo "Using revision $GIT_REVISION"
git checkout "$GIT_REVISION"

SYLVAN_SRC_ROOT="$(pwd)"
popd

#
# Build the native library.
#

mkdir -p sylvan-java-build
pushd sylvan-java-build

mkdir -p build
pushd build

SYLVAN_C_FLAGS="-Wno-error -Wno-error=array-parameter -Wno-error=calloc-transposed-args -Wno-array-parameter -Wno-calloc-transposed-args"
if [ -n "$SYLVAN_C_FLAGS_EXTRA" ]; then
    SYLVAN_C_FLAGS="$SYLVAN_C_FLAGS $SYLVAN_C_FLAGS_EXTRA"
fi

cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_C_FLAGS="$SYLVAN_C_FLAGS" \
    $SYLVAN_CMAKE_ARGS \
    "$SYLVAN_SRC_ROOT"
make sylvan
SYLVAN_BUILD_ROOT="$(pwd)"

popd

cmake -DUSE_NATIVE_JNI=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    "-DSYLVAN_SRC_ROOT=$SYLVAN_SRC_ROOT" "-DSYLVAN_BUILD_ROOT=$SYLVAN_BUILD_ROOT" \
    $SYLVAN_CMAKE_ARGS \
    "$PROJECT_ROOT/src/main/c/sylvan-java"
make sylvan-java

popd
popd

# Copy the built artifact for this platform.
case "$(uname -sm)" in
    "Linux x86_64")  LIBRARY_DIR=linux-x64 ;;
    "Darwin x86_64") LIBRARY_DIR=darwin-x64 ;;
    *)               LIBRARY_DIR="" ;;
esac

mkdir -p "$PROJECT_ROOT/src/main/resources/$LIBRARY_DIR"
cp "$PROJECT_ROOT/target/sylvan-java-build/lib"/libsylvan-java* "$PROJECT_ROOT/src/main/resources/$LIBRARY_DIR"
