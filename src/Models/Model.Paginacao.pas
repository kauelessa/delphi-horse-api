unit Model.Paginacao;

interface

type
  TPaginacao = record
    Pagina: Integer;
    Limite: Integer;
    function Offset: Integer;
    // pagina < 1 vira 1; limite fora de 1..100 cai no padrão / no máximo
    class function Criar(APagina, ALimite: Integer): TPaginacao; static;
  end;

const
  LIMITE_PADRAO = 20;
  LIMITE_MAXIMO = 100;

implementation

class function TPaginacao.Criar(APagina, ALimite: Integer): TPaginacao;
begin
  Result.Pagina := APagina;
  if Result.Pagina < 1 then
    Result.Pagina := 1;

  Result.Limite := ALimite;
  if Result.Limite < 1 then
    Result.Limite := LIMITE_PADRAO
  else if Result.Limite > LIMITE_MAXIMO then
    Result.Limite := LIMITE_MAXIMO;
end;

function TPaginacao.Offset: Integer;
begin
  Result := (Pagina - 1) * Limite;
end;

end.
