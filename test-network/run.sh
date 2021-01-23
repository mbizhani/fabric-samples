#!/bin/bash

# ./network.sh up createChannel

echo "##########################"
echo "####### CHAIN CODE #######"
echo "##########################"

## Internal
#./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go

## External
source .env
pushd ../asset-transfer-basic/chaincode-external
tar cvfz code.tar.gz connection.json
tar cvfz asset-transfer-basic-external.tgz metadata.json code.tar.gz

GOPRX=${GOPROXY}
if [ ! "${GOPRX}" ]; then
  GOPRX="https://gonexus.dev/"
fi
echo "*** GOPROXY = ${GOPRX}"
docker image prune --filter label=stage=build -f
docker rmi asset-transfer-basic || true
docker build \
  --build-arg GOPROXY=${GOPRX} \
  -t asset-transfer-basic .
popd

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
source ./scripts/envVar.sh
CC_NAME="basic"
CC_VERSION="1.0"
CC_INIT_FCN="InitLedger"
INIT_REQUIRED="--init-required"

setGlobals 1
peer lifecycle chaincode install \
  ../asset-transfer-basic/chaincode-external/asset-transfer-basic-external.tgz
echo "Install 1: $?"

setGlobals 2
peer lifecycle chaincode install \
  ../asset-transfer-basic/chaincode-external/asset-transfer-basic-external.tgz
echo "Install 2: $?"

setGlobals 1
peer lifecycle chaincode queryinstalled \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt >&log.txt
cat log.txt
PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
echo "PACKAGE_ID = ${PACKAGE_ID}"
if [ ! "${PACKAGE_ID}" ]; then
  echo "ERROR: no PACKAGE_ID"
  exit 1
fi

EXT_CC_ADDR="asset-transfer-basic.org1.example.com"

echo "CHAINCODE_SERVER_ADDRESS=${EXT_CC_ADDR}:9999" > cc.env
echo "CHAINCODE_ID=${PACKAGE_ID}" >> cc.env

docker run -d --rm \
  --name ${EXT_CC_ADDR} \
  --hostname ${EXT_CC_ADDR} \
  --env-file cc.env \
  --network=net_test asset-transfer-basic

sleep 2
setGlobals 1
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID mychannel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id "${PACKAGE_ID}" \
  --sequence 1 ${INIT_REQUIRED}
echo "Approve Org1: $?"

sleep 2
setGlobals 2
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID mychannel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --package-id "${PACKAGE_ID}" \
  --sequence 1 ${INIT_REQUIRED}
echo "Approve Org2: $?"

sleep 2
peer lifecycle chaincode commit \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
  --channelID mychannel \
  --name ${CC_NAME} \
  --version ${CC_VERSION} \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  --sequence 1 ${INIT_REQUIRED}
echo "Commit: $?"

if [ "${CC_INIT_FCN}" ]; then
  sleep 2
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  #TIP: just needs one of the peers!!!
  peer chaincode invoke \
    -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    --channelID mychannel \
    --name ${CC_NAME} \
    --peerAddresses localhost:7051 \
    --tlsRootCertFiles $PWD/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    --isInit -c ${fcn_call}
  echo "Invoke Init: $?"
fi