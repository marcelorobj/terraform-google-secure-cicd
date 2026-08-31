#!/bin/bash

set -e

# This script runs terraform apply with auto-approval.

cd examples/mortgage-agent
terraform apply -auto-approve tfplan
