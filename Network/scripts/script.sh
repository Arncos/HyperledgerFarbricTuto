#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build your first network (BYFN) end-to-end test"
echo
CHANNEL_NAME1="$1"
CHANNEL_NAME2="$2"
DELAY="$3"
LANGUAGE="$4"
TIMEOUT="$5"
CHANNEL_NAME_Orderer_2="$6"
: ${CHANNEL_NAME1:="channel1"}
: ${CHANNEL_NAME2:="channel2"}
: ${DELAY:="3"}
: ${LANGUAGE:="golang"}
: ${TIMEOUT:="10"}
: ${CHANNEL_NAME_Orderer_2:="channel"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/mydomain.com/orderers/orderer.mydomain.com/msp/tlscacerts/tlsca.mydomain.com-cert.pem
ORDERER2_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/accenture.com/orderers/orderer.accenture.com/msp/tlscacerts/tlsca.accenture.com-cert.pem

CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "$LANGUAGE" = "node" ]; then
	CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi

echo "Channel orderer.accenture.com name : "$CHANNEL_NAME_Orderer_2
echo "Channel1 name : "$CHANNEL_NAME1
echo "Channel2 name : "$CHANNEL_NAME2

# import utils
. scripts/utils.sh

createChannel() {
	setGlobals 0 1

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer.mydomain.com:7050 -c $CHANNEL_NAME1 -f ./channel-artifacts/channel1.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer.mydomain.com:7050 -c $CHANNEL_NAME1 -f ./channel-artifacts/channel1.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME1\" is created successfully ===================== "

	echo
		if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer.mydomain.com:7050 -c $CHANNEL_NAME2 -f ./channel-artifacts/channel2.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer.mydomain.com:7050 -c $CHANNEL_NAME2 -f ./channel-artifacts/channel2.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME2\" is created successfully ===================== "
	echo

}
createChannel_Orderer_2() {
	setGlobals 0 3

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer.accenture.com:7050 -c $CHANNEL_NAME_Orderer_2 -f ./channel-artifacts/orderer.accenture.com/channel.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer.accenture.com:7050 -c $CHANNEL_NAME_Orderer_2 -f ./channel-artifacts/orderer.accenture.com/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER2_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME_Orderer_2\" is created successfully ===================== "

}

joinChannel () {
    #for 2 peer
	for org in  2; do
	    for peer in 0 1 ; do
		joinChannel1WithRetry $peer $org
		echo "===================== peer${peer}.org${org} joined on the channel \"$CHANNEL_NAME1\" ===================== "
		sleep $DELAY
		echo
	    done
	done
    joinChannel1WithRetry 0 1
    echo "===================== peer0.org1 joined on the channel \"$CHANNEL_NAME1\" ===================== "
    joinChannel2WithRetry 1 1
    echo "===================== peer1.org1 joined on the channel \"$CHANNEL_NAME2\" ===================== "

	#for 3 peers
	for org in 3; do
	    for peer in 0 1 2 ; do
		joinChannel2WithRetry $peer $org
		echo "===================== peer${peer}.org${org} joined on the channel \"$CHANNEL_NAME2\" ===================== "
		sleep $DELAY
		echo
	    done
	done
}
joinChannelOrderer2 () {
    #for 2 peer
	for org in 2 3; do
	    for peer in 0 1 ; do
		joinChannelOrderer2WithRetry $peer $org
		echo "===================== peer${peer}.org${org} joined on the channel \"$CHANNEL_NAME_Orderer_2\" ===================== "
		sleep $DELAY
		echo
	    done
	done
	joinChannelOrderer2WithRetry 2 3
    echo "===================== peer2.org3 joined on the channel \"$CHANNEL_NAME_Orderer_2\" ===================== "
}
## Create channel
echo "Creating channel..."
createChannel
createChannel_Orderer_2


## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1 channel1..."
updateAnchorPeers 0 1 $CHANNEL_NAME1
echo "Updating anchor peers for org2 channel1..."
updateAnchorPeers 0 2 $CHANNEL_NAME1
echo "Updating anchor peers for org3 channel2..."
updateAnchorPeers 0 3 $CHANNEL_NAME2
echo "Updating anchor peers for org1 channel2..."
updateAnchorPeersAgain 1 1 $CHANNEL_NAME2
echo "Updating anchor peers for org1 channel1..."
updateAnchorPeersOrderer2 1 3 $CHANNEL_NAME_Orderer_2
echo "Updating anchor peers for org2 channel1..."
updateAnchorPeersOrderer2 1 2 $CHANNEL_NAME_Orderer_2

## Join all the peers to the channel

echo "Having all peers join the channel..."
joinChannel
joinChannelOrderer2

## Install chaincode on peer0.org1 and peer0.org2
echo "Installing chaincode on peer0.org1..."
installChaincode 0 1
echo "Installing chaincode on peer0.org1..."
installChaincode 1 1
echo "Install chaincode on peer0.org2..."
installChaincode 0 2
echo "Install chaincode on peer0.org2..."
installChaincode 1 2
echo "Install chaincode on peer0.org3..."
installChaincode 0 3
echo "Installing chaincode on peer2.org3..."
installChaincode 1 3
echo "Installing chaincode on peer1.org2..."
installChaincode 2 3

# Instantiate chaincode on peer0.org2

echo "Instantiating chaincode on peer0.org1..."
instantiateChaincode 0 2 $CHANNEL_NAME1
echo "Instantiating chaincode on peer1.org1..."
instantiateChaincode 1 1 $CHANNEL_NAME2
echo "Instantiating chaincode on peer1.org1..."
instantiateChaincodeOrderer2 1 2 $CHANNEL_NAME_Orderer_2

# Query chaincode on peer0.org1
echo "Querying chaincode on peer0.org1..."
chaincodeQuery 0 1 100 $CHANNEL_NAME1

# Invoke chaincode on peer0.org1
echo "Sending invoke transaction on peer0.org1..."
chaincodeInvoke 0 1 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org1... 90"
chaincodeQuery 0 1 90 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org2... 90"
chaincodeQuery 0 2 90 $CHANNEL_NAME1
# Invoke chaincode on peer0.org2
echo "Sending invoke transaction on peer0.org2..."
chaincodeInvoke 0 1 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org2... Querying chaincode on peer0.org1... 80"
chaincodeQuery 0 1 80 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org2... Querying chaincode on peer0.org2... 80"
chaincodeQuery 0 2 80 $CHANNEL_NAME1

echo "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"

chaincodeQuery 1 1 100 $CHANNEL_NAME2


# Invoke chaincode on peer1.org1
echo "Sending invoke transaction on peer0.org3..."
chaincodeInvoke 0 3 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org1... 90"
chaincodeQuery 1 1 90 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org2... 90"
chaincodeQuery 0 3 90 $CHANNEL_NAME2
# Invoke chaincode on peer0.org1
echo "Sending invoke transaction on peer0.org1..."
chaincodeInvoke 1 1 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org1... 80"
chaincodeQuery 1 1 80 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org2... 80"
chaincodeQuery 0 3 80 $CHANNEL_NAME2

echo "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"

# Invoke chaincode on peer0.org1
echo "Sending invoke transaction on peer0.org1..."
chaincodeInvoke 0 1 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org1... 70"
chaincodeQuery 0 1 70 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org2... 70"
chaincodeQuery 0 2 70 $CHANNEL_NAME1
# Invoke chaincode on peer0.org2
echo "Sending invoke transaction on peer0.org2..."
chaincodeInvoke 0 2 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org2... Querying chaincode on peer0.org1...60"
chaincodeQuery 0 1 60 $CHANNEL_NAME1
echo " Sent invoke transaction on peer0.org2... Querying chaincode on peer0.org2... 60"
chaincodeQuery 0 2 60 $CHANNEL_NAME1

echo "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"

# Invoke chaincode on peer1.org1
echo "Sending invoke transaction on peer0.org1..."
chaincodeInvoke 1 1 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer1.org1... 70"
chaincodeQuery 1 1 70 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org3... 70"
chaincodeQuery 0 3 70 $CHANNEL_NAME2
# Invoke chaincode on peer0.org1
echo "Sending in8rj zzvoke transaction on peer0.org1..."
chaincodeInvoke 0 3 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer1.org1... 60"
chaincodeQuery 1 1 60 $CHANNEL_NAME2
echo " Sent invoke transaction on peer0.org1... Querying chaincode on peer0.org3... 60"
chaincodeQuery 0 3 60 $CHANNEL_NAME2


echo
echo " _____   _____   ____   "
echo "|_____| |   __| |  _ \  "
echo "  | |   |  |__  | | | | "
echo "  | |   |  |__  | |_| | "
echo "  |_|   |_____| |____/  "
echo

chaincodeQuery 0 3 100 $CHANNEL_NAME_Orderer_2


echo
echo "========= All GOOD, BYFN execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
