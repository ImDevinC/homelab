#!/bin/zsh

newfolder=$(mktemp -d)
git clone git@github.com:k8up-io/k8up.git "${newfolder}"
cp ${newfolder}/config/crd/apiextensions.k8s.io/v1/* ./crds/
rm -rf ${newfolder}
