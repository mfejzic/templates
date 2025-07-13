# will auto push docke rimage to registry after its creation - container app wil auto pull this image

az acr login --name mf37registry
docker tag flask-cosmos-app:latest mf37registry.azurecr.io/flask-cosmos-app:latest
docker push mf37registry.azurecr.io/flask-cosmos-app:latest
