#!/bin/bash
echo "Deleting Database deployment."
kubectl delete deployment.apps/account-database
echo "Deleting Database service."
kubectl delete service/account-database

echo "Deleting Compute interest deployment."
kubectl delete deployment.apps/compute-interest-api
echo "Deleting Compute interest service."
kubectl delete service/compute-interest-api

echo "Deleting Account summary deployment."
kubectl delete deployment.apps/account-summary 
echo "Deleting Account summary service."
kubectl delete service/account-summary

echo "Deleting Transaction generator deployment."
kubectl delete deployment.apps/transaction-generator
echo "Deleting Transaction generator service."
kubectl delete service/transaction-generator
echo "Finish!!"