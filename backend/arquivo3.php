<!-- k8s-database-exemplo/backend/arquivo3.php -->
<?php
// Melhor prática: mudar o nome do arquivo para algo descritivo, como 'gravar_mensagem.php'

header("Content-Type: application/json; charset=UTF-8"); // Resposta JSON é padrão em APIs
header("Access-Control-Allow-Origin: *");
// Adicionar métodos permitidos
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Se for um método OPTIONS (pré-voo CORS), apenas responda com sucesso
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

include 'conexao.php'; // Inclui a conexão

// O id é NULL pois a coluna 'id' é AUTO_INCREMENT no banco de dados.
$id = NULL; 

// Capturar e sanitizar a entrada do POST (usando operador de coalescência nula)
$nome = $_POST["nome"] ?? '';
$mensagem = $_POST["mensagem"] ?? '';

// Verificação básica de entrada
if (empty($nome) || empty($mensagem)) {
    http_response_code(400); // 400 Bad Request
    echo json_encode(["error" => "Nome e mensagem são campos obrigatórios."]);
    exit();
}

// **CORREÇÃO DE SEGURANÇA CRÍTICA:** Usar Prepared Statements para prevenir Injeção de SQL.

// 1. Preparar a instrução SQL com marcadores de posição (?)
$query = "INSERT INTO mensagens (nome, mensagem) VALUES (?, ?)";
$stmt = $link->prepare($query);

// Verificar se a preparação foi bem-sucedida
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["error" => "Erro ao preparar a consulta: " . $link->error]);
    exit();
}

// 2. Vincular os parâmetros ('s' para string)
// A ordem deve corresponder aos '?' na query: nome (string), mensagem (string)
// Note que 'id' não está na lista, pois é auto-incrementado.
$stmt->bind_param("ss", $nome, $mensagem);

// 3. Executar a instrução
if ($stmt->execute()) {
    http_response_code(201); // 201 Created é a resposta correta para uma criação bem-sucedida
    echo json_encode(["message" => "Registro criado com sucesso", "inserted_id" => $link->insert_id]);
} else {
    http_response_code(500);
    echo json_encode(["error" => "Erro ao inserir registro: " . $stmt->error]);
}

// 4. Fechar o statement
$stmt->close();

// A conexão ($link) é fechada automaticamente pelo PHP ao fim do script.
?>