#!/bin/sh

WORKDIR=$(pwd)
BUILD="ripx80/archbuild:latest"
BASE="ripx80/archbase:latest"
DESK="ripx80/archdesk:latest"

echo "remove old images and artefacts"

if [ "$(ls -A $WORKDIR/artefacts)" ]; then
    rm $WORKDIR/artefacts/*
fi

if [[ "$(docker images -q $BUILD 2> /dev/null)" != "" ]]; then
  docker rmi $BUILD
fi

if [[ "$(docker images -q $BASE 2> /dev/null)" != "" ]]; then
  docker rmi $BASE
fi

if [[ "$(docker images -q $DESK 2> /dev/null)" != "" ]]; then
  docker rmi $DESK
fi

echo "build all stage images"

cd build
docker build -t ripx80/archbuild:latest .
docker run --rm -it -v $WORKDIR/artefacts:/artefacts --privileged ripx80/archbuild:latest
docker import $WORKDIR/artefacts/archbase.tar.gz ripx80/archbase:latest
cd $WORKDIR

cp artefacts/archbase.tar.gz web/
mv artefacts/archbase.tar.gz base/


#cd basedesk
#cd $WORKDIR

exit 0