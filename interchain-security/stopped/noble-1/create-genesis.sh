#!/bin/bash
gaiad query provider consumer-genesis noble-1 -o json | jq . > ccv.json
jq -s '.[0].app_state.ccvconsumer = .[1] | .[0]' noble-1-genesis-without-ccv.json ccv.json > noble-1-genesis.json
rm ccv.json
sha256sum noble-1-genesis.json
