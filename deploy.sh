#!/bin/sh -e

# Accept AWS profile as parameter, default to "personal"
AWS_PROFILE="${1:-personal}"

docker-compose run --rm build

aws s3 cp ./_site/ s3://callumpember.com/ --recursive --profile "$AWS_PROFILE"
aws cloudfront create-invalidation --distribution-id E20KVYOK8HW59W --paths '/*' --profile "$AWS_PROFILE"
