#!/bin/bash

aws ec2 import-key-pair \
  --key-name "bcitkey" \
  --public-key-material fileb:///home/ubuntu/bcitkey.pub \
  --region us-west-2
