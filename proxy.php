<?php
// Mini proxy vers l'API Infomaniak AI Tools.
// Nécessaire car l'API Infomaniak n'autorise pas les appels directs depuis un navigateur (pas de CORS).
// La configuration (token, product ID, modèle par défaut) est lue dans le fichier .env à côté de ce fichier.

// Les modèles qui raisonnent peuvent mettre plusieurs minutes à composer un deck.
// Une valeur non nulle remplace toujours le minuteur armé par PHP (set_time_limit(0) ne le fait pas toujours).
set_time_limit(600);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function fail(int $status, string $message): void {
    http_response_code($status);
    echo json_encode(['error' => ['message' => $message]]);
    exit;
}

function loadEnv(string $path): array {
    $env = [];
    if (!is_readable($path)) return $env;
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#' || !str_contains($line, '=')) continue;
        [$key, $value] = array_map('trim', explode('=', $line, 2));
        $env[$key] = trim($value, "\"'");
    }
    return $env;
}

$env = loadEnv(__DIR__ . '/.env');
$envToken = $env['INFOMANIAK_TOKEN'] ?? '';
$envProductId = $env['INFOMANIAK_PRODUCT_ID'] ?? '';
$action = $_GET['action'] ?? '';

// Ce que la page a besoin de savoir, sans jamais exposer le token.
if ($action === 'config') {
    echo json_encode([
        'hasToken' => $envToken !== '',
        'productId' => $envProductId,
        'model' => $env['INFOMANIAK_MODEL'] ?? '',
    ]);
    exit;
}

$token = $envToken !== '' ? $envToken : trim($_SERVER['HTTP_X_INFOMANIAK_TOKEN'] ?? '');
if ($token === '') {
    fail(401, 'Token Infomaniak manquant (.env ou réglages).');
}

$productId = $envProductId !== '' ? $envProductId : ($_GET['product_id'] ?? '');
if ($action !== 'products' && !ctype_digit((string) $productId)) {
    fail(400, 'product_id invalide.');
}

switch ($action) {
    case 'products':
        $url = 'https://api.infomaniak.com/1/ai';
        $method = 'GET';
        break;
    case 'models':
        $url = "https://api.infomaniak.com/2/ai/$productId/openai/v1/models";
        $method = 'GET';
        break;
    case 'chat':
        $url = "https://api.infomaniak.com/2/ai/$productId/openai/v1/chat/completions";
        $method = 'POST';
        break;
    default:
        fail(400, 'Action inconnue.');
}

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 300,
    CURLOPT_HTTPHEADER => [
        "Authorization: Bearer $token",
        'Content-Type: application/json',
        'Accept: application/json',
    ],
]);
if ($method === 'POST') {
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
}

$body = curl_exec($ch);
if ($body === false) {
    fail(502, 'Erreur réseau vers Infomaniak : ' . curl_error($ch));
}
http_response_code(curl_getinfo($ch, CURLINFO_HTTP_CODE));
echo $body;
