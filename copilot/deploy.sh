#!/bin/bash

echo "📁 Criando estrutura..."
# A pasta 'mensagens' não é mais necessária, mas o mkdir -p é seguro.
mkdir -p k8s-app/{database,backend,frontend/mensagens}

echo "🧹 Limpando recursos antigos..."
# Corrigido: Nomes de deployment e ConfigMap para consistência
kubectl delete deploy backend-deploy frontend-deployment database-deploy --ignore-not-found
kubectl delete svc backend-service frontend-service database-service --ignore-not-found
kubectl delete configmap backend-config frontend-files-config --ignore-not-found

# --- DATABASE DEPLOYMENT (Mantido) ---
###########################################################################
# DATABASE DEPLOYMENT
###########################################################################
cat <<'EOF' > k8s-app/database/db.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
        - name: mysql
          image: mysql:8
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: root
            - name: MYSQL_DATABASE
              value: mensagensdb
          ports:
            - containerPort: 3306
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  selector:
    app: database
  ports:
    - port: 3306
      targetPort: 3306
EOF

# --- BACKEND CONFIGMAP (Mantido) ---
###########################################################################
# BACKEND CONFIGMAP (server.js)
###########################################################################
cat <<'EOF' > k8s-app/backend/backend-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  server.js: |
    const express = require('express');
    const mysql = require('mysql2');
    const http = require('http');
    const socketio = require('socket.io');

    const app = express();
    const server = http.createServer(app);
    const io = socketio(server, { cors: { origin: "*" } });

    app.use(express.json());

    const db = mysql.createConnection({
      host: 'database-service',
      user: 'root',
      password: 'root',
      database: 'mensagensdb'
    });

    db.query(`CREATE TABLE IF NOT EXISTS mensagens (
      id INT AUTO_INCREMENT PRIMARY KEY,
      usuario VARCHAR(255),
      mensagem TEXT,
      criado TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

    db.connect(err => {
      if (err) throw err;
      console.log('Conectado ao MySQL!');
    });

    app.post('/mensagem', (req, res) => {
      const { usuario, mensagem } = req.body;
      if(!usuario || usuario.length < 3 || !mensagem || mensagem.length < 3)
        return res.status(400).json({sucesso:false, erro:"Dados inválidos"});

      db.query('INSERT INTO mensagens (usuario, mensagem) VALUES (?, ?)',
        [usuario, mensagem],
        (err, result) => {
          if(err) return res.json({sucesso:false, erro:err.sqlMessage});

          db.query('SELECT * FROM mensagens WHERE id = ?',
            [result.insertId],
            (err2, rows) => {
              if(err2 || rows.length === 0)
                return res.json({sucesso:false, erro:"Erro ao consultar registro"});

              io.emit("nova_mensagem", rows[0]);
              res.json({sucesso:true, dados:rows[0]});
            }
          );
        }
      );
    });

    app.get('/mensagens', (req, res) => {
      db.query('SELECT * FROM mensagens ORDER BY criado DESC', (err, results) => {
        if(err) return res.status(500).json({erro:err.sqlMessage});
        res.json(results);
      });
    });

    io.on("connection", () => console.log("WebSocket conectado"));

    server.listen(3000, () => console.log("Backend rodando na porta 3000"));
EOF

# --- BACKEND DEPLOYMENT (CORRIGIDO com montagem em /tmp-code) ---
###########################################################################
# BACKEND DEPLOYMENT
###########################################################################
cat <<'EOF' > k8s-app/backend/backend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deploy
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
          image: node:18
          workingDir: /usr/src/app
          # CORREÇÃO: Copia o server.js do /tmp-code, instala libs e executa
          command: ["sh", "-c", "cp /tmp-code/server.js /usr/src/app/server.js && npm install express mysql2 socket.io && node server.js"]
          volumeMounts:
            # Monta ConfigMap em um diretório temporário
            - name: backend-code
              mountPath: /tmp-code 
          ports:
            - containerPort: 3000
      volumes:
        - name: backend-code
          configMap:
            name: backend-config
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
    - port: 3000
      targetPort: 3000
EOF

# --- FRONTEND FILES (HTML/CSS/JS/NGINX) ---
###########################################################################
# FRONTEND FILES (index, mensagens, js, css, nginx.conf)
###########################################################################
# Conteúdo do index.html (Unificado)
cat <<'EOF' > k8s-app/frontend/index.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <title>Chat Simples Kubernetes</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
  <link rel="stylesheet" href="css.css">
</head>
<body>
<nav class="navbar navbar-dark bg-dark">
  <div class="container-fluid">
    <a class="navbar-brand" href="/">Chat K8s</a>
  </div>
</nav>

<div class="container mt-4">
  <div class="row">
    <div class="col-md-4 mb-4">
      <h3>Enviar Mensagem</h3>
      <input id="nome" class="form-control" placeholder="Seu nome"/>
      <textarea id="mensagem" class="form-control mt-2" placeholder="Mensagem"></textarea>
      <button id="btn_salvar" class="btn btn-primary w-100 mt-3">Enviar</button>
      <div id="resposta" class="mt-2 fw-bold"></div>
    </div>

    <div class="col-md-8">
      <h2>Mensagens Recentes</h2>
      <ul id="lista" class="list-group">
        <li class="list-group-item disabled" aria-disabled="true">Carregando mensagens...</li>
      </ul>
    </div>
  </div>
</div>

<script src="js.js"></script>
</body>
</html>
EOF

# Conteúdo do mensagens/index.html (Mantido, mas não será usado no ConfigMap)
cat <<'EOF' > k8s-app/frontend/mensagens/index.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <title>Mensagens</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
</head>
<body>

<nav class="navbar navbar-dark bg-dark">
  <a class="navbar-brand ms-3" href="/">Home</a>
</nav>

<div class="container mt-4">
  <h2>Mensagens</h2>
  <ul id="lista" class="list-group"></ul>
</div>

<script>
const socket = io();
function addMsg(m){
  const li=document.createElement("li");
  li.className="list-group-item";
  li.innerHTML=`<b>${m.usuario}</b>: ${m.mensagem}
  <br><small>${m.criado}</small>`;
  lista.prepend(li);
}
socket.on("nova_mensagem", addMsg);

fetch("/api/mensagens").then(r=>r.json()).then(msgs=>msgs.forEach(addMsg));
</script>
</body>
</html>
EOF

# Conteúdo do js.js (CORRIGIDO E ATUALIZADO)
cat <<'EOF' > k8s-app/frontend/js.js
// Conteúdo CORRIGIDO
function addMsg(m){
  const lista = document.getElementById("lista");
  const li=document.createElement("li");
  li.className="list-group-item";
  // Formatando data
  const date = new Date(m.criado);
  const formattedDate = date.toLocaleTimeString('pt-BR') + ' ' + date.toLocaleDateString('pt-BR');

  li.innerHTML=`<b>${m.usuario}</b>: ${m.mensagem}
  <br><small>${formattedDate}</small>`;
  lista.prepend(li);
}

document.addEventListener('DOMContentLoaded', () => {
    const lista = document.getElementById("lista");
    lista.innerHTML = ''; // Limpa o item de carregamento

    // 1. WebSocket
    const socket = io();
    socket.on("nova_mensagem", addMsg);

    // 2. Fetch de mensagens existentes
    fetch("/api/mensagens")
        .then(r => r.json())
        .then(msgs => msgs.forEach(addMsg))
        .catch(err => {
             lista.innerHTML = '<li class="list-group-item list-group-item-danger">Erro ao carregar mensagens.</li>';
             console.error("Erro ao carregar mensagens:", err);
        });

    // 3. Listener do botão de envio
    const btnSalvar = document.getElementById("btn_salvar");

    btnSalvar.onclick = async () => {
        // CORREÇÃO: Usar document.getElementById para obter os elementos
        const nomeInput = document.getElementById("nome"); 
        const mensagemInput = document.getElementById("mensagem");

        const nome = nomeInput.value.trim();
        const mensagem = mensagemInput.value.trim();
        const resp = document.getElementById("resposta");

        if(nome.length < 3 || mensagem.length < 3){
            resp.innerHTML = "Preencha corretamente!";
            resp.style.color = "red";
            return;
        }

        btnSalvar.disabled = true;

        const f = await fetch("/api/mensagem", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ usuario: nome, mensagem })
        });

        const dados = await f.json();
        
        btnSalvar.disabled = false;

        if(dados.sucesso){
            resp.innerHTML = "Mensagem enviada!";
            resp.style.color = "green";
            mensagemInput.value = "";
        } else {
            resp.innerHTML = "Erro: " + (dados.erro || "Falha desconhecida");
            resp.style.color = "red";
        }
    };
});
EOF

# Conteúdo do css.css (Mantido)
cat <<'EOF' > k8s-app/frontend/css.css
body { padding:20px; }
EOF

# Conteúdo do nginx.conf (Simplificado e mantido)
cat <<'EOF' > k8s-app/frontend/nginx.conf
events {}
http {
  server {
    listen 80;
    root /usr/share/nginx/html;

    location /api/ {
      proxy_pass http://backend-service:3000/;
    }

    location /socket.io/ {
      proxy_pass http://backend-service:3000/socket.io/;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    }

    location / {
      try_files $uri $uri/ /index.html;
    }
  }
}
EOF

# --- FRONTEND CONFIGMAP (CORRIGIDO e simplificado) ---
###########################################################################
# FRONTEND CONFIGMAP
###########################################################################
# Removida a chave mensagens-index.html e a seção duplicada
kubectl create configmap frontend-files-config \
  --from-file=index.html=k8s-app/frontend/index.html \
  --from-file=js.js=k8s-app/frontend/js.js \
  --from-file=css.css=k8s-app/frontend/css.css \
  --from-file=nginx.conf=k8s-app/frontend/nginx.conf \
  -o yaml --dry-run=client | kubectl apply -f -

# --- FRONTEND DEPLOYMENT + SERVICE (CORRIGIDO) ---
#########################################################
# FRONTEND DEPLOYMENT + SERVICE
#########################################################
cat <<'EOF' > k8s-app/frontend/frontend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
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
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            # Monta nginx.conf no local correto
            - name: frontend-files
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
            # Monta arquivos estáticos
            - name: frontend-files
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
            - name: frontend-files
              mountPath: /usr/share/nginx/html/js.js
              subPath: js.js
            - name: frontend-files
              mountPath: /usr/share/nginx/html/css.css
              subPath: css.css
      volumes:
        - name: frontend-files
          configMap:
            name: frontend-files-config
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
EOF


###########################################################################
# APPLY ALL
###########################################################################

echo "🚀 Aplicando Kubernetes..."

# Aplica Configuração e Deployment/Service
kubectl apply -f k8s-app/database/db.yaml
kubectl apply -f k8s-app/backend/backend-config.yaml
kubectl apply -f k8s-app/backend/backend.yaml
kubectl apply -f k8s-app/frontend/frontend.yaml

echo "⏳ Aguardando frontend..."
kubectl wait --for=condition=available deployment/frontend-deployment --timeout=180s

echo "🌍 Frontend disponível em:"
minikube service frontend-service --url

echo "🎉 Deploy finalizado com sucesso!"