#!/bin/bash
set -euo pipefail

# Variables (replace with your values or pass via pipeline environment)
CLUSTER_NAME="my-eks-cluster"
REGION="us-east-1"
NEW_VERSION="1.32"

echo "Checking current EKS cluster version..."
CURRENT_VERSION=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --query "cluster.version" \
  --output text)

echo "Current version: $CURRENT_VERSION"
echo "Target version: $NEW_VERSION"

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ]; then
  echo "Cluster is already at version $NEW_VERSION. No update needed."
  exit 0
fi

echo "Updating EKS cluster version..."
aws eks update-cluster-version \
  --name $CLUSTER_NAME \
  --region $REGION \
  --version $NEW_VERSION

echo "Waiting for cluster update to complete..."
aws eks wait cluster-active \
  --name $CLUSTER_NAME \
  --region $REGION

echo "Cluster successfully updated to version $NEW_VERSION!"
