all: install

install:
	install ansible-manager.sh maria-databases.sh postgres-databases.sh /usr/local/bin

.PHONY: all install