#!/bin/bash
source .env

forge build --force

forge script scripts/DeployL1TrustlessResolver.s.sol:DeployL1TrustlessResolver \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

