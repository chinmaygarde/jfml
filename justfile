# This project uses CMake and Git sub-modules. This justfile is just in place
# to make common tasks easier.

gen:
    mkdir -p build
    cmake -G Ninja -B build -DJFML_BUILD_TESTING=ON

build: gen
    cmake --build build

test: build
    ctest --test-dir build --output-on-failure

clean:
    rm -rf build

sync:
    git submodule update --init --recursive -j 8
