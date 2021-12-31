#!/bin/bash

LND_DIR="/mnt/ext/lnd"

ADMIN_MACAROON="data/chain/bitcoin/mainnet/admin.macaroon"
TLS_CERT="tls.cert"
FILES=( $ADMIN_MACAROON $TLS_CERT )

for FILENAME in "${FILES[@]}"
do
	sudo cp $LND_DIR/$FILENAME $FILENAME
	sudo chown lndadmin: $FILENAME
done

