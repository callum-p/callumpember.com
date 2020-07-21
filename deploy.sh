#!/bin/sh -e

docker-compose run --rm build

aws s3 cp ./_site/ s3://callumpember.com/ --recursive
aws cloudfront create-invalidation --distribution-id E20KVYOK8HW59W --paths '/*'
