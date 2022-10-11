#!/bin/sh

echo "gitea-adm: --== post-install ==--"

# Environment variables
GITEA_VERSION=$(cat $APKG_PKG_DIR/gitea_version)
GITEA_DATA_PATH='/share/Docker/Gitea'
GITEA_CONFIG_PATH='/gitea/conf'
GITEA_CONTAINER=Gitea
GITEA_UID=999
GITEA_GID=999

# Checking the configuration to install according to the user's settings
if [ -d ${GITEA_DATA_PATH}${GITEA_CONFIG_PATH} ]; then
  cd ${GITEA_DATA_PATH}${GITEA_CONFIG_PATH} || exit 1

  # Backing configuration
  if [ "$APKG_PKG_STATUS" = 'upgrade' ]; then
    # Saving the configuration
    echo "gitea-adm: Saving configuration (app.ini.old)..."
    cp app.ini app.ini.old
  fi

  # Integrity check
  echo "gitea-adm: Integrity check-up for users of the old version of gitea by iGi"
  if [ $(cat app.ini | grep RUN_USER | awk '{print $3}') != 'git' ]; then
    sed -i 's/\(RUN_USER =\).*/RUN_USER = git/' app.ini
    chown -R $GITEA_UID:$GITEA_GID ../../../Gitea
  fi
fi

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
  --env USER_UID=$GITEA_UID \
  --env USER_GID=$GITEA_GID \
  --restart=unless-stopped \
  --volume $GITEA_DATA_PATH:/data \
  --volume /usr/builtin/etc/certificate/:/ssl/:ro \
  gitea/gitea:$GITEA_VERSION

echo "gitea-adm: Installation/Update complete"

# Starting container
echo "gitea-adm: Starting container"
docker start $GITEA_CONTAINER

exit 0