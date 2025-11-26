<!-- // k8s-database-exemplo/backend/index.php -->
<?php
// Este arquivo foi corrigido para usar Prepared Statements, 
// pois a versão anterior era vulnerável a SQL Injection.

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include 'conexao.php';

// **ATENÇÃO:** O uso de index.php para uma ação POST de inserção é incomum.
// O arquivo 'gravar_mensagem.php' é mais adequado para esta lógica.
// Manteremos a lógica aqui, mas é recomendado ter funções específicas por arquivo.

$nome = $_POST["nome"] ?? '';
$mensagem = $_POST["mensagem"] ?? '';

if (empty($nome) || empty($mensagem)) {
    http_response_code(400); 
    echo json_encode(["error" => "Nome e mensagem são campos obrigatórios."]);
    exit();
}

// Preparar a instrução SQL com marcadores de posição (?)
$query = "INSERT INTO mensagens (nome, mensagem) VALUES (?, ?)";
$stmt = $link->prepare($query);

if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["error" => "Erro ao preparar a consulta: " . $link->error]);
    exit();
}

// Vincular os parâmetros (strings)
$stmt->bind_param("ss", $nome, $mensagem);

if ($stmt->execute()) {
    http_response_code(201);
    echo json_encode(["message" => "Registro criado com sucesso em index.php", "inserted_id" => $link->insert_id]);
} else {
    http_response_code(500);
    echo json_encode(["error" => "Error: " . $stmt->error]);
}

$stmt->close();
?>