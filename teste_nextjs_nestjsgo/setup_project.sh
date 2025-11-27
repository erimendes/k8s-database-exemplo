#!/usr/bin/env bash
set -euo pipefail

ROOT="k8s-projeto"
echo "Criando projeto em ./${ROOT}"
mkdir -p "${ROOT}"

# Diretórios
mkdir -p "${ROOT}/k8s/postgres" \
         "${ROOT}/k8s/backend" \
         "${ROOT}/k8s/frontend" \
         "${ROOT}/backend/cmd/api" \
         "${ROOT}/frontend/pages"

# NOTA: O diretório backend foi alterado para incluir cmd/api, 
# pois o Dockerfile espera 'cmd/api/main.go'.

########################################
# Kubernetes Manifests (YAMLs)
########################################

# Namespace
cat > "${ROOT}/k8s/namespace.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: app-mensagens
YAML

# ConfigMap
cat > "${ROOT}/k8s/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: app-mensagens
data:
  BACKEND_PORT: "3000"
  FRONTEND_PORT: "3000"
  NEXT_PUBLIC_API_URL: "/api"
YAML

# Secret
cat > "${ROOT}/k8s/secret.yaml" <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: app-mensagens
type: Opaque
stringData:
  POSTGRES_USER: appuser
  POSTGRES_PASSWORD: supersecret
  POSTGRES_DB: appdb
  DATABASE_URL: postgres://appuser:supersecret@postgres.app-mensagens.svc.cluster.local:5432/appdb
YAML

# PostgreSQL StatefulSet
cat > "${ROOT}/k8s/postgres/statefulset.yaml" <<'YAML'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: app-mensagens
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: db-secret
          volumeMounts:
            - name: pgdata
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: pgdata
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
YAML

# PostgreSQL Service
cat > "${ROOT}/k8s/postgres/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: app-mensagens
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
YAML

# Backend Deployment (Go)
cat > "${ROOT}/k8s/backend/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app-mensagens
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: backend-go:latest
          ports:
            - containerPort: 3000
          envFrom:
            - secretRef:
                name: db-secret
            - configMapRef:
                name: app-config
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
YAML

# Backend Service
cat > "${ROOT}/k8s/backend/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: app-mensagens
spec:
  selector:
    app: backend
  ports:
    - port: 3000
      targetPort: 3000
  type: ClusterIP
YAML

# Frontend Deployment (Next.js)
cat > "${ROOT}/k8s/frontend/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: app-mensagens
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: frontend-next:latest
          ports:
            - containerPort: 3000
          envFrom:
            - configMapRef:
                name: app-config
          readinessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
YAML

# Frontend Service
cat > "${ROOT}/k8s/frontend/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: app-mensagens
spec:
  selector:
    app: frontend
  ports:
    - port: 3000
      targetPort: 3000
  type: ClusterIP
YAML

# Ingress
cat > "${ROOT}/k8s/ingress.yaml" <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: app-mensagens
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: app.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 3000
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 3000
YAML

########################################
# Dockerfile Backend (Go)
########################################
cat > "${ROOT}/backend/Dockerfile" <<'DOCKERFILE'
# Estágio de Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
# O COPY go.mod go.sum ./ agora funciona, pois eles são criados abaixo.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Compila o arquivo principal
RUN CGO_ENABLED=0 go build -o /backend-app cmd/api/main.go

# Estágio Final
FROM alpine:latest
WORKDIR /app
EXPOSE 3000
COPY --from=builder /backend-app /app/backend-app
CMD ["/app/backend-app"]
DOCKERFILE

########################################
# Arquivos de Código-fonte (Go Backend) 
########################################
# go.mod (módulo inicial)
cat > "${ROOT}/backend/go.mod" <<'GOMOD'
module app-mensagens/backend

go 1.21

require (
    github.com/gorilla/mux v1.8.0 
)
GOMOD

# go.sum (vazio para COPY inicial, será preenchido pelo 'go mod download')
# O uso de 'touch' aqui é melhor para garantir que o arquivo exista
touch "${ROOT}/backend/go.sum" 

# main.go (ponto de entrada com health check)
cat > "${ROOT}/backend/cmd/api/main.go" <<'GOMAIN'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
)

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func main() {
	router := mux.NewRouter()

	// Handler para Health Check
	router.HandleFunc("/health", healthCheck).Methods("GET")
	
	port := os.Getenv("BACKEND_PORT")
	if port == "" {
		port = "3000"
	}
	
	log.Printf("Servidor backend rodando na porta :%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
}
GOMAIN


########################################
# Dockerfile Frontend (Next.js)
########################################
cat > "${ROOT}/frontend/Dockerfile" <<'DOCKERFILE'
# 1. Estágio de Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

# 2. Estágio de Execução (Produção)
FROM node:20-alpine AS runner
WORKDIR /app
ENV NEXT_PUBLIC_API_URL="/api"
EXPOSE 3000
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
CMD ["node", "server.js"]
DOCKERFILE

########################################
# Arquivos de Dependência (Frontend Next.js) 
########################################
# package.json (módulo inicial)
cat > "${ROOT}/frontend/package.json" <<'NPMJSON'
{
  "name": "frontend-next",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18",
    "react-dom": "18"
  },
  "devDependencies": {
    "eslint": "8",
    "eslint-config-next": "14.0.0"
  }
}
NPMJSON

# package-lock.json (vazio, será gerado pelo 'npm install' no Dockerfile)
touch "${ROOT}/frontend/package-lock.json"

# pages/index.js (página inicial simples)
cat > "${ROOT}/frontend/pages/index.js" <<'JSPAGE'
import React from 'react';

const HomePage = () => {
  return (
    <div>
      <h1>Bem-vindo ao App Mensagens!</h1>
      <p>O Frontend (Next.js) está rodando e se comunicará com a API em: {process.env.NEXT_PUBLIC_API_URL}</p>
      <p>Verifique o console para a chamada da API.</p>
    </div>
  );
};

export default HomePage;
JSPAGE


########################################
# README com instruções Kind/Minikube
########################################
cat > "${ROOT}/README.md" <<'MD'
# App Mensagens (Next.js + Go + PostgreSQL)

## ATENÇÃO: Pré-requisitos
Os arquivos essenciais (código e dependências) foram criados. Você pode começar a desenvolver a partir deles!

## Build das imagens locais
docker build -t backend-go:latest k8s-projeto/backend/
docker build -t frontend-next:latest k8s-projeto/frontend/

## Carregar imagens no cluster

### Kind
kind load docker-image backend-go:latest
kind load docker-image frontend-next:latest

### Minikube
eval $(minikube docker-env)
# Atenção: Após rodar 'eval', execute novamente o 'docker build' acima para usar o daemon do Minikube.
docker build -t backend-go:latest k8s-projeto/backend/
docker build -t frontend-next:latest k8s-projeto/frontend/

## Deploy no Kubernetes
kubectl apply -f k8s-projeto/k8s/

## Ingress
- Kind: instale ingress-nginx e adicione `127.0.0.1 app.local` em /etc/hosts.
- Minikube: habilite ingress com `minikube addons enable ingress` e rode `minikube tunnel`.

## Acesso
- Frontend: http://app.local/
- API: http://app.local/api
MD

echo "Projeto criado em ${ROOT}"