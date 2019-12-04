#!/bin/bash
kubectl logs -f deployment/$1 --all-containers=true --since=10m