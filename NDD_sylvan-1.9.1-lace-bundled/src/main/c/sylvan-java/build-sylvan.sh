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
LACE_GIT_REMOTE=${LACE_GIT_REMOTE:-https://github.com/trolando/lace.git}
LACE_GIT_TAG=${LACE_GIT_TAG:-}

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

BUNDLED_LACE_DIR="$PROJECT_ROOT/src/main/c/lace-bundled"
if [ -d "$BUNDLED_LACE_DIR" ]; then
    cp "$BUNDLED_LACE_DIR/lace.c" "$SYLVAN_SRC_ROOT/src/lace.c"
    cp "$BUNDLED_LACE_DIR/lace.h" "$SYLVAN_SRC_ROOT/src/lace.h"

    SYLVAN_SRC_ROOT="$SYLVAN_SRC_ROOT" python - <<'PY'
import os
import pathlib
import re

sylvan_root = pathlib.Path(os.environ["SYLVAN_SRC_ROOT"])

def update_file(path, transform):
    text = path.read_text()
    new_text = transform(text)
    if new_text != text:
        path.write_text(new_text)

def patch_top_level(text):
    text = re.sub(r"\\nif\\(NOT TARGET lace\\)[\\s\\S]*?endif\\(\\)\\n", "\\n", text, count=1)
    if "# Dependencies" in text:
        text = text.replace("# Dependencies\\n", "# Dependencies\\n# Lace bundled in-tree for this build.\\n", 1)
    return text

def patch_src_cmake(text):
    if "lace.h" not in text:
        text = text.replace("set(SYLVAN_HDRS\\n", "set(SYLVAN_HDRS\\n    lace.h\\n", 1)
    if "lace.c" not in text:
        text = text.replace("target_sources(sylvan\\n  PRIVATE\\n", "target_sources(sylvan\\n  PRIVATE\\n    lace.c\\n", 1)
    text = text.replace("target_link_libraries(sylvan PUBLIC lace::lace)\\n", "")
    text = text.replace('set(PKGC_REQUIRES "lace >= 1.4.2 gmp")', 'set(PKGC_REQUIRES "gmp")')
    text = text.replace('set(PKGC_REQUIRES "lace >= 1.4.2")', 'set(PKGC_REQUIRES "")')
    return text

def patch_lace_compat(text):
    if "sylvan_lace_is_worker" in text:
        return text
    insert = "#include <sylvan_int.h>\\n\\nstatic inline int sylvan_lace_is_worker(void) { return lace_get_worker() != NULL; }\\n\\n"
    return text.replace("#include <sylvan_int.h>\\n\\n", insert, 1)

def patch_lace_calls(text):
    return text.replace("lace_is_worker()", "sylvan_lace_is_worker()")

update_file(sylvan_root / "CMakeLists.txt", patch_top_level)
update_file(sylvan_root / "src" / "CMakeLists.txt", patch_src_cmake)
def patch_sylvan_h(text):
    if "define RUN" in text:
        text = text.replace("#define RUN(f, ...) CALL(f, ##__VA_ARGS__)",
                            "#define RUN(f, ...) ({ LACE_ME; CALL(f, ##__VA_ARGS__); })")
    if "SYLVAN_LACE_COMPAT" in text:
        return text
    needle = "#include <lace.h>\\n"
    insert = (
        "#include <lace.h>\\n"
        "\\n#ifndef SYLVAN_LACE_COMPAT\\n"
        "#define SYLVAN_LACE_COMPAT\\n"
        "#ifdef TOGETHER\\n"
        "#undef TOGETHER\\n"
        "#define TOGETHER(f, ...) ({ LACE_ME; WRAP(f##_TOGETHER, ##__VA_ARGS__); })\\n"
        "#endif\\n"
        "#endif\\n"
    )
    if needle in text:
        return text.replace(needle, insert, 1)
    return text

update_file(sylvan_root / "src" / "sylvan.h", patch_sylvan_h)
update_file(sylvan_root / "src" / "sylvan_mtbdd.c", lambda t: patch_lace_calls(patch_lace_compat(t)))
update_file(sylvan_root / "src" / "sylvan_ldd.c", lambda t: patch_lace_calls(patch_lace_compat(t)))
def patch_stdatomic_includes(text, marker):
    fixed = text.replace("\\n#include <stdatomic.h>", "\n#include <stdatomic.h>")
    fixed = fixed.replace("#include <stdatomic.h>\n#include <stdatomic.h>",
                          "#include <stdatomic.h>")
    if "<stdatomic.h>" not in fixed:
        fixed = fixed.replace(marker, f"{marker}\n#include <stdatomic.h>", 1)
    return fixed

update_file(
    sylvan_root / "src" / "sylvan_refs.c",
    lambda t: patch_stdatomic_includes(t, "#include <sylvan.h>"),
)
update_file(
    sylvan_root / "src" / "sylvan_sl.c",
    lambda t: patch_stdatomic_includes(t, "#include <sylvan.h>"),
)
PY
    perl -0777 -i -pe 's/#define RUN\(f, \.\.\.\) CALL\(f, ##__VA_ARGS__\)/#define RUN(f, ...) ({ LACE_ME; CALL(f, ##__VA_ARGS__); })/s' \
        "$SYLVAN_SRC_ROOT/src/sylvan.h"
    if ! grep -q "SYLVAN_LACE_COMPAT" "$SYLVAN_SRC_ROOT/src/sylvan.h"; then
        perl -0777 -i -pe 's/#include <lace\.h>\n/#include <lace.h>\n\n#ifndef SYLVAN_LACE_COMPAT\n#define SYLVAN_LACE_COMPAT\n#ifdef TOGETHER\n#undef TOGETHER\n#define TOGETHER(f, ...) ({ LACE_ME; WRAP(f##_TOGETHER, ##__VA_ARGS__); })\n#endif\n#endif\n/s' \
            "$SYLVAN_SRC_ROOT/src/sylvan.h"
    fi
    if ! grep -q "lace.h" "$SYLVAN_SRC_ROOT/src/CMakeLists.txt"; then
        perl -0777 -i -pe 's/set\(SYLVAN_HDRS\n/set(SYLVAN_HDRS\n    lace.h\n/s' \
            "$SYLVAN_SRC_ROOT/src/CMakeLists.txt"
    fi
    if ! grep -q "lace.c" "$SYLVAN_SRC_ROOT/src/CMakeLists.txt"; then
        perl -0777 -i -pe 's/target_sources\(sylvan\n  PRIVATE\n/target_sources(sylvan\n  PRIVATE\n    lace.c\n/s' \
            "$SYLVAN_SRC_ROOT/src/CMakeLists.txt"
    fi
    perl -0777 -i -pe 's/target_link_libraries\(sylvan PUBLIC lace::lace\)\n//s' \
        "$SYLVAN_SRC_ROOT/src/CMakeLists.txt"
    if ! grep -q "stdatomic.h" "$SYLVAN_SRC_ROOT/src/sylvan_int.h"; then
        perl -0777 -i -pe 's/#include <sylvan\.h>\n/#include <sylvan.h>\n#include <stdatomic.h>\n/s' \
            "$SYLVAN_SRC_ROOT/src/sylvan_int.h"
    fi
    SYLVAN_CMAKE_ARGS="$SYLVAN_CMAKE_ARGS -DSYLVAN_BUILD_TESTS=OFF -DSYLVAN_BUILD_EXAMPLES=OFF"
fi

if [ -n "$LACE_GIT_TAG" ]; then
    echo "Downloading Lace from $LACE_GIT_REMOTE"
    if [ ! -d "lace" ]; then
        git clone "$LACE_GIT_REMOTE" lace
    fi

    pushd lace
    git fetch origin --tags
    echo "Using Lace revision $LACE_GIT_TAG"
    git checkout "$LACE_GIT_TAG"
    LACE_SRC_ROOT="$(pwd)"
    popd

    SYLVAN_CMAKE_ARGS="$SYLVAN_CMAKE_ARGS -DFETCHCONTENT_SOURCE_DIR_LACE=$LACE_SRC_ROOT"
fi

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
