#!/bin/bash

tmpdir="${TMPDIR:-/tmp}"
homedir="${HOME:-/root}"
bkpdir="/var/backup/mariadb"

mkdir -p "$bkpdir"

for db in $* ; do

	dbbak="$bkpdir/$db.sql"

	lock=/var/run/backup-mariadb-process

	echo "Creando copia de seguridad de $db..."

	cd "$tmpdir"
	flock -n $lock sudo mysqldump "$db" > "$dbbak"

	if [ -f "$dbbak" ] ; then
		gzip -f "$dbbak"
		chmod 600 "$dbbak.gz"
	else
		echo "Error creando copia de seguridad."
	fi
done
