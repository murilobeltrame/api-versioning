# ASP.Net API Versioning on Azure Api Gateway

## Export API Documentation

```sh
cd src
dotnet build
dotnet tool install
dotnet swagger tofile --output swagger.v1.json Wine.Api/bin/Debug/net6.0/Wine.Api.dll v1 # For V1
dotnet swagger tofile --output swagger.v2.json Wine.Api/bin/Debug/net6.0/Wine.Api.dll v2 # For v2
```

## Deliver application to Docker Hub Registry

```sh
cd src
docker buildx build --platform linux/amd64,linux/arm64 --tag murilobeltrame/wineapi Wine.Api --push --no-cache
```

## Deploy application on Azure Container App

```sh
cd src/environment
terraform init
terraform apply
```
