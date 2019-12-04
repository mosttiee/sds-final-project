#!/bin/bash
echo "Database.."
kubectl create -f account-database.yaml
sleep 5
echo "Compute interest"
kubectl apply -f compute-interest-api.yaml
sleep 5
echo "Transaction generator"
kubectl apply -f transaction-generator.yaml
sleep 5
echo "Account summary"
kubectl apply -f account-summary.yaml
echo "Finish!!"