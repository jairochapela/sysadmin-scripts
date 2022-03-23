all: install

install:
	install ansible-manager.sh maria-databases.sh postgres-databases.sh /usr/local/bin
	install backup-borg.sh backup-postgres.sh /usr/local/sbin

.PHONY: all install