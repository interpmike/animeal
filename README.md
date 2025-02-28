# Animeal iOS
### A project to help volunteers feed stray animals


## About the application
The app helps you search and locate animals that need feed feeding. A user can sign in with a mobile number / Facebook / Apple account.

## Usage
Xcode: 14+
SDK: iOS 15+
SPM: Yes
Architecture: MVVM + Flow Coordinator


## Tech Stack
1. UIKit / SwiftUI / Combine
2. Swift Package Manager
3. XCTest

## List of 3rd party SDK's
1. MapBOX
2. AWS Amplify
3. Sorcery
4. Quick and Nimble
5. CocoaLumberjackSwift
6. Firebase
7. Kingfisher


## Style guide
Raywenderlich Swift Style Guide https://github.com/raywenderlich/swift-style-guide

## Color Naming
https://colors.artyclick.com/color-name-finder/

## Steps for onboarding
1. This app uses Mabbox SDK. Please follow the steps from here. https://docs.mapbox.com/ios/maps/guides/install/
2. This project uses AWS Amplify. Please use the `update_amplify.sh` script to run and generate the source code files. Further read here: https://docs.amplify.aws/cli/start/install/
Note: 
1. for API keys and other secret please connect with one of our group members.
2. for first time on boarding guys in case the `update_amplify.sh` script failes. Please run the `recover_from_error.sh`

## Generate the string file

We needed to convert the certificate and provisioning profile to base 64 string format so that it can be used in the github actions secrets. Hence we used the following commands to convert the files to base 64 format.

openssl base64 -in dev-certificates.p12 -A | tr -d '\n' > dev-certificates_base64.txt
openssl base64 -in Animeal_Development_latest.mobileprovision -A | tr -d '\n' > Animeal_Development_latest_base64.txt
