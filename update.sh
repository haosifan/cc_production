#!/bin/bash

echo "test" >> /home/epvoteadmin/cc_production/test.txt

git add .
git commit -m "autocommit"
git push origin main
