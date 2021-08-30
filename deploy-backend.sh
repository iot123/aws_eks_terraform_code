#!/bin/bash
sleep 60
export workspace="$1"
export env="$2"
export domain="$3"
export nfs_url="nfs.$3"
export aws_acm_arn="$4"
export dockerhub_username="$5"
export dockerhub_password="$6"

kubectl --kubeconfig ./kubeconfig* get nodes

    if [ $? -eq 0 ]; then
        echo "Cluster is Ready"
    else
        exit 0
    fi
mkdir temp
echo "Applying predefined namespaces"
kubectl --kubeconfig ./kubeconfig* apply -f backend/namespaces/namespaces.yaml
sleep 5
echo "Applying NFS provisioner and creating pv-pvc volumes"
envsubst < backend/nfs-provisioner/nfs-provisioner.yaml > temp/tmp_file
cat temp/tmp_file > temp/nfs-provisioner.yaml
kubectl --kubeconfig ./kubeconfig* apply -f temp/nfs-provisioner.yaml -nkube-system
sleep 10
#kubectl --kubeconfig ./kubeconfig* apply -f backend/nfs-provisioner/test-pvc.yaml -nnanoprecise
sleep 5
#kubectl --kubeconfig ./kubeconfig* get pvc -nnanoprecise

echo "Applying cluster Autoscalar to eks cluster 1.19"
envsubst < backend/autoscalar/cluster-autoscaler-autodiscover.yaml > temp/tmp_file
cat temp/tmp_file > temp/cluster-autoscaler-autodiscover.yaml
kubectl --kubeconfig ./kubeconfig* apply -f temp/cluster-autoscaler-autodiscover.yaml

echo "Applying Metric-server for aggregation of resource usage data in your cluster"
kubectl --kubeconfig ./kubeconfig* apply -f backend/metric/metric-server/metric-server.yaml

echo "Applying cadvisor for aggregation of resource usage and performance characteristics of their running containers."
kubectl --kubeconfig ./kubeconfig* apply -f backend/metric/cadvisor/cadvisor.yaml


echo "Deploying Mongo Statefulset for Sensor-Cache"
sh backend/mongo/sensor-cache-mongo/mongo-secret.sh
kubectl --kubeconfig ./kubeconfig* apply -f backend/mongo/sensor-cache-mongo/mongo-sts.yaml -n nanoprecise
sleep 5

echo "Deploying Mongo Statefulset for Login-Cache"
sh backend/mongo/login-cache-mongo/mongo-secret.sh
kubectl --kubeconfig ./kubeconfig* apply -f backend/mongo/login-cache-mongo/mongo-sts.yaml -n nanoprecise
sleep 5

echo "Deploying Mongo Statefulset for KPI-Cache"
sh backend/mongo/kpi-cache-mongo/mongo-secret.sh
kubectl --kubeconfig ./kubeconfig* apply -f backend/mongo/kpi-cache-mongo/mongo-sts.yaml -n nanoprecise
sleep 5

echo "Deploying Mongo Statefulset for file-write"
sh backend/mongo/file-write-mongo/mongo-secret.sh
kubectl --kubeconfig ./kubeconfig* apply -f backend/mongo/file-write-mongo/mongo-sts.yaml -n nanoprecise
sleep 5

echo "Creating Secrets for Docker Hub Registry"
kubectl --kubeconfig ./kubeconfig* create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=$dockerhub_username --docker-password=$dockerhub_password

echo "Applying Ngine Ingress Controller API-Gateway"
envsubst < backend/api-gateway/nginx-ingress-controller.yaml > temp/tmp_file
cat temp/tmp_file > temp/nginx-ingress-controller.yaml
kubectl --kubeconfig ./kubeconfig* apply -f temp/nginx-ingress-controller.yaml

rm -rf temp
