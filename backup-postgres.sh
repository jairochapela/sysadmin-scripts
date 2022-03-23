#!/bin/bash

tmpdir="${TMPDIR:-/tmp}"
homedir="${HOME:-/root}"
bkpdir="/var/backup/postgres"

mkdir -p "$bkpdir"

for db in $* ; do

	dbbak="$bkpdir/$db.sql"

	lock=/var/run/databases-backup-process

	echo "Creando copia de seguridad de $db..."

	cd "$tmpdir"
	flock -n $lock sudo -u postgres pg_dump "$db" > "$dbbak"

	if [ -f "$dbbak" ] ; then
		gzip -f "$dbbak"
		chmod 600 "$dbbak.gz"
	else
		echo "Error creando copia de seguridad."
	fi
done
