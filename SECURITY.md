# Security

## Reporting a Security Vulnerability

To report a security vulnerability, please send an email to `security[at]hudik.eu`. Please provide detailed information about the vulnerability and steps to reproduce it. We appreciate your cooperation in allowing us to investigate and address the issue promptly.

## What is in scope

This app performs every cryptographic operation on the device. The server it talks to only ever receives ciphertext. Anything that breaks that property is the most serious class of bug this repository can have, including:

- Plaintext file content, file names, thumbnails, or search terms leaving the device
- The decrypted private key being written to disk, logged, or exposed to another process
- The PIN or biometric lock being bypassed to reach decrypted data
- Weaknesses in how file keys are wrapped for another account or for a public link
- The embedded MCP server exposing storage without the bearer token, or while the app is locked

The cryptographic primitives themselves live in the `cryptfns` and `transfer` crates in the [hoodik](https://github.com/hudikhq/hoodik) repository. Report issues in those there, or here if you are unsure which applies.

## Responsible Disclosure Guidelines

We kindly request that you adhere to the following guidelines when reporting security vulnerabilities:

1. **Provide Sufficient Details**: When reporting a vulnerability, please include enough information for us to understand and reproduce the issue. This may include steps to reproduce, proof-of-concept code, screenshots, or any other relevant information.

2. **Do Not Exploit the Vulnerability**: We request that you do not attempt to exploit the vulnerability beyond what is necessary to demonstrate the existence of the issue.

3. **Keep Information Confidential**: Please do not share or disclose any information about the vulnerability or its details with anyone else, except the Hoodik security team. We will keep all information confidential until an agreed-upon date for disclosure.

4. **Allow Sufficient Time to Respond**: We strive to respond to security reports promptly. Please provide us with a reasonable amount of time to investigate and fix the vulnerability before disclosing it publicly.

5. **Follow Responsible Disclosure**: We appreciate your cooperation in following responsible disclosure practices. We will acknowledge your contribution and mention your name (if desired) once the vulnerability is resolved, with your permission.

Thank you for helping us make Hoodik a safer and more secure platform. Your contributions play a vital role in ensuring the privacy and protection of our users' data.
