#!/usr/bin/env bash
set -euo pipefail

ROOT="k8s-projeto"
echo "Criando projeto em ./${ROOT}"
mkdir -p "${ROOT}"

# Diretórios
mkdir -p "${ROOT}/k8s/postgres" \
         "${ROOT}/k8s/backend" \
         "${ROOT}/k8s/frontend" \
         "${ROOT}/backend/src" \
         "${ROOT}/frontend/src"

########################################
# Arquivos Kubernetes
########################################

# k8s/namespace.yaml
cat > "${ROOT}/k8s/namespace.yaml" <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: app-mensagens
YAML

# k8s/configmap.yaml
cat > "${ROOT}/k8s/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: app-mensagens
data:
  BACKEND_PORT: "3000"
  FRONTEND_PORT: "80"
  VITE_API_URL: "/api"
YAML

# k8s/secret.yaml
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

# k8s/postgres/statefulset.yaml
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
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: POSTGRES_DB
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

# k8s/postgres/service.yaml
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
    - name: db
      port: 5432
      targetPort: 5432
YAML

# k8s/postgres/init-job.yaml (Job + ConfigMap de migrations)
cat > "${ROOT}/k8s/postgres/init-job.yaml" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: app-mensagens
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: migrate
          image: node:20-alpine
          command:
            - sh
            - -c
            - >
              npm i pg &&
              node -e "
                const { Client } = require('pg');
                const fs = require('fs');
                const sql = fs.readFileSync('/migrations.sql', 'utf8');
                const c = new Client({ connectionString: process.env.DATABASE_URL });
                c.connect()
                 .then(() => c.query(sql))
                 .then(() => { console.log('Migrations OK'); process.exit(0); })
                 .catch(e => { console.error(e); process.exit(1); });
              "
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: DATABASE_URL
          volumeMounts:
            - name: migrations
              mountPath: /
      volumes:
        - name: migrations
          configMap:
            name: migrations-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: migrations-cm
  namespace: app-mensagens
data:
  migrations.sql: |
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS messages (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
YAML

# k8s/backend/deployment.yaml
cat > "${ROOT}/k8s/backend/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app-mensagens
spec:
  replicas: 2
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
          image: ghcr.io/seu-usuario/k8s-backend:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: BACKEND_PORT
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: DATABASE_URL
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

# k8s/backend/service.yaml
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

# k8s/frontend/deployment.yaml
cat > "${ROOT}/k8s/frontend/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: app-mensagens
spec:
  replicas: 2
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
          image: ghcr.io/seu-usuario/k8s-frontend:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          env:
            - name: VITE_API_URL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: VITE_API_URL
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
YAML

# k8s/frontend/service.yaml
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
    - port: 80
      targetPort: 80
  type: ClusterIP
YAML

# k8s/ingress.yaml
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
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 3000
YAML

########################################
# Backend (Node.js/Express)
########################################

# backend/package.json
cat > "${ROOT}/backend/package.json" <<'JSON'
{
  "name": "k8s-backend",
  "version": "1.0.0",
  "main": "src/index.js",
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "migrate": "node src/index.js migrate"
  },
  "dependencies": {
    "express": "^4.19.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5"
  }
}
JSON

# backend/src/db.js
cat > "${ROOT}/backend/src/db.js" <<'JS'
import pg from 'pg';
const { Pool } = pg;

// Usa URL completa: postgres://user:pass@host:port/dbname
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('DATABASE_URL não definido');
}

export const pool = new Pool({ connectionString });

export async function migrate(client) {
  const fs = await import('fs');
  const path = await import('path');
  const sql = fs.readFileSync(path.resolve('src/migrations.sql'), 'utf8');
  await client.query(sql);
}
JS

# backend/src/routes.js
cat > "${ROOT}/backend/src/routes.js" <<'JS'
import express from 'express';
import { pool } from './db.js';

const router = express.Router();

// Users
router.post('/users', async (req, res) => {
  try {
    const { name, email } = req.body;
    const { rows } = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email já cadastrado' });
    res.status(500).json({ error: 'Erro ao criar usuário' });
  }
});

router.get('/users', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM users ORDER BY id DESC');
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'Erro ao listar usuários' });
  }
});

// Messages
router.post('/messages', async (req, res) => {
  try {
    const { user_id, content } = req.body;
    const { rows } = await pool.query(
      'INSERT INTO messages (user_id, content) VALUES ($1, $2) RETURNING *',
      [user_id, content]
    );
    res.status(201).json(rows[0]);
  } catch {
    res.status(500).json({ error: 'Erro ao criar mensagem' });
  }
});

router.get('/messages', async (_req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT m.*, u.name as user_name, u.email as user_email
       FROM messages m
       JOIN users u ON u.id = m.user_id
       ORDER BY m.id DESC`
    );
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'Erro ao listar mensagens' });
  }
});

export default router;
JS

# backend/src/index.js
cat > "${ROOT}/backend/src/index.js" <<'JS'
import express from 'express';
import cors from 'cors';
import { pool, migrate } from './db.js';
import router from './routes.js';

const app = express();
app.use(cors());
app.use(express.json());

// Health
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.send('ok');
  } catch {
    res.status(500).send('db down');
  }
});

app.use('/api', router);

const port = process.env.PORT || 3000;
const mode = process.argv[2];

if (mode === 'migrate') {
  (async () => {
    const client = await pool.connect();
    try {
      await migrate(client);
      console.log('Migrations executadas');
      process.exit(0);
    } catch (e) {
      console.error(e);
      process.exit(1);
    } finally {
      client.release();
    }
  })();
} else {
  app.listen(port, () => console.log(`Backend ouvindo na porta ${port}`));
}
JS

# backend/src/migrations.sql
cat > "${ROOT}/backend/src/migrations.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
SQL

# Backend Dockerfile
cat > "${ROOT}/backend/Dockerfile" <<'DOCKER'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY src ./src
EXPOSE 3000
CMD ["node", "src/index.js"]
DOCKER

########################################
# Frontend (React + Vite + Nginx)
########################################

# frontend/package.json
cat > "${ROOT}/frontend/package.json" <<'JSON'
{
  "name": "k8s-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "@vitejs/plugin-react": "^4.0.4"
  }
}
JSON

# frontend/index.html
cat > "${ROOT}/frontend/index.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>App Mensagens</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

# frontend/src/main.jsx
cat > "${ROOT}/frontend/src/main.jsx" <<'JSX'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';

createRoot(document.getElementById('root')).render(<App />);
JSX

# frontend/src/App.jsx
cat > "${ROOT}/frontend/src/App.jsx" <<'JSX'
import { useEffect, useState } from 'react';
import { api } from './api';

export default function App() {
  const [users, setUsers] = useState([]);
  const [messages, setMessages] = useState([]);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [content, setContent] = useState('');
  const [userId, setUserId] = useState('');

  const refresh = async () => {
    const u = await api.get('/users');
    const m = await api.get('/messages');
    setUsers(u);
    setMessages(m);
  };

  useEffect(() => { refresh().catch(console.error); }, []);

  const createUser = async () => {
    if (!name || !email) return;
    await api.post('/users', { name, email });
    setName(''); setEmail('');
    await refresh();
  };

  const createMessage = async () => {
    if (!userId || !content) return;
    await api.post('/messages', { user_id: Number(userId), content });
    setContent(''); setUserId('');
    await refresh();
  };

  return (
    <div style={{ padding: 24, fontFamily: 'sans-serif', maxWidth: 720, margin: '0 auto' }}>
      <h1>App de Usuários e Mensagens</h1>

      <h2>Usuários</h2>
      <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
        <input placeholder="Nome" value={name} onChange={e => setName(e.target.value)} />
        <input placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} />
        <button onClick={createUser}>Criar usuário</button>
      </div>
      <ul>
        {users.map(u => <li key={u.id}>{u.name} ({u.email})</li>)}
      </ul>

      <h2>Mensagens</h2>
      <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
        <input placeholder="User ID" value={userId} onChange={e => setUserId(e.target.value)} />
        <input placeholder="Conteúdo" value={content} onChange={e => setContent(e.target.value)} />
        <button onClick={createMessage}>Criar mensagem</button>
      </div>
      <ul>
        {messages.map(m => <li key={m.id}>[{m.id}] {m.content} — {m.user_name} ({m.user_email})</li>)}
      </ul>
    </div>
  );
}
JSX

# frontend/src/api.js
cat > "${ROOT}/frontend/src/api.js" <<'JS'
const BASE_URL = import.meta.env.VITE_API_URL || '/api';

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  get: (p) => request(p),
  post: (p, body) => request(p, { method: 'POST', body })
};
JS

# frontend/vite.config.js
cat > "${ROOT}/frontend/vite.config.js" <<'JS'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000'
    }
  }
});
JS

# frontend/Dockerfile
cat > "${ROOT}/frontend/Dockerfile" <<'DOCKER'
# Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --legacy-peer-deps || yarn
COPY . .
RUN npm run build

# Serve com Nginx
FROM nginx:1.25-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
DOCKER

# frontend/nginx.conf
cat > "${ROOT}/frontend/nginx.conf" <<'NGINX'
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri /index.html;
  }

  # Proxy para o backend (sem Ingress, ambiente local)
  location /api {
    proxy_pass http://backend:3000/api;
  }
}
NGINX

########################################
# README rápido
########################################
cat > "${ROOT}/README.md" <<'MD'
# App Mensagens (Kubernetes)

## Componentes
- Backend Node/Express (API REST)
- Frontend React/Vite (SPA servida por Nginx)
- Banco PostgreSQL (StatefulSet)
- Manifests Kubernetes (Deployments, Services, Secret, ConfigMap, Job de migração, Ingress)

## Build das imagens
- Backend:
  docker build -t ghcr.io/seu-usuario/k8s-backend:latest backend
- Frontend:
  docker build -t ghcr.io/seu-usuario/k8s-frontend:latest frontend
- Faça push para seu registry e atualize os manifests se necessário.

## Deploy no Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres/service.yaml
kubectl apply -f k8s/postgres/statefulset.yaml
kubectl apply -f k8s/postgres/init-job.yaml
kubectl apply -f k8s/backend/deployment.yaml
kubectl apply -f k8s/backend/service.yaml
kubectl apply -f k8s/frontend/deployment.yaml
kubectl apply -f k8s/frontend/service.yaml
kubectl apply -f k8s/ingress.yaml

## Acesso
- Configure o DNS/hosts para `app.local` apontar para o Ingress.
- A API estará em `http://app.local/api`.

## Notas
- Edite `k8s/secret.yaml` para alterar a URL do banco (DATABASE_URL).
- Em ambiente local sem Ingress, o `nginx.conf` do frontend proxy para `backend:3000/api`.
MD

echo "Projeto criado em ${ROOT}"
