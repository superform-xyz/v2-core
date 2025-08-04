# Security Policy
This section outlines the security policy and known issues of the superform v2 core protocol.

## Known Issues
The protocol has a few accepted risks that are acknowledged and should be handled accordingly by integrators and users.

#### 1. Cross-Bridge Replay Attack
This is a low-likelihood vulnerability where a user may get their signed bridging intent executed on the destination chain even after it has been cancelled on the source chain.

**Prerequisites:** 

The user must still have sufficient balance on their smart account on the destination chain.

