/*
  002 - Usuário inicial para ambiente de DESENVOLVIMENTO
  Login: admin   Senha: admin123

  NÃO execute este script em produção. Se executar por engano,
  troque a senha imediatamente.
*/

INSERT INTO USUARIOS (NOME, LOGIN, SENHA_HASH, ATIVO)
VALUES (
  'Administrador',
  'admin',
  'pbkdf2-sha256$100000$IzS+iB9uBT30hcFZYWL/Jw==$VtlDe4f/jVAE6YE2tKYNad2Gz/96gLlv5+fV2VFeaI4=',
  TRUE
);

COMMIT;
