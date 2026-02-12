#!/bin/bash
set -euo pipefail

# Variables (usually injected via pipeline environment/secrets)
CLUSTER_NAME="${CLUSTER_NAME:-my-eks-cluster}"
REGION="${REGION:-us-east-1}"
NEW_VERSION="${NEW_VERSION:-1.29}"

echo "[INFO] Checking current EKS cluster version..."
CURRENT_VERSION=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "cluster.version" \
  --output text)

echo "[INFO] Current version: $CURRENT_VERSION"
echo "[INFO] Target version: $NEW_VERSION"

if [ "$CURRENT_VERSION" == "$NEW_VERSION" ]; then
  echo "[INFO] Cluster is already at version $NEW_VERSION. Skipping upgrade."
  exit 0
fi

echo "[INFO] Starting cluster upgrade..."
aws eks update-cluster-version \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --version "$NEW_VERSION"

echo "[INFO] Waiting for cluster to become active..."
aws eks wait cluster-active \
  --name "$CLUSTER_NAME" \
  --region "$REGION"

echo "[SUCCESS] Control plane upgraded to $NEW_VERSION"

# --- Upgrade managed node groups ---
echo "[INFO] Fetching node groups..."
NODEGROUPS=$(aws eks list-nodegroups \
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query "nodegroups[]" \
  --output text)

for ng in $NODEGROUPS; do
  echo "[INFO] Upgrading node group: $ng"
  aws eks update-nodegroup-version \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$ng" \
    --kubernetes-version "$NEW_VERSION"

  echo "[INFO] Waiting for node group $ng to update..."
  aws eks wait nodegroup-active \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodegroup-name "$ng"
done

echo "[SUCCESS] All node groups upgraded to $NEW_VERSION"

# --- Upgrade core add-ons ---
for addon in kube-proxy vpc-cni coredns; do
  echo "[INFO] Updating addon: $addon"
  aws eks update-addon \
    --cluster-name "$CLUSTER_NAME" \
    --region "$REGION" \
    --addon-name "$addon" \
    --resolve-conflicts OVERWRITE || true
done

echo "[SUCCESS] Cluster, node groups, and add-ons upgraded to $NEW_VERSION"
