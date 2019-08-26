# Arch Pipeline

## Build

The script build.sh generate a new base tarball

- remove old images
- create new build image, ripx80/archbuild
- build the base system with build/buildBase.sh, create artefacts/archbase.tar.bz2
- create ripx80/archbase image

## How to use

```bash
./build.sh # generate a tarball in base and import as ripx80/archbase
cd web
./serve.sh # start a simple webserver to serve the tar

# start your server with sysres or over pxe and download from server prepare.sh
./prepare.sh
reboot
```

## Roadmap

- add basedesk with postprepare script to create a desktop system (not working at the moment)
- add travis pipeline to generate a docker image and save it on dockerhub
- add a desc how to boot with pxe and serve the tarball for auto installs

## Bugs

- Not working with normal bios systems, only with uefi
