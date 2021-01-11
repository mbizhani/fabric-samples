./network.sh up createChannel -ca -verbose

echo "##########################"
echo "####### CHAIN CODE #######"
echo "##########################"

./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-javascript -ccl javascript