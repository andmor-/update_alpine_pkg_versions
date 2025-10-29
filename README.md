# update_alpine_pkg_versions

This script automates the process of fixing broken Alpine package versions in a Dockerfile by extracting the latest versions from the build output.
The versions are updated on ARG and ENV variables declared to specify the package versions according to: https://docs.docker.com/build/building/best-practices/#env

(based on: https://gist.github.com/chrisleekr/28ecc960f223778a13d349a582c67df6)
