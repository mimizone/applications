#!/bin/bash
set -e
peers_fr1="10.1.1.10 10.1.1.11 10.1.1.12"
peers_fr2="10.2.1.10 10.2.1.11 10.2.1.12"
echo "Blueprint Kubernetes HA"
echo "-----------------------"
if [[ -z "$OS_PASSWORD" ]]
then
  cat <<EOF
  You must set OS_USERNAME / OS_PASSWORD / OS_TENANT_NAME / OS_AUTH_URL ...
  The simple way to do this is to follow theses instructions:

  - Bring your Cloudwatt credentials and go to this url : https://console.cloudwatt.com/project/access_and_security/api_access/openrc/
  - If you are not connected, fill your Cloudwatt username / password
  - A file suffixed by openrc.sh will be downloaded, once complete, type in your terminal :
    source COMPUTE-[...]-openrc.sh
EOF
  exit 1
fi

KEYPAIR="bigk8s"
# KEYS=$(nova keypair-list | egrep '\|.*' | tail -n +2 | cut -d' ' -f 2)
# echo "What is your keypair name ?"
# select KEYPAIR in ${KEYS}
# do
#  echo "Key selected: $KEYPAIR"
#  break;
# done

MONITORING="1"
# echo "Do you want to deploy Prometheus (monitoring) in your cluster ?"
# select MONITORING in yes no
# do
#  case "$MONITORING" in
#    yes) MONITORING="1" ;;
#    no)  MONITORING="0" ;;
#  esac
#  echo "Monitoring: $MONITORING"
#  break;
# done

MODE="Create"
# echo "Do you want to create a new cluster or join an existing one ?"
# select MODE in Create Join
# do
#   echo "Mode: $MODE"
#   break;
# done
# if [ "${MODE}" == "Join" ]
# then
#   read -p "Enter the peers(at least 3) Public IPs: " PEER
#   if [ "${PEER}" == "" ]; then echo "Peer cannot be empty"; exit 1; fi
# else
#   TOKEN=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
# fi

TOKEN=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
# read -p "Enter the secret token (default: $TOKEN): " TOKEN_C
# if [ "${TOKEN_C}" != "" ]; then TOKEN=${TOKEN_C}; fi
# if [ "$(echo -n ${TOKEN} | wc -c | sed 's/ //g')" != "16" ]; then echo "Token must be 16 alphanumeric characters"; exit 1; fi

NODE_COUNT=15
# read -p "Enter the number of nodes (default: $NODE_COUNT): " NODE_COUNT_C
# if [ "${NODE_COUNT_C}" != "" ]; then NODE_COUNT=${NODE_COUNT_C}; fi

STORAGE_COUNT=3
# read -p "Enter the number of storage nodes (default: $STORAGE_COUNT): " STORAGE_COUNT_C
# if [ "${STORAGE_COUNT_C}" != "" ]; then STORAGE_COUNT=${STORAGE_COUNT_C}; fi

NAME="kube"
# read -p "How do you want to name this stack : " NAME
# if [ "${NAME}" == "" ]; then echo "Name cannot be empty"; exit 1; fi

cat <<EOF
Openstack credentials :
Username: ${OS_USERNAME}
Password: *************
Tenant name: ${OS_TENANT_NAME}
Authentication url: ${OS_AUTH_URL}
Region: ${OS_REGION_NAME}
Keypair: ${KEYPAIR}
Mode: ${MODE}
Monitoring: ${MONITORING}
TOKEN: ${TOKEN}
K8 Nodes count: ${NODE_COUNT}
Storage Nodes count: ${STORAGE_COUNT}
NAME: ${NAME}
-----------------------
EOF


# heat stack-create -f stack-${OS_REGION_NAME}-cli.yml -P os_username=${OS_USERNAME} -P os_password=${OS_PASSWORD} -P os_auth_url=${OS_AUTH_URL} -P os_tenant_name=${OS_TENANT_NAME} -P node_count=${NODE_COUNT} -P storage_count=${STORAGE_COUNT} -P keypair_name=${KEYPAIR} -P token=${TOKEN} -P ceph=1 -P monitoring=${MONITORING} ${NAME}

echo "starting at" `date`

openstack stack create -f shell -t stack-${OS_REGION_NAME}-cli.yml \
--parameter os_username=${OS_USERNAME} \
--parameter os_password=${OS_PASSWORD} \
--parameter os_auth_url=${OS_AUTH_URL} \
--parameter os_tenant_name=${OS_TENANT_NAME} \
--parameter node_count=${NODE_COUNT} \
--parameter storage_count=${STORAGE_COUNT} \
--parameter keypair_name=${KEYPAIR} \
--parameter token=${TOKEN} \
--parameter ceph=1 \
--parameter monitoring=${MONITORING} ${NAME}

# if [ "${MODE}" == "Create" ]
# then
#   heat stack-create -f stack-${OS_REGION_NAME}-cli.yml -P os_username=${OS_USERNAME} -P os_password=${OS_PASSWORD} -P os_auth_url=${OS_AUTH_URL} -P os_tenant_name=${OS_TENANT_NAME} -P node_count=${NODE_COUNT} -P storage_count=${STORAGE_COUNT} -P keypair_name=${KEYPAIR} -P token=${TOKEN} -P ceph=1 -P monitoring=${MONITORING} ${NAME}
# else
#   var="peers_$OS_REGION_NAME"
#   INITIAL_PEERS=${!var}
#   heat stack-create -f stack-${OS_REGION_NAME}-cli.yml -P os_username=${OS_USERNAME} -P os_password=${OS_PASSWORD} -P os_auth_url=${OS_AUTH_URL} -P os_tenant_name=${OS_TENANT_NAME} -P node_count=${NODE_COUNT} -P storage_count=${STORAGE_COUNT} -P keypair_name=${KEYPAIR} -P token=${TOKEN} -P ceph=1 -P monitoring=${MONITORING} -P peer="$INITIAL_PEERS $PEER" ${NAME}
# fi

echo "type the following in another shell to follow the creation:"
echo "openstack stack event list --follow ${NAME}"
echo -n "Waiting for stack to be ready"
until openstack stack show ${NAME} 2> /dev/null | egrep 'CREATE_COMPLETE|CREATE_FAILED'
do
  echo -n "."
  sleep 10
done

if openstack stack show ${NAME} 2> /dev/null | grep CREATE_FAILED
then
  echo "Error while creating stack"
  exit 1
fi
echo "done at " `date`

for output in $(openstack stack output list ${NAME} 2> /dev/null | egrep '\|.*' | tail -n +2 | cut -d' ' -f 2)
do
  echo "$output: $(openstack stack output show ${NAME} ${output} 2> /dev/null)"
done
