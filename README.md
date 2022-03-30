# Scripts de administración de sistemas

## Gestión de bases de datos

### Postgres

Se recomienda instalar `pgcli` y `pspg`.

### MySQL/MariaDB

Se recomienda instalar `mycli` y `pspg`.

## Scripts de backup

En `backup-borg.sh` debe configurarse el repositorio y la clave de cifrado en el propio script.

### Configuración de cron

```
10 1 * * * /usr/local/sbin/backup-postgres.sh postgres bd1 bd2
30 3 * * * /usr/local/sbin/backup-borg.sh /home /etc/apache2 /srv/storage /var/backup/postgres
```

