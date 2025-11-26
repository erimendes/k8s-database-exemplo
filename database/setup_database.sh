#!/bin/bash
# k8s-database-exemplo/database/setup_database.sh
# Script para configurar o banco de dados MySQL no Kubernetes

IMAGE_NAME="erimendes/meubanco"
IMAGE_TAG="1.0"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "--- 1. Construindo a imagem Docker: ${FULL_IMAGE} ---"
docker build -t ${FULL_IMAGE} .

if [ $? -ne 0 ]; then
  echo "ERRO ao construir a imagem."
  exit 1
fi

echo "--- 2. Enviando imagem para o Docker Hub ---"
docker push ${FULL_IMAGE}

echo "--- 3. Aplicando PVC ---"
kubectl apply -f mysql-pvc.yaml

echo "--- 4. Aplicando Deployment e Service ---"
kubectl apply -f db-deployment.yml

echo "--- 5. Aguardando MySQL iniciar (até 180s) ---"
kubectl rollout status deployment/mysql-deployment --timeout=180s

echo "--- 6. Status ---"
kubectl get pvc mysql-pvc
kubectl get deploy,pod -l app=mysql
kubectl get svc mysql-service

echo "OK! Para acessar:"
echo "kubectl exec -it \$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- bash"
echo "mysql -uappuser -p"
echo "Senha: Senha123"
echo "Banco de dados: meubanco"
echo "Para remover tudo:"
echo "kubectl delete -f db-deployment.yaml"
echo "kubectl delete -f mysql-pvc.yaml"
echo "docker rmi ${FULL_IMAGE}"
echo "docker image prune -f"
echo "docker container prune -f"
echo "docker volume prune -f"
echo "docker network prune -f"
echo "kubectl delete all --all --namespace=default"
echo "CUIDADO: Os comandos acima removem todos os containers, imagens, volumes e redes não utilizados!"