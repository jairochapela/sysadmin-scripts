#!/bin/bash

hostname=$(hostname)

export BORG_REPO="ssh://uuuuuu@backup-server.xyz:23/~/$hostname.borg"
export BORG_PASSPHRASE='xxxxxxxxxxxxxxxxxxxxxxxxxx'

borg create --stats -C lz4 --exclude-caches ::`date +%Y%m%d%H%M` $*
borg prune --list --show-rc --keep-daily 7 --keep-weekly 4 --keep-monthly 6
#borg compact


