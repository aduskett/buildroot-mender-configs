# Overview
This directory contains all necessary directories and files of which to use buildroot for professional products.

## Reasons for using containers to build
Containers provide the following:
  - A consistent build environment
  - Easy setup and onboarding
  - Reproducible builds
  - An all-in-one setup process.

## Directory structure
This directory has the following structure:
  - buildroot
    - A stock buildroot download found at [buildroot.org](https://buildroot.org/) 
  - docker
    - Contains two files:
      - env_file
        - This file contains the environment variable ENV_FILES. A colon deliminated list of environment files of which to use.
      - init
        - Automatically set's up the buildroot environment on startup and then runs /bin/bash to keep the docker container running if exit_after_build is set to False in the last environment file in the ENV_FILES variable.
  - external
    - The external directory contains several directories used for persistent storage purposes.
        - board:
          - Board specific files and directories.
        - configs:
          - Buildroot defconfig files. During the initialization process, the docker init script loops through this directory and applies each config to external/output.
        - dl:
          - This directory contains all downloaded source packages used in the above configs in a compressed format.
        - output:
          - The init-script applies each config file found in external/configs to output/config_name, and then the source code is built in that directory.
        - package:
          - Any external packages not in stock Buildroot go here.
        - production:
          - Once built, production images go here.
  - scripts
    - Various scripts used for development purposes.

## Prerequisites:
- A computer running macOS, Linux, or Windows with WSL2
- Docker
- Python3
- docker-compose
- 10 - 20GB of free space.

## Setup
  - First, set the ENV_FILES in docker/env to what is appropriate for the build.
  - Second, set the env.json file to what is appropriate for the build.
    By default, the environment variables automatically apply all config files found in external/configs but does not auto-build them.
  - run `docker-compose build`

## Building
If auto-building:
  - run `docker-compose up`

If manually-building:
  - run `docker-compose up -d && && docker exec -ti buildroot-devel-build /bin/bash`
  - Then navigate to `/home/br-user/buildroot/` and build manually. If `build` is set to true
    in the environment json file, then the output directory is automatically created in the defined external tree.
    The default for the included example env.json file creates the directory external/output

# Customizations

## Changing the buildroot user name
  - Edit the user variable in the docker/env.json and docker-compose.yml files.

## Changing the buildroot UID and GID
  - The default UID and GID for the buildroot user is 1000, however you may customize the default by either:
    - modifying the docker-compose.yml file directly.
    - passing the UID and GID directly from the command line. IE: `docker-compose build --build-arg UID=$(id -u $(whoami)) --build-arg GID=$(id -g $(whoami))`

## Changing the buildroot directory name
  - Edit the buildroot_dir_name variable in the docker/env.json and docker-compose.yml files.

## Adding patches to buildroot
  - Add a directory to the BUILDROOT_PATCH_DIR argument in the docker-compose.yml file.
    Patches are automatically copied and applied to buildroot when `docker-compose build` is ran.

## Adding additional external trees
  - Add additional external trees by copying the external directory to a new directory and adding the new directories name to the
    EXTERNAL_TREES variable in the docker-compose.yml file and the external_trees variable for a given config in the environment json file.
    Note: The docker-compose.yml variable is space deliminated, the json file variable is colon deliminated.

## Changing the Buildroot version
  - Edit the BUILDROOT_VERSION argument in the docker-compose.yml file
  - run `docker-compose build`
  Note: If you have a BUILDROOT_PATCH_DIR defined, watch for failures during the build process to ensure that all patches applied cleanly!

# Using the packages without docker:

- clone or download buildroot from: https://buildroot.org/
- clone or download and extract this repository: `git clone git@github.com:aduskett/buildroot-docker-devel.git`
- copy the external tree  to the buildroot directory: `cp buildroot-docker-devel/example-buildroot-project/external ./exteranl`
- apply the config with the external tree: `BR2_EXTERNAL=./external make $your_defconfig`
- Add or remove packages with `make menuconfig`
- Build the project with `make`

For more information about using and building with Buildroot, see: https://buildroot.org/downloads/manual/manual.html

## Further reading
Please check [The Buildroot manual](https://buildroot.org/downloads/manual/manual.html) for more information.
