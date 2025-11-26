<!-- README.md -->

## Criar imagem do banco mysql
docker build . -t erimendes/meubanco:1.0
docker push erimendes/meubanco:1.0
kubectl apply -f db-d
