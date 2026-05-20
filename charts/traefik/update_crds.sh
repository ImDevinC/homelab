#!/bin/zsh

helm repo add traefik https://traefik.github.io/charts
helm repo update
rm -rf crds/*
helm show crds traefik/traefik >> crds/crds.yaml
