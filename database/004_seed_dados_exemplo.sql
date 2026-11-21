/*
  004 - Dados de exemplo para DESENVOLVIMENTO (clientes e produtos)
  Documentos fictícios, mas com dígitos verificadores válidos.
*/

INSERT INTO CLIENTES (NOME, DOCUMENTO, EMAIL, TELEFONE)
VALUES ('Maria Souza', '52998224725', 'maria@exemplo.com', '11988887777');

INSERT INTO CLIENTES (NOME, DOCUMENTO, EMAIL, TELEFONE)
VALUES ('Comercial Exemplo Ltda', '11222333000181', 'contato@exemplo.com', '1133334444');

INSERT INTO PRODUTOS (DESCRICAO, PRECO, ESTOQUE) VALUES ('Teclado mecânico', 349.90, 15);
INSERT INTO PRODUTOS (DESCRICAO, PRECO, ESTOQUE) VALUES ('Mouse sem fio', 129.90, 40);
INSERT INTO PRODUTOS (DESCRICAO, PRECO, ESTOQUE) VALUES ('Monitor 27"', 1599.00, 5);

COMMIT;
