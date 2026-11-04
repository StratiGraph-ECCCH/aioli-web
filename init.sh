#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"
DEPLOY_DIR="$(pwd)"

[ -f .env ] || cp .env.example .env
if grep -q '^HOST_PROJECT_PATH=' .env; then
    sed -i "s|^HOST_PROJECT_PATH=.*|HOST_PROJECT_PATH=${DEPLOY_DIR}|" .env
else
    echo "HOST_PROJECT_PATH=${DEPLOY_DIR}" >> .env
fi

IMAGE="$(grep -E '^AIOLI_WEB_IMAGE=' .env | cut -d= -f2-)"
IMAGE="${IMAGE:-aioli-web:prod}"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull "$IMAGE"

API_IMAGE="$(grep -E '^AIOLI_DATA_API_IMAGE=' .env | cut -d= -f2-)"
API_IMAGE="${API_IMAGE:-aioli-data-api:prod}"
docker image inspect "$API_IMAGE" >/dev/null 2>&1 || docker pull "$API_IMAGE"

# Images de traitement lancées par Aïoli via docker.sock, sous ces noms locaux (cf. src/bin).
# Si absentes, on les récupère sur le registre puis on les renomme.
REGISTRY="$(grep -E '^PROCESSING_REGISTRY=' .env | cut -d= -f2- || true)"
for LOCAL in potreeconverter:v1 matlab2017a:v1 micmac:0.1; do
    docker image inspect "$LOCAL" >/dev/null 2>&1 && continue
    if [ -z "$REGISTRY" ]; then
        echo "Image $LOCAL absente : renseigner PROCESSING_REGISTRY dans .env" >&2
        exit 1
    fi
    docker pull "$REGISTRY/$LOCAL"
    docker tag "$REGISTRY/$LOCAL" "$LOCAL"
done

echo "Extraction de src/bin depuis $IMAGE..."
rm -rf src/bin
mkdir -p src
CID="$(docker create "$IMAGE")"
docker cp "$CID:/var/www/html/src/bin" src/bin
docker rm "$CID" >/dev/null

mkdir -p workspace/usr workspace/heritage

echo "Prêt. Vérifier .env et config/constants.json, puis : docker compose up -d"
