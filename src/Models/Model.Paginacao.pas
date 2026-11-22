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

  { Filtro da sincronização incremental do app. Desde só vale com Ativo = True:
    aí a listagem traz também os inativos/cancelados alterados desde então. }
  TFiltroSync = record
    Ativo: Boolean;
    Desde: TDateTime;
    UsuarioId: Integer; // > 0 restringe ao vendedor (pedidos, visitas)
    class function Nenhum: TFiltroSync; static;
    class function APartirDe(ADesde: TDateTime): TFiltroSync; static;
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

class function TFiltroSync.Nenhum: TFiltroSync;
begin
  Result.Ativo := False;
  Result.Desde := 0;
  Result.UsuarioId := 0;
end;

class function TFiltroSync.APartirDe(ADesde: TDateTime): TFiltroSync;
begin
  Result := Nenhum;
  Result.Ativo := True;
  Result.Desde := ADesde;
end;

function TPaginacao.Offset: Integer;
begin
  Result := (Pagina - 1) * Limite;
end;

end.
