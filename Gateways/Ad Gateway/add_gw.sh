#!/bin/bash  

#Get User input

echo "Please enteer GW EUI:"
read GATEWAY_EUI
echo "Please enter RF Region:"
read RF_REGION
echo "Please enter GW Name:"
read GW_NAME
echo "Please enter GW Description:"
read GW_DESCRIPTION
echo "Please enter AWS Region:"
read  AWS_REGION


#Create Directory for the GW files
if [ -d "$GATEWAY_EUI" ]; then rm -Rf $GATEWAY_EUI; fi
mkdir $GATEWAY_EUI


#Create the GW
GATEWAY_ID=$(aws --profile [profile_name] iotwireless create-wireless-gateway --name "$GW_NAME"  --description "$GW_DESCRIPTION" --lorawan GatewayEui=$GATEWAY_EUI,RfRegion=$RF_REGION MaxEirp=7 --region $AWS_REGION | jq -r .Id)
echo "Created gateway with id $GATEWAY_ID"

#Create Certificates
CERTIFICATE_ID=$(aws  --profile [profile_name] iot create-keys-and-certificate --set-as-active --certificate-pem-outfile $GATEWAY_EUI/cups.crt --private-key-outfile  $GATEWAY_EUI/cups.key --region $AWS_REGION | jq -r .certificateId)
cp $GATEWAY_EUI/cups.key $GATEWAY_EUI/tc.key
cp  $GATEWAY_EUI/cups.crt  $GATEWAY_EUI/tc.crt
echo "Created certificate with id $CERTIFICATE_ID"

#Associate gateway with the certificate
aws --profile [profile_name] iotwireless  associate-wireless-gateway-with-certificate --id $GATEWAY_ID --iot-certificate-id $CERTIFICATE_ID --region $AWS_REGION


#Pull trust certificates
aws --profile [profile_name] iotwireless get-service-endpoint --service-type CUPS --region $AWS_REGION  | jq -r .ServerTrust > $GATEWAY_EUI/cups.trust
aws --profile [profile_name] iotwireless get-service-endpoint --service-type LNS --region $AWS_REGION | jq -r .ServerTrust > $GATEWAY_EUI/tc.trust

#Create URI files
aws --profile [profile_name] iotwireless get-service-endpoint --service-type CUPS --region $AWS_REGION | jq -r .ServiceEndpoint > $GATEWAY_EUI/cups.uri 
aws --profile [profile_name] iotwireless get-service-endpoint --service-type LNS --region $AWS_REGION | jq -r .ServiceEndpoint > $GATEWAY_EUI/tc.uri 



