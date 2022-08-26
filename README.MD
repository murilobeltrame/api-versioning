# ASP.Net API Versioning on Azure Api Gateway

## Deliver application to Docker Hub Registry

```sh
docker buildx build --platform linux/amd64,linux/arm64 --tag murilobeltrame/wineapi Wine.Api --push --no-cache
```

## Deploy application on Azure Container App

```sh
cd /src/environment
terraform init
terraform apply
```
