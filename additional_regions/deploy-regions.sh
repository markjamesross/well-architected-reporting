#! /bin/bash
set -euo pipefail
terraform init

for ACTION_OUTPUT in $(cat regions.txt); do

  if [[ ${ACTION_OUTPUT} != "#"* ]]; then

  echo "*****************************"
  echo "Processing ${ACTION_OUTPUT}"
  echo "*****************************"
  export TF_VAR_region=${ACTION_OUTPUT}
  terraform apply -auto-approve -state=tfstate/${ACTION_OUTPUT}-terraform.tfstate
  fi

done