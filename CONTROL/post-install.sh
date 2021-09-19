#!/bin/sh

echo "Gitea Install: post-install"

# Environement variables
GITEA_DATA_PATH="/volume1/Docker/Gitea"
GITEA_CONTAINER=Gitea

# Pull the container image
echo "Gitea Install: fetching data"
docker pull gitea/gitea:latest

# Installing creating container
echo "Gitea Install: creating container"
docker create -i -t --name=$GITEA_CONTAINER \
  --publish 3022:22 --publish 3000:3000 \
  --env GITEA__server__PROTOCOL='https' \
  --env GITEA__server__ROOT_URL='https://localhost:3000' \
  --env GITEA__server__CERT_FILE='/ssl/ssl.crt' \
  --env GITEA__server__KEY_FILE='/ssl/ssl.key' \
  --restart=unless-stopped \
  --volume $GITEA_DATA_PATH:/data \
  --volume /usr/builtin/etc/certificate/:/ssl/:ro \
  gitea/gitea:latest

# Starting container
echo "Gitea Install: strating container"
docker start $GITEA_CONTAINER

case "$APKG_PKG_STATUS" in
  upgrade)
    GITEA_IMAGE=$(docker images | grep gitea/gitea | grep none | awk '{print $3}')
    # REMOVE old docker image on UPGRADE
    echo "Gitea Upgrade: removing old docker image"
    echo "    - $GITEA_IMAGE"
    if [ ! -z $GITEA_IMAGE ]; then 
      docker rmi -f $GITEA_IMAGE
    fi
    ;;
  *)
    ;;
esac

exit 0
