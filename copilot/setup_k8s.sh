Ótimo pedido 🚀! Vou te mostrar um exemplo completo em Kubernetes (YAML + aplicação simples) que cria:

Pod + Service Backend (API para atualizar o banco)

Pod + Service Frontend (página web para enviar usuário e mensagem)

Pod + Service Database (MySQL)

Integração entre eles para que a página do frontend permita atualizar a tabela mensagens(usuario, mensagem) no banco.

🗂 Estrutura dos arquivos
1. Banco de Dados (MySQL)
yaml
apiVersion: v1
kind: Pod
metadata:
  name: database-pod
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
    - protocol: TCP
      port: 3306
      targetPort: 3306
2. Backend (Node.js Express)
yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend-pod
  labels:
    app: backend
spec:
  containers:
    - name: backend
      image: node:18
      command: ["node", "server.js"]
      volumeMounts:
        - name: backend-code
          mountPath: /usr/src/app
      workingDir: /usr/src/app
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
    - protocol: TCP
      port: 3000
      targetPort: 3000
👉 O ConfigMap backend-config conteria o código server.js que conecta no MySQL e expõe um endpoint /mensagem.

Exemplo de server.js:

js
const express = require('express');
const mysql = require('mysql2');
const app = express();
app.use(express.json());

const db = mysql.createConnection({
  host: 'database-service',
  user: 'root',
  password: 'root',
  database: 'mensagensdb'
});

app.post('/mensagem', (req, res) => {
  const { usuario, mensagem } = req.body;
  db.query('INSERT INTO mensagens (usuario, mensagem) VALUES (?, ?)', [usuario, mensagem], (err) => {
    if (err) return res.status(500).send(err);
    res.send('Mensagem salva com sucesso!');
  });
});

app.listen(3000, () => console.log('Backend rodando na porta 3000'));
3. Frontend (HTML simples com fetch)
yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  labels:
    app: frontend
spec:
  containers:
    - name: frontend
      image: nginx:alpine
      volumeMounts:
        - name: frontend-code
          mountPath: /usr/share/nginx/html
  volumes:
    - name: frontend-code
      configMap:
        name: frontend-config
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
👉 O ConfigMap frontend-config conteria o index.html:

html
<!DOCTYPE html>
<html>
<head>
  <title>Atualizar Banco</title>
</head>
<body>
  <h1>Enviar Mensagem</h1>
  <form id="form">
    Usuário: <input type="text" id="usuario"><br>
    Mensagem: <input type="text" id="mensagem"><br>
    <button type="submit">Enviar</button>
  </form>
  <script>
    document.getElementById('form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const usuario = document.getElementById('usuario').value;
      const mensagem = document.getElementById('mensagem').value;
      await fetch('http://backend-service:3000/mensagem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ usuario, mensagem })
      });
      alert('Mensagem enviada!');
    });
  </script>
</body>
</html>
🚀 Como rodar
Salve os YAMLs em arquivos (db.yaml, backend.yaml, frontend.yaml).

Crie os ConfigMaps com o código do backend e frontend.

Aplique tudo no cluster:

bash
kubectl apply -f db.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
Exponha o frontend-service com NodePort ou Ingress para acessar no navegador.



Perfeito! 🎯 Vou montar os ConfigMaps prontos para você aplicar direto no cluster Kubernetes. Assim, o backend (Node.js) e o frontend (HTML/JS) ficam embutidos nos ConfigMaps e são montados nos Pods.

📦 ConfigMap do Backend (backend-config.yaml)
yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  server.js: |
    const express = require('express');
    const mysql = require('mysql2');
    const app = express();
    app.use(express.json());

    const db = mysql.createConnection({
      host: 'database-service',
      user: 'root',
      password: 'root',
      database: 'mensagensdb'
    });

    // Cria tabela se não existir
    db.query(`CREATE TABLE IF NOT EXISTS mensagens (
      id INT AUTO_INCREMENT PRIMARY KEY,
      usuario VARCHAR(255),
      mensagem TEXT
    )`);

    app.post('/mensagem', (req, res) => {
      const { usuario, mensagem } = req.body;
      db.query('INSERT INTO mensagens (usuario, mensagem) VALUES (?, ?)', [usuario, mensagem], (err) => {
        if (err) return res.status(500).send(err);
        res.send('Mensagem salva com sucesso!');
      });
    });

    app.get('/mensagens', (req, res) => {
      db.query('SELECT * FROM mensagens', (err, results) => {
        if (err) return res.status(500).send(err);
        res.json(results);
      });
    });

    app.listen(3000, () => console.log('Backend rodando na porta 3000'));
🎨 ConfigMap do Frontend (frontend-config.yaml)
yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <title>Atualizar Banco</title>
    </head>
    <body>
      <h1>Enviar Mensagem</h1>
      <form id="form">
        Usuário: <input type="text" id="usuario"><br>
        Mensagem: <input type="text" id="mensagem"><br>
        <button type="submit">Enviar</button>
      </form>

      <h2>Mensagens Salvas</h2>
      <ul id="lista"></ul>

      <script>
        async function carregarMensagens() {
          const res = await fetch('http://backend-service:3000/mensagens');
          const msgs = await res.json();
          const lista = document.getElementById('lista');
          lista.innerHTML = '';
          msgs.forEach(m => {
            const li = document.createElement('li');
            li.textContent = m.usuario + ': ' + m.mensagem;
            lista.appendChild(li);
          });
        }

        document.getElementById('form').addEventListener('submit', async (e) => {
          e.preventDefault();
          const usuario = document.getElementById('usuario').value;
          const mensagem = document.getElementById('mensagem').value;
          await fetch('http://backend-service:3000/mensagem', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ usuario, mensagem })
          });
          alert('Mensagem enviada!');
          carregarMensagens();
        });

        carregarMensagens();
      </script>
    </body>
    </html>
🚀 Como aplicar
Salve os arquivos como backend-config.yaml e frontend-config.yaml.

Aplique no cluster:

bash
kubectl apply -f backend-config.yaml
kubectl apply -f frontend-config.yaml
# Os Pods e Services que montam esses ConfigMaps (como mostrei antes), o frontend-service expõe a página.

Ao abrir no navegador, você terá o formulário para enviar usuário e mensagem, e logo abaixo a lista de mensagens salvas no banco.


