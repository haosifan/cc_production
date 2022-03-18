#!/bin/bash

echo "test" >> /home/epvoteadmin/cc_production/test.txt

cd /home/epvoteadmin/cc_production/
git add .
git commit -m "autocommit"
git push origin main
