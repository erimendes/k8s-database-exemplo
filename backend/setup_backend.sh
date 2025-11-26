#!/bin/bash
# k8s-database-exemplo/backend/setup_backend.sh
# Script para configurar e implantar o backend PHP no Kubernetes.

# Variáveis
IMAGE_NAME="erimendes/php"
IMAGE_TAG="8.2-latest"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Caminhos corrigidos, assumindo que este script é executado do diretório 'backend/'
DEPLOYMENT_FILE="php-deployment.yml"
DOCKER_CONTEXT="." # O Dockerfile e arquivos estão neste diretório (backend/)

# Credenciais do DB (devem coincidir com as do Deployment do MySQL)
DB_USER_VAL="appuser"
DB_PASS_VAL="Senha123" 

# Função para verificar o último comando e sair em caso de falha
check_status() {
    if [ $? -ne 0 ]; then
        echo "❌ ERRO: O último comando falhou. Abortando." >&2
        exit 1
    fi
}

echo "=================================================="
echo "🚀 INICIANDO IMPLANTAÇÃO DO BACKEND PHP (K8s) 🚀"
echo "=================================================="

## 1. Criação/Atualização do Kubernetes Secret

echo "1/5 - Criando/Atualizando Kubernetes Secret 'db-credentials' para credenciais do DB..."
# Cria o Secret referenciado no php-deployment.yml
kubectl create secret generic db-credentials \
  --from-literal=username=${DB_USER_VAL} \
  --from-literal=password=${DB_PASS_VAL} \
  --dry-run=client -o yaml | kubectl apply -f - --overwrite=true
check_status

## 2. Construção e Push da Imagem Docker

echo "2/5 - Construindo a imagem Docker com a tag: $FULL_IMAGE"
# Contexto é o diretório atual (.)
docker build ${DOCKER_CONTEXT} -t $FULL_IMAGE
check_status

echo "    > Fazendo push da imagem Docker..."
docker push $FULL_IMAGE
check_status

## 3. Aplicação do Deployment e Service no Kubernetes

echo "3/5 - Aplicando a configuração do Kubernetes (${DEPLOYMENT_FILE})..."
kubectl apply -f ${DEPLOYMENT_FILE}
check_status

## 4. Verificação do Rollout e Status dos Componentes

echo "4/5 - Verificando o status do Deployment e aguardando o rollout..."

# Esperar ativamente pelo rollout do Deployment
kubectl rollout status deployment/php --timeout=300s
check_status

echo "    > Deployment pronto! Verificando pods e services..."
kubectl get pods -l app=php
kubectl get services php-service

echo "Backend PHP implantado e pronto com sucesso. 🎉"

## 5. Verificação dos Logs e Informações Adicionais

echo "5/5 - Verificando logs do pod para garantir o start up..."

# Obter o nome de um Pod em execução (o mais novo)
POD_NAME=$(kubectl get pods -l app=php -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo "⚠️ Aviso: Pod com 'app=php' não encontrado para logs."
else
    echo "    > Logs do Pod: $POD_NAME"
    kubectl logs $POD_NAME
fi

# Informação útil para acesso externo
echo "=================================================="
echo "✅ Backend rodando na porta 30005 (NodePort)!"
echo "Para testar, use:"
echo "curl -X POST http://<IP_DO_NÓ>:30005/gravar_mensagem.php -d \"nome=Teste&mensagem=MinhaMensagem\""
echo "=================================================="