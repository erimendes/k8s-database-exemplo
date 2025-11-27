Como executar
Salvar e rodar:

Passo: crie o arquivo setup_project.sh e cole o script acima.

Comando: bash setup_project.sh

Build das imagens:

Backend: docker build -t ghcr.io/seu-usuario/k8s-backend:latest k8s-projeto/backend

Frontend: docker build -t ghcr.io/seu-usuario/k8s-frontend:latest k8s-projeto/frontend

Publicar no registry:

Ajuste: troque ghcr.io/seu-usuario/... pelos seus repositórios e faça push.

Aplicar no cluster:

Comandos: conforme o README gerado em k8s-projeto/README.md.

Próximos passos
Label personalizada: quer trocar React por Next.js, ou Node por NestJS/Go? Eu adapto o script.

Cluster local: se usar Kind/Minikube, posso te passar os comandos para carregar as imagens locais sem precisar de registry.