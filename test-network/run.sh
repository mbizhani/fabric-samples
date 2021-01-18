./network.sh up createChannel

echo "##########################"
echo "####### CHAIN CODE #######"
echo "##########################"

./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go