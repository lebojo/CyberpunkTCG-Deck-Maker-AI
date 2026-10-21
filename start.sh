#!/usr/bin/env bash
# Lance le Deck Maker en local avec la config du fichier .env.
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo "Fichier .env créé. Renseigne INFOMANIAK_TOKEN et INFOMANIAK_PRODUCT_ID dedans, puis relance ./start.sh"
    exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ -z "${INFOMANIAK_TOKEN:-}" ]]; then
    echo "INFOMANIAK_TOKEN est vide dans .env"
    exit 1
fi
if [[ -z "${INFOMANIAK_PRODUCT_ID:-}" ]]; then
    echo "INFOMANIAK_PRODUCT_ID est vide dans .env. Produits accessibles avec ce token :"
    curl -s https://api.infomaniak.com/1/ai -H "Authorization: Bearer $INFOMANIAK_TOKEN" \
        | grep -oE '"product_id":[0-9]+|"name":"[^"]*"' | paste - - || true
    exit 1
fi

if ! command -v php >/dev/null; then
    echo "PHP est requis pour le proxy. Installe-le avec : brew install php"
    exit 1
fi

PORT="${PORT:-8000}"
URL="http://localhost:$PORT"
echo "Deck Maker sur $URL (Ctrl+C pour arrêter)"
(sleep 1 && open "$URL" 2>/dev/null || true) &
php -S "localhost:$PORT"
