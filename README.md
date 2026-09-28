# AWS-IoT-Core-For-LoRaWAN

Python scripts for working with AWS IoT Core for LoRaWAN.

A small collection of helper scripts (Python with boto3, plus one Bash script that uses the
AWS CLI) and an AWS IoT rule statement. They look up wireless devices and gateways, register a
new LoRaWAN gateway together with its LoRa Basics Station credential files, create a Network
Analyzer configuration, and decode uplink payloads through an AWS Lambda function.

The scripts are templates: most values (AWS profile, identifiers, ARNs) are empty or
placeholders that you fill in before running.

## Table of Contents

- [Repository Contents](#repository-contents)
- [Requirements](#requirements)
- [Usage](#usage)
  - [Get Device Info](#get-device-info)
  - [Get Gateway Info](#get-gateway-info)
  - [Add a Gateway](#add-a-gateway)
  - [Create a Network Analyzer Configuration](#create-a-network-analyzer-configuration)
  - [Message Decoding IoT Rule](#message-decoding-iot-rule)
- [Required IAM Permissions](#required-iam-permissions)
- [Security Notes](#security-notes)
- [Contributing](#contributing)
- [License](#license)

## Repository Contents

| Path | Type | Purpose |
|------|------|---------|
| [`Devices/get_device_info.py`](Devices/get_device_info.py) | Python (boto3) | Look up a wireless device by its DevEUI and print its AWS wireless device ID. |
| [`Gateways/get_gateway_info.py`](Gateways/get_gateway_info.py) | Python (boto3) | Look up a wireless gateway by its Gateway EUI and print the full API response. |
| [`Gateways/Ad Gateway/add_gw.sh`](Gateways/Ad%20Gateway/add_gw.sh) | Bash (AWS CLI) | Create a LoRaWAN gateway, create and associate its certificate, and download the CUPS/LNS endpoint and trust files. |
| [`Network Analyzer/create_network_analyzer.py`](Network%20Analyzer/create_network_analyzer.py) | Python (boto3) | Create a Network Analyzer configuration for a list of devices and gateways. |
| [`Message Decoding/Iot rule statement`](Message%20Decoding/Iot%20rule%20statement) | AWS IoT SQL | Rule statement that sends LoRaWAN uplinks to a Lambda decoder. |

## Requirements

- An AWS account with AWS IoT Core for LoRaWAN available in your region.
- AWS credentials configured as a named profile (for example with `aws configure --profile <name>`).
- **Python scripts:** Python 3 with [`boto3`](https://pypi.org/project/boto3/) and
  [`loguru`](https://pypi.org/project/loguru/) (`loguru` is imported by every script, so it must
  be installed even though it is not used for output):

  ```bash
  pip install boto3 loguru
  ```

  <!-- TODO: verify minimum Python version (not declared anywhere in the repo) -->
- **Gateway script:** Bash, the [AWS CLI](https://aws.amazon.com/cli/) with the `iotwireless`
  commands, and [`jq`](https://jqlang.github.io/jq/).

## Usage

All Python scripts create a boto3 session with `region_name='eu-west-1'` and an empty
`profile_name=''`. Before running any of them, edit the `boto3.Session(...)` line: set
`profile_name` to your AWS profile and change `region_name` if your resources are not in
`eu-west-1`.

### Get Device Info

[`Devices/get_device_info.py`](Devices/get_device_info.py) calls
`iotwireless.get_wireless_device` with `IdentifierType='DevEui'`.

1. Set `Identifier=''` to the device's DevEUI.
2. Run:

   ```bash
   python Devices/get_device_info.py
   ```

The script prints the wireless device ID (`response["Id"]`), which is the ID the other AWS APIs
(and the Network Analyzer script) expect.

### Get Gateway Info

[`Gateways/get_gateway_info.py`](Gateways/get_gateway_info.py) calls
`iotwireless.get_wireless_gateway` with `IdentifierType='GatewayEui'`.

1. Set `Identifier=''` to the gateway's EUI.
2. Run:

   ```bash
   python Gateways/get_gateway_info.py
   ```

The script prints the full API response.

### Add a Gateway

[`Gateways/Ad Gateway/add_gw.sh`](Gateways/Ad%20Gateway/add_gw.sh) registers a new LoRaWAN
gateway and prepares the files a LoRa Basics Station gateway needs to connect to AWS IoT Core
for LoRaWAN.

Before running it, replace every `[profile_name]` placeholder in the script with your AWS
profile name.

```bash
cd "Gateways/Ad Gateway"
bash add_gw.sh
```

The script prompts for:

| Prompt | Used as |
|--------|---------|
| GW EUI | `GatewayEui`, and the name of the output directory |
| RF Region | `RfRegion` (for example `EU868` or `US915`) |
| GW Name | Gateway name |
| GW Description | Gateway description |
| AWS Region | `--region` for every AWS CLI call |

It then runs these steps:

1. Deletes the directory named after the Gateway EUI if it already exists, and recreates it.
2. `aws iotwireless create-wireless-gateway` creates the gateway and captures its ID.
   **Known issue:** on line 23, `MaxEirp=7` is separated from the `--lorawan` value by a space
   instead of a comma, so the AWS CLI is expected to reject it as an unknown option. Fix that line
   before running. <!-- TODO: verify -->
3. `aws iot create-keys-and-certificate --set-as-active` creates an active certificate and key
   pair, saved as `cups.crt` / `cups.key` and copied to `tc.crt` / `tc.key`.
4. `aws iotwireless associate-wireless-gateway-with-certificate` links the certificate to the
   gateway.
5. `aws iotwireless get-service-endpoint` is called for the `CUPS` and `LNS` service types to
   save the server trust certificates (`cups.trust`, `tc.trust`) and endpoint URIs
   (`cups.uri`, `tc.uri`).

Resulting files in `<GATEWAY_EUI>/`:

| File | Content |
|------|---------|
| `cups.crt`, `tc.crt` | Gateway certificate |
| `cups.key`, `tc.key` | Gateway private key |
| `cups.trust` | CUPS server trust certificate |
| `tc.trust` | LNS server trust certificate |
| `cups.uri` | CUPS service endpoint |
| `tc.uri` | LNS service endpoint |

Copy these files to your gateway's Basics Station configuration.

### Create a Network Analyzer Configuration

[`Network Analyzer/create_network_analyzer.py`](Network%20Analyzer/create_network_analyzer.py)
calls `iotwireless.create_network_analyzer_configuration` with:

- `Name='AutoGenerated_with_script'`
- `Description='Test script for NA creation'`
- `TraceContent`: `WirelessDeviceFrameInfo` set to `ENABLED`, `LogLevel` set to `INFO`
- `WirelessDevices` and `WirelessGateways`: lists of wireless device and gateway IDs

The ID lists in the script are example values from the author's account. Replace them with your
own wireless device IDs and gateway IDs (you can get a device ID with
[Get Device Info](#get-device-info)), and change the name and description if needed. Then run:

```bash
python "Network Analyzer/create_network_analyzer.py"
```

The script does not print anything; check the result in the AWS IoT console or with the AWS CLI.

### Message Decoding IoT Rule

[`Message Decoding/Iot rule statement`](Message%20Decoding/Iot%20rule%20statement) is an AWS IoT
SQL statement for a rule that decodes LoRaWAN uplinks with a Lambda function:

```sql
SELECT aws_lambda("arn:aws:lambda:[Full lambda arn]",
                  {"PayloadData":PayloadData,
                  "WirelessDeviceId": WirelessDeviceId,
                   "WirelessMetadata": WirelessMetadata,"DECODER_NAME": topic()}) as transformed_payload,
        timestamp() as timestamp
```

It calls the Lambda function with:

- `PayloadData`: the uplink payload
- `WirelessDeviceId`: the ID of the device that sent it
- `WirelessMetadata`: the LoRaWAN metadata of the uplink
- `DECODER_NAME`: the value of `topic()` (the MQTT topic of the incoming message), presumably used by the Lambda to pick a decoder
  <!-- TODO: verify how DECODER_NAME / topic() is set up; the Lambda decoder is not part of this repo -->

The rule outputs the Lambda's return value as `transformed_payload`, plus a `timestamp`.

To use it, replace `[Full lambda arn]` with the rest of your Lambda function's ARN and use the
statement in the IoT rule that your LoRaWAN destination sends uplinks to. The decoder Lambda
itself is not included in this repository.

## Required IAM Permissions

Only the actions that the scripts actually call:

| Script | Actions |
|--------|---------|
| `get_device_info.py` | `iotwireless:GetWirelessDevice` |
| `get_gateway_info.py` | `iotwireless:GetWirelessGateway` |
| `add_gw.sh` | `iotwireless:CreateWirelessGateway`, `iot:CreateKeysAndCertificate`, `iotwireless:AssociateWirelessGatewayWithCertificate`, `iotwireless:GetServiceEndpoint` |
| `create_network_analyzer.py` | `iotwireless:CreateNetworkAnalyzerConfiguration` |

For the IoT rule, AWS IoT must be allowed to invoke the Lambda function
(`lambda:InvokeFunction`).

## Security Notes

- Never commit AWS credentials. The scripts read credentials from a named AWS profile; keep
  them in `~/.aws/`, not in the scripts.
- `add_gw.sh` writes the gateway's **private key** (`cups.key`, `tc.key`) to disk in plain text.
  Keep the output directory private and do not commit it.
- `add_gw.sh` runs `rm -Rf` on any existing directory named after the Gateway EUI before
  recreating it, so earlier files for that gateway are lost.
- The Network Analyzer script contains device and gateway IDs from the author's account.
  Replace them before use.

## Contributing

Issues and pull requests are welcome.

## License

No license file is included in this repository.
