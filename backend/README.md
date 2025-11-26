🚀 Deploy Automatizado de Aplicação PHP no Kubernetes

Este repositório contém o script setup_backend.sh e os manifests do Kubernetes responsáveis por construir, enviar e implantar automaticamente uma aplicação PHP + MySQL em um cluster Kubernetes (Minikube ou real).

O objetivo é oferecer um fluxo de CI/CD simplificado, automatizado e seguro.

📦 Recursos do Projeto

✔ Deploy automático no Kubernetes
✔ Construção e Push da imagem Docker
✔ Deploy de aplicação PHP
✔ Deploy do banco MySQL
✔ Geração automática de Secrets
✔ Service para acessar a aplicação
✔ Port-forward automático (opcional)
✔ Verificação de rollout do Kubernetes
✔ Documentação completa

📁 Estrutura do Projeto
/
├── setup_backend.sh          # Script principal de CI/CD no Kubernetes
├── Dockerfile                # Build da aplicação PHP
├── php-deployment.yml        # Deployment da aplicação
├── php-service.yml           # Service da aplicação
├── mysql-deployment.yml      # Deployment do MySQL
├── mysql-service.yml         # Service do MySQL
├── README.md

🛠 Pré-requisitos

Antes de executar o script, certifique-se de ter:

✔ Docker instalado
✔ Minikube instalado
✔ kubectl configurado
✔ Acesso à internet
✔ Linux (recomendado)

Para verificar:

docker --version
kubectl version --client
minikube version

⚙️ Instalação

Clone o repositório:

git clone https://github.com/SEU-USUARIO/SEU-REPO.git
cd SEU-REPO


Dê permissão ao script:

chmod +x setup_backend.sh


Execute:

./setup_backend.sh


O script fará:

Criar docker secret do banco

Build da imagem Docker

Push da imagem para o Docker Hub

Aplicação do Deployment + Service

Verificação do rollout

Expor o serviço PHP

Criar port-forward para MySQL

🚀 Como o Script Funciona (Etapa por Etapa)
1️⃣ Criação do Secret
kubectl create secret generic db-credentials \
  --from-literal=db_user=admin \
  --from-literal=db_pass=s3cr3ta


Benefício: mantém credenciais fora do YAML.

2️⃣ Build e Push da imagem Docker
docker build -t erimendes/php:8.2-latest .
docker push erimendes/php:8.2-latest

3️⃣ Aplicação dos arquivos YAML
kubectl apply -f php-deployment.yml
kubectl apply -f php-service.yml
kubectl apply -f mysql-deployment.yml
kubectl apply -f mysql-service.yml

4️⃣ Aguarda o rollout
kubectl rollout status deployment/php

5️⃣ Obter a URL da aplicação
minikube service php-service --url

6️⃣ Conectar ao MySQL
kubectl port-forward svc/mysql-service 3306:3306


Agora funciona via:

Host: 127.0.0.1
Port: 3306
User: admin
Pass: s3cr3ta

🏗 Arquitetura da Solução
Diagrama Kubernetes (Mermaid)
flowchart LR
    A[Docker Build] --> B[Docker Registry]
    B --> C[Deployment PHP]
    B --> D[Deployment MySQL]

    C --> E[ReplicaSet PHP] --> F[Pods PHP]
    D --> G[ReplicaSet MySQL] --> H[Pod MySQL]

    F --> I[Service PHP]
    H --> J[Service MySQL]

    I --> K[Cliente / Browser]
    J --> L[Aplicação PHP / DBeaver]

🌐 Fluxo de Implantação

Desenvolvedor faz alterações

Executa o script

Nova imagem vai para o Docker Hub

Kubernetes atualiza o Deployment

Pods antigos são substituídos

Service expõe a aplicação

MySQL acessível via port-forward

🧪 Testando Aplicação

Listar pods:

kubectl get pods


Acessar o PHP:

minikube service php-service --url


Abrir MySQL dentro do pod:

kubectl exec -it deploy/mysql-db -- mysql -u admin -p


Ver logs:

kubectl logs -f deploy/php

❗ Troubleshooting (Problemas Comuns)
❌ Erro: Access denied for user

✔ Verifique se o usuário existe:

SELECT user, host FROM mysql.user;


✔ Teste conexão dentro do pod:

kubectl exec -it deploy/mysql-db -- mysql -u admin -p


✔ Verifique as variáveis de ambiente do deployment:

kubectl describe deploy/php

❌ port-forward trava o terminal

Use:

nohup kubectl port-forward svc/mysql-service 3306:3306 &

❌ Minikube não abre serviço

Use driver Docker:

minikube start --driver=docker

❌ Deployment não atualiza

Force rollout:

kubectl rollout restart deployment/php

📬 Suporte

Se precisar de ajuda com Kubernetes, Docker ou PHP, posso ajudar a:

✔ depurar conexões
✔ ajustar YAMLs
✔ melhorar CI/CD
✔ implementar ingress
✔ adicionar monitoramento com Prometheus

🏁 Conclusão

Este projeto cria um fluxo completo de CI/CD simplificado, seguro e profissional usando:

Docker

Kubernetes

Minikube

Secrets

Deployment

Service

Se quiser, posso também gerar:
✅ versão em inglês
✅ documentação PDF
✅ diagrama real com Imagem
✅ template para seu GitHub Pages