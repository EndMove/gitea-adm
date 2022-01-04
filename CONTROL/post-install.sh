#!/bin/sh

echo "gitea-adm: --== post-install ==--"

# Environement variables
GITEA_DATA_PATH="/volume1/Docker/Gitea"
GITEA_CONTAINER=Gitea
GITEA_VERSION=$(cat $APKG_PKG_DIR/gitea_version)

# Pull the container image
echo "gitea-adm: Fetching data"
docker pull gitea/gitea:$GITEA_VERSION

# Installing creating container
echo "gitea-adm: Creating container"
docker create -i -t --name=$GITEA_CONTAINER \
  --publish 3122:22 --publish 3100:3000 \
  --env GITEA__server__PROTOCOL='https' \
  --env GITEA__server__CERT_FILE='/ssl/ssl.crt' \
  --env GITEA__server__KEY_FILE='/ssl/ssl.key' \
  --env USER_UID=1000 \
  --env USER_GID=1000 \
  --restart=unless-stopped \
  --volume $GITEA_DATA_PATH:/data \
  --volume /usr/builtin/etc/certificate/:/ssl/:ro \
  gitea/gitea:$GITEA_VERSION

# Starting container
echo "gitea-adm: Strating container"
docker start $GITEA_CONTAINER

# Say update is done
if [ "$APKG_PKG_STATUS" == "upgrade" ]; then
  echo "gitea-adm: Upgrade done"
fi

exit 0
