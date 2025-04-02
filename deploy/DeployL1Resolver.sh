#!/bin/bash
source .env

forge build --force

forge script scripts/DeployL1Resolver.s.sol:DeployL1Resolver \
    --slow \
    --multi \
    --broadcast \
    --interactives 1 \
    -vvvv

