#!/bin/bash

VAULT_NETWORK_CIDR="172.18.100.0/24"
VAULT_NETWORK_GATEWAY="172.18.100.1"
VAULT_ADDRESSES=("172.18.100.100" "172.18.100.101" "172.18.100.102")
CERTS_FOLDER=./certs
CONFIGS_FOLDER=./configs


CA_CN="VaultClusterCA"

./clean.sh

if [ ! -d "${CERTS_FOLDER}" ]
then  
  mkdir ${CERTS_FOLDER}
fi

if [ ! -d "${CONFIGS_FOLDER}" ]
then  
  mkdir ${CONFIGS_FOLDER}
fi

./gen-vault-ca.sh $CA_CN ${CERTS_FOLDER}


# Gerar as configurações dos agents vault
for i in ${!VAULT_ADDRESSES[@]}; do
  ./gen-vault-cert.sh $CA_CN "VaultNode-${i}" ${VAULT_ADDRESSES[$i]} ${CERTS_FOLDER}

cat <<EOF > ${CONFIGS_FOLDER}/vaultnode-${i}-config.hcl
ui = true
disable_mlock = true

cluster_addr = "https://${VAULT_ADDRESSES[$i]}:8201"
api_addr = "https://${VAULT_ADDRESSES[$i]}:8200"

listener "tcp" {
    address            = "127.0.0.1:8200"
    tls_disable        = false
    tls_cert_file      = "/vault/tls/VaultNode-${i}.pem"
    tls_key_file       = "/vault/tls/VaultNode-${i}-key.pem"
    tls_client_ca_file = "/vault/tls/${CA_CN}.pem"
    telemetry {
        unauthenticated_metrics_access = true
    }
}

listener "tcp" {
    address            = "${VAULT_ADDRESSES[$i]}:8200"
    tls_disable        = false
    tls_cert_file      = "/vault/tls/VaultNode-${i}.pem"
    tls_key_file       = "/vault/tls/VaultNode-${i}-key.pem"
    tls_client_ca_file = "/vault/tls/${CA_CN}.pem"
    telemetry {
        unauthenticated_metrics_access = true
    }
}

telemetry {
    prometheus_retention_time = "30s"
    disable_hostname = true
}
storage "raft" {
  path    = "/tmp"
  node_id = "VaultNode-${i}"
EOF

for nodeidx in ${!VAULT_ADDRESSES[@]}; do
    if [ $VAULT_ADDRESSES[$nodeidx] != $VAULT_ADDRESSES[$i] ]
    then
cat <<EOF >> ${CONFIGS_FOLDER}/vaultnode-${i}-config.hcl
  retry_join {
    leader_api_addr = "https://${VAULT_ADDRESSES[$nodeidx]}:8200"
    leader_tls_servername = "VaultNode-${nodeidx}"
    leader_ca_cert_file = "/vault/tls/${CA_CN}.pem"
    leader_client_cert_file = "/vault/tls/VaultNode-${nodeidx}.pem"
    leader_client_key_file = "/vault/tls/VaultNode-${nodeidx}-key.pem"
  }
EOF
    fi
done

cat <<EOF >> ${CONFIGS_FOLDER}/vaultnode-${i}-config.hcl
}
EOF

done

# gerar o ficheiro docker-compose
cat <<EOF > docker-compose.yaml
version: "3.8"
networks:
  vault-network:
    driver: bridge  
    ipam:
      config:
        - subnet: ${VAULT_NETWORK_CIDR}
          gateway: ${VAULT_NETWORK_GATEWAY}
EOF

cat <<EOF >> docker-compose.yaml
services:
EOF

for i in ${!VAULT_ADDRESSES[@]}; do

cat <<EOF >> docker-compose.yaml
  vaultnode-${i}:
    image: hashicorp/vault:latest
EOF

if [ $i -eq 0 ]
then
cat <<EOF >> docker-compose.yaml
    ports:
      - "8200:8200"
EOF
fi

cat <<EOF >> docker-compose.yaml
    volumes:
      - ${CERTS_FOLDER}:/vault/tls
      - ${CONFIGS_FOLDER}:/vault/config
    cap_add:
      - IPC_LOCK
    networks:
      vault-network:
        ipv4_address: ${VAULT_ADDRESSES[$i]}
        aliases:
          - vaultnode-${i}
    entrypoint: vault server -config=/vault/config/vaultnode-${i}-config.hcl      
EOF

done
