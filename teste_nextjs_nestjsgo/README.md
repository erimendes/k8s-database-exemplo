🔧 Script adaptado (setup_project.sh)
Este script cria a estrutura de diretórios e arquivos para:

Frontend: Next.js (SSR/SPA) com Dockerfile para produção.

Backend: NestJS (Node) com PostgreSQL. (Se preferir Go, basta trocar a pasta backend por um projeto Go simples com main.go e ajustar o Dockerfile.)

Database: PostgreSQL StatefulSet + Service + Job de migração.

Kubernetes: Deployments, Services, Secrets, ConfigMaps, Ingress.

Principais mudanças
Frontend:

Usa next em vez de vite/react.

Dockerfile baseado em node:20-alpine, build com next build, serve com next start.

package.json com dependências de Next.js..

Backend:

Usa NestJS (@nestjs/core, @nestjs/common, @nestjs/typeorm, pg).

Estrutura mínima: main.ts, app.module.ts, users/messages modules.

Dockerfile baseado em Node 20.

🚀 Como usar
Gerar projeto:

bash
bash setup_project.sh
Buildar imagens locais:

bash
docker build -t backend-go:latest k8s-projeto/backend
docker build -t frontend-next:latest k8s-projeto/frontend
Carregar no cluster:

Kind: kind load docker-image backend-go:latest frontend-next:latest

Minikube: eval $(minikube docker-env) e depois docker build ...

Aplicar manifests:

bash
kubectl apply -f k8s-projeto/k8s/
Ingress:

Kind: instalar ingress-nginx e mapear app.local para 127.0.0.1.

Minikube: minikube addons enable ingress + minikube tunnel.