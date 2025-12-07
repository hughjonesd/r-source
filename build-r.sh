#!/bin/bash
set -e

echo "=== Building R from source ==="

# Get the source directory (where this script is located)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SOURCE_DIR}/build"

# Step 1: Download recommended packages
echo "Step 1: Downloading recommended packages..."
cd "${SOURCE_DIR}"
./tools/rsync-recommended

# Step 2: Regenerate gram.c if gram.y is newer
echo "Step 2: Checking if gram.c needs regeneration..."
if [ src/main/gram.y -nt src/main/gram.c ] || [ ! -f src/main/gram.c ]; then
    echo "gram.y is newer than gram.c or gram.c missing - regenerating with bison..."
    # Use homebrew bison if available (system bison 2.3 is too old)
    if [ -f /opt/homebrew/opt/bison/bin/bison ]; then
        BISON=/opt/homebrew/opt/bison/bin/bison
    else
        echo "Warning: Using system bison - may not work if too old"
        BISON=bison
    fi
    cd "${SOURCE_DIR}/src/main"
    $BISON -y -l gram.y -o gram.c
    cd "${SOURCE_DIR}"
else
    echo "gram.c is up to date"
fi

# Step 3: Create and configure in build directory
echo "Step 3: Creating build directory and running configure..."
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"
CPPFLAGS="-I/opt/homebrew/opt/xz/include -I/opt/homebrew/opt/pcre2/include" \
LDFLAGS="-L/opt/homebrew/opt/xz/lib -L/opt/homebrew/opt/pcre2/lib" \
"${SOURCE_DIR}/configure"

# Step 4: Apply SVN workaround (after configure, before make)
echo "Step 4: Applying SVN workaround..."
cd "${BUILD_DIR}"
(cd doc/manual && make front-matter html-non-svn)
cd "${SOURCE_DIR}"
# Create SVNINFO file for make to read
echo -n 'Revision: ' > SVNINFO
git log --format=%B -n 1 | grep "^git-svn-id" | sed -E 's/.*@([0-9]+).*$/\1/' >> SVNINFO
echo >> SVNINFO
echo -n 'Last Changed Date: ' >> SVNINFO
git log -1 --pretty=format:"%ad" --date=iso | cut -d' ' -f1 >> SVNINFO

# Step 5: Build R
echo "Step 5: Building R..."
cd "${BUILD_DIR}"
make

echo "=== Build complete ==="
echo "R has been built in ${BUILD_DIR}"
echo "R binary: ${BUILD_DIR}/bin/R"
echo "To rebuild after changes: cd build && make"
echo "To clean: cd build && make clean"
