#!/bin/bash
# This script is used to fix the alpine version in the Dockerfile.

DOCKERFILE=${1:-"Dockerfile"}

echo "Building Dockerfile: $DOCKERFILE"

BUILD_OUTPUT=$(docker build --progress plain -f "$DOCKERFILE" . 2>&1)
BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo "The build succeeded."
    exit 0
fi

if ! echo "$BUILD_OUTPUT" | grep -q "ERROR: unable to select packages"; then
    echo "The build is not failed due to version update."
    echo "$BUILD_OUTPUT"
    exit 1
fi

# Extract broken package names. Expected variable value is:
#   ca-certificates
#   curl
# Extract broken package names.
# shellcheck disable=SC2207
BROKEN_PACKAGES=($(echo "$BUILD_OUTPUT" | awk -F '[][]' '/breaks: world\[[^]]*\]/{print $2}' | sed 's/=.*//g'))

# Loop through each broken package and find the latest version from BUILD_OUTPUT
declare -a PACKAGES
for pkg in "${BROKEN_PACKAGES[@]}"; do
    # If the variable $pkg is empty, then skip the loop.
    if [ -z "$pkg" ]; then
        continue
    fi

    version=$(echo "$BUILD_OUTPUT" | grep " $pkg-" | grep -v '\[' | awk '{print $3}' | sed 's/:$//' | sed "s/$pkg-//" | head -n1)
    # Add the package name and version to the PACKAGES array
    PACKAGES+=("$pkg $version")
done

# If the variable PACKAGES is empty array, then exit with error message.
if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "The script cannot find any packages to fix."
    echo "$BUILD_OUTPUT"
    exit 1
fi

# Get Dockerfile content
DOCKERFILE_CONTENT=$(cat "$DOCKERFILE")

# Loop through the PACKAGES array and replace the version in the Dockerfile
for package in "${PACKAGES[@]}"; do
    NAME=$(echo "$package" | cut -d' ' -f1)
    VERSION=$(echo "$package" | cut -d' ' -f2)
    echo "Updating $NAME to the version $VERSION."

    pkg_declaration=$(cat Dockerfile |grep -o -e $NAME=[^[:space:]]*)
    pkg_v_var=${pkg_declaration#*=*}

    if [[ "$pkg_v_var" =~ \"\$\{?([a-zA-Z0-9_-]*)\}?\" ]]; then
      # The captured group (the variable name) is stored in the BASH_REMATCH array at index 1
      pkg_v_var="${BASH_REMATCH[1]}"
    fi

    # shellcheck disable=SC2001
    DOCKERFILE_CONTENT=$(echo "$DOCKERFILE_CONTENT" | sed "s/$pkg_v_var=.*$/$pkg_v_var=$VERSION/")

done

echo "Replacing the content of $DOCKERFILE with updated Dockerfile."
echo "$DOCKERFILE_CONTENT" >"$DOCKERFILE"

echo "Updated. Here is the diff."
git diff "$DOCKERFILE"
