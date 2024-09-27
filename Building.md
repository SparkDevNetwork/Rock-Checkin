To perform a build, update the version number and build number and push that commit to the repo then use the github action to build. If that fails with a signing issue then it is probably time to upload a new provisioning profile and certificate.

Create the certificate and provisioning provile per Apple's normal steps. The provisioning profile downloaded form Apple should be base-64 encoded and then stored in the BUILD_PROVISION_PROFILE_BASE64 secret.

The signed certificate must be imported into KeyChain access, and then exported along with the private key into a .p12 format. Base-64 encode this p12 file and store it in the BUILD_CERTIFICATE_BASE64 secret. The password for the p12 file should be stored in the P12_PASSWORD secret.

The IPA can be downloaded from the action assets and then uploaded to Apple via Transporter.
