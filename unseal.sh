#!/bin/bash

VAULT_ADDRESSES=("172.18.100.100" "172.18.100.101" "172.18.100.102")
OTHER_VAULT_ADDRESSES=("${VAULT_ADDRESSES[@]/$VAULT_ADDRESSES[0]}")
CERTS_FOLDER=./certs
CONFIGS_FOLDER=./configs
CA_CN="VaultClusterCA"

UNSEAL_INFO_FILE="unseal-info.json"

function unseal_vault {

  local unseal_info
	
  if [ ! -f $UNSEAL_INFO_FILE ];
  then
    vault operator init -format=json > $UNSEAL_INFO_FILE
  fi
  
  unseal_info=$(cat $UNSEAL_INFO_FILE)
  unseal_threshold=$(echo $unseal_info | jq -r '.unseal_threshold')
  
  echo $unseal_info | jq -r '.unseal_keys_b64[]' | head -n $unseal_threshold | while read key;
  do 
    vault operator unseal $key
  done

  echo "Vault unsealed.... the unseal info IS in $UNSEAL_INFO_FILE file"  
} 

for vault_server in ${VAULT_ADDRESSES[@]}; do

    export VAULT_ADDR=https://${vault_server}:8200
    export VAULT_CACERT=${CERTS_FOLDER}/${CA_CN}.pem

    vault status 1>/dev/null

    # TODO: change to /v1/sys/health?!
    # 200 if initialized, unsealed, and active
    # 429 if unsealed and standby
    # 472 if disaster recovery mode replication secondary and active
    # 473 if performance standby
    # 501 if not initialized
    # 503 if sealed

    case $? in

    "0")
        echo "Already unsealed! move on... BTW: the unseal info SHOULD be in $UNSEAL_INFO_FILE file"
        ;;

    "1")
        echo "Some error in the vault instance... exiting unseal process!"
        exit 1
        ;;

    "2")   
        unseal_vault
        echo "Espera um pouco pela replicacao ..."
        sleep 2s    
        ;;

    *)
        echo "What?! (response was: $?)"
        ;;
    esac

done