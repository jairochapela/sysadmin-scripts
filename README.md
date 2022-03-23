# Scripts de administración de sistemas



## Scripts de backup

En `backup-borg.sh` debe configurarse el repositorio y la clave de cifrado en el propio script.

### Configuración de cron

```
10 1 * * * /usr/local/sbin/backup-postgres.sh postgres bd1 bd2
30 3 * * * /usr/local/sbin/backup-borg.sh /home /etc/apache2 /srv/storage /var/backup/postgres
```

