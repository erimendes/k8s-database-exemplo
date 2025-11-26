-- k8s-database-exemplo/database/sql.sql
-- Adiciona PRIMARY KEY, AUTO_INCREMENT e restrições NOT NULL para robustez.
-- Usa VARCHAR(255) para a mensagem, mais comum.
-- Define o charset para utf8mb4, suportando emojis e caracteres internacionais.
CREATE TABLE IF NOT EXISTS mensagens (
    id INT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(50) NOT NULL,
    mensagem VARCHAR(255),
    -- Define 'id' como chave primária
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Exemplo de inserção para testar
INSERT INTO mensagens (nome, mensagem) VALUES ('Eri Mendes', 'Olá, mundo! Esta é a primeira mensagem.');