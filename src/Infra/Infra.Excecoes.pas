unit Infra.Excecoes;

// Exceções da aplicação. Cada uma carrega o status HTTP correspondente,
// que o middleware Infra.Middleware.Erros usa para montar a resposta
// no formato { "erro": "mensagem" }.

interface

uses
  System.SysUtils;

type
  EApiErro = class(Exception)
  public
    function Status: Integer; virtual; abstract;
  end;

  { 400 - requisição malformada ou campos obrigatórios ausentes }
  ERequisicaoInvalida = class(EApiErro)
  public
    function Status: Integer; override;
  end;

  { 401 - não autenticado ou credenciais inválidas }
  ENaoAutorizado = class(EApiErro)
  public
    function Status: Integer; override;
  end;

  { 404 - recurso não encontrado }
  ENaoEncontrado = class(EApiErro)
  public
    function Status: Integer; override;
  end;

  { 422 - dados válidos sintaticamente, mas que violam regra de negócio }
  ERegraNegocio = class(EApiErro)
  public
    function Status: Integer; override;
  end;

  { Índice único de UUID estourou: outra requisição com o mesmo UUID gravou
    antes (reenvio do app). Não vira resposta HTTP; o Service trata. }
  EUuidDuplicado = class(Exception);

implementation

function ERequisicaoInvalida.Status: Integer;
begin
  Result := 400;
end;

function ENaoAutorizado.Status: Integer;
begin
  Result := 401;
end;

function ENaoEncontrado.Status: Integer;
begin
  Result := 404;
end;

function ERegraNegocio.Status: Integer;
begin
  Result := 422;
end;

end.
