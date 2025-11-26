<?php
// <!-- k8s-database-exemplo/backend/conexao.php -->
// Definir o nível de relatório de erros
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Leitura das variáveis de ambiente (DB_HOST, DB_USER, DB_PASSWORD, DB_NAME)
// Estas são injetadas no container pelo Kubernetes Deployment (Secret e valores literais)
$servername = getenv('DB_HOST') ?: 'mysql-service'; // Usar 'mysql-service' como fallback, não 'mysql-connection'
$username = getenv('DB_USER') ?: 'appuser'; 
$password = getenv('DB_PASSWORD') ?: 'Senha123'; 
$database = getenv('DB_NAME') ?: 'meubanco';

// Cria a conexão usando a classe mysqli
$link = new mysqli($servername, $username, $password, $database);

// Verifica a conexão
if ($link->connect_error) {
    // Em produção, isso deve ser registrado em log, não exibido diretamente.
    http_response_code(500);
    // Usamos die() para interromper a execução do script em caso de falha crítica.
    die(json_encode(["error" => "Erro de Conexão com o Banco de Dados: " . $link->connect_error]));
}

// Define o charset para utf8mb4, o mesmo configurado no DB, para suportar emojis e caracteres especiais.
$link->set_charset("utf8mb4");

// A conexão ($link) está pronta para ser usada nos outros arquivos PHP.

?>