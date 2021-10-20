#!/bin/sh

# Environement variables
GITEA_CONTAINER=Gitea

case "$1" in
  start)
    # Starting gitea
    echo "Gitea Start: Starting service..."
    docker start $GITEA_CONTAINER
    sleep 3
    ;;
  stop)
    # Stopping gitea
    echo "Gitea Stop: Stopping service..."
    docker stop $GITEA_CONTAINER
    sleep 3
    ;;
  relaod)
    # Reloading gitea
    echo "Gitea Reload: Reloading service..."
    docker stop $GITEA_CONTAINER
    sleep 6
    docker start $GITEA_CONTAINER
    sleep 3
    ;;
  *)
    echo "usage: $0 {start|stop|reload}"
    exit 1
    ;;
esac

exit 0