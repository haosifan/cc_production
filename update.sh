#!/bin/bash

echo "Hi, it is now $(date)" >> /home/ubuntu/cc_production/log.txt

cd /home/ubuntu/cc_production/
git add .
git commit -m "autocommit"
git push origin main
