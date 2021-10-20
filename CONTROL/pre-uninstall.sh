#!/bin/sh

echo "Gitea Uninstall: pre-uninstall"

# Environement variables
GITEA_DATA_PATH="/volume1/Docker/Gitea"
GITEA_VERSION=$(cat $APKG_PKG_DIR/gitea_version)
GITEA_CONTAINER=$(docker container ls -a | grep Gitea | awk '{print $1}')

# Force shutdown of the container and delete the image
echo "Gitea Uninstall: stoping and removing container"
echo "    - $GITEA_CONTAINER"
if [ ! -z $GITEA_CONTAINER ]; then 
  docker kill $GITEA_CONTAINER
  sleep 2
  docker rm -f $GITEA_CONTAINER
fi

case "$APKG_PKG_STATUS" in
  uninstall)
    GITEA_IMAGE=$(docker images | grep gitea/gitea | grep $GITEA_VERSION | awk '{print $3}')
    # REMOVE docker image on uninstalling
    echo "Gitea Uninstall: removing docker image"
    echo "    - $GITEA_IMAGE"
    if [ ! -z $GITEA_IMAGE ]; then 
      docker rmi -f $GITEA_IMAGE
    fi
    ;;
  *)
    ;;
esac

exit 0