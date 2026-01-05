#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYLVAN_REMOTE="https://github.com/trolando/sylvan.git"
LACE_REMOTE="https://github.com/trolando/lace.git"

VARIANT_BUNDLED="NDD_sylvan-1.4.1-lace-bundled"
VARIANT_LACE="NDD_sylvan-1.8.1-lace-1.4.2"
VARIANT_LACE_150="NDD_sylvan-1.9.1-lace-1.5.0"
VARIANT_LACE_151="NDD_sylvan-1.9.1-lace-1.5.1"
VARIANT_LATEST="NDD_sylvan-1.9.1-lace-2.0.3"
VARIANT_BUNDLED_191="NDD_sylvan-1.9.1-lace-bundled"
SYLVAN_BUNDLED_TAG="v1.4.1"
SYLVAN_LACE_TAG="v1.8.1"
SYLVAN_LATEST_TAG="v1.9.1"
LACE_150_TAG="v1.5.0"
LACE_151_TAG="v1.5.1"
LACE_LATEST_TAG="v2.0.3"

clean=1
gmp="off"
mmap="on"
mode="all"

for arg in "$@"; do
  case "$arg" in
    --no-clean)
      clean=0
      ;;
    --gmp=on|--gmp=off)
      gmp="${arg#*=}"
      ;;
    --mmap=on|--mmap=off)
      mmap="${arg#*=}"
      ;;
    all|bundled|lace|lace150|lace151|latest|bundled191)
      mode="$arg"
      ;;
    *)
      echo "Usage: $0 [--no-clean] [--gmp=on|off] [--mmap=on|off] {all|bundled|lace|lace150|lace151|latest|bundled191}" >&2
      exit 1
      ;;
  esac
done

gmp_flag="$(echo "$gmp" | tr '[:lower:]' '[:upper:]')"
mmap_flag="$(echo "$mmap" | tr '[:lower:]' '[:upper:]')"

build_variant() {
  local dir="$1"
  local tag="$2"
  local lace_tag="${3:-}"
  local cflags_extra="${4:-}"

  cd "$REPO_ROOT/$dir"
  if [[ "$clean" -eq 1 ]]; then
    rm -rf target
  fi
  LACE_GIT_REMOTE="$LACE_REMOTE" \
  LACE_GIT_TAG="$lace_tag" \
  SYLVAN_C_FLAGS_EXTRA="$cflags_extra" \
  SYLVAN_CMAKE_ARGS="-DSYLVAN_USE_MMAP=${mmap_flag} -DSYLVAN_GMP=${gmp_flag} -DSYLVAN_ENABLE_PIC=ON" \
    src/main/c/sylvan-java/build-sylvan.sh "$SYLVAN_REMOTE" "$tag"
  mvn package
}

case "$mode" in
    all)
    build_variant "$VARIANT_BUNDLED" "$SYLVAN_BUNDLED_TAG"
    build_variant "$VARIANT_LACE" "$SYLVAN_LACE_TAG"
    build_variant "$VARIANT_LACE_150" "$SYLVAN_LATEST_TAG" "$LACE_150_TAG"
    build_variant "$VARIANT_LACE_151" "$SYLVAN_LATEST_TAG" "$LACE_151_TAG" "-DLINE_SIZE=64"
    ;;
  bundled)
    build_variant "$VARIANT_BUNDLED" "$SYLVAN_BUNDLED_TAG"
    ;;
  lace)
    build_variant "$VARIANT_LACE" "$SYLVAN_LACE_TAG"
    ;;
  lace150)
    build_variant "$VARIANT_LACE_150" "$SYLVAN_LATEST_TAG" "$LACE_150_TAG"
    ;;
  lace151)
    build_variant "$VARIANT_LACE_151" "$SYLVAN_LATEST_TAG" "$LACE_151_TAG" "-DLINE_SIZE=64"
    ;;
  latest)
    build_variant "$VARIANT_LATEST" "$SYLVAN_LATEST_TAG" "$LACE_LATEST_TAG"
    ;;
  bundled191)
    build_variant "$VARIANT_BUNDLED_191" "$SYLVAN_LATEST_TAG"
    ;;
  *)
    echo "Usage: $0 [--no-clean] {all|bundled|lace|lace150|lace151|latest|bundled191}" >&2
    exit 1
    ;;
esac
