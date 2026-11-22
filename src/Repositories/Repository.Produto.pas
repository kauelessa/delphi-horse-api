unit Repository.Produto;

interface

uses
  System.Generics.Collections, Model.Produto, Model.Paginacao;

type
  IProdutoRepository = interface
    ['{4C1E6B2A-8D3F-4E57-9A06-2B7C5D9E1F34}']
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto; // só ativos; nil se não achar
    function BuscarPorCodigoBarras(const ACodigo: string): TProduto; // só ativos; nil se não achar
    // id do produto (ativo ou não) que já usa o código; 0 se livre
    function CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Integer;
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
  end;

  TProdutoRepository = class(TInterfacedObject, IProdutoRepository)
  public
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto;
    function BuscarPorCodigoBarras(const ACodigo: string): TProduto;
    function CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Integer;
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
    /// WHERE da listagem e valor do parâmetro :BUSCA (nunca concatenado no SQL).
    class function Filtro(const ABusca: string; out ABuscaParam: string): string; overload; static;
    class function Filtro(const ABusca: string; out ABuscaParam: string;
      const ASync: TFiltroSync): string; overload; static;
  end;

implementation

uses
  System.SysUtils, System.Variants, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, Infra.Conexao;

const
  CAMPOS = 'ID, DESCRICAO, PRECO, ESTOQUE, CODIGO_BARRAS, ATIVO, ATUALIZADO_EM';

// vazio grava NULL: o índice único aceita vários NULL, mas não vários ''
function CodigoOuNulo(const ACodigo: string): Variant;
begin
  if ACodigo = '' then
    Result := Null
  else
    Result := ACodigo;
end;

function OrdemListagem(const ASync: TFiltroSync): string;
begin
  if ASync.Ativo then
    Result := ' ORDER BY ATUALIZADO_EM, ID'
  else
    Result := ' ORDER BY DESCRICAO';
end;

function LerProduto(AQry: TFDQuery): TProduto;
begin
  Result := TProduto.Create;
  Result.Id := AQry.FieldByName('ID').AsInteger;
  Result.Descricao := AQry.FieldByName('DESCRICAO').AsString;
  Result.Preco := AQry.FieldByName('PRECO').AsCurrency;
  Result.Estoque := AQry.FieldByName('ESTOQUE').AsInteger;
  Result.CodigoBarras := Trim(AQry.FieldByName('CODIGO_BARRAS').AsString);
  Result.Ativo := AQry.FieldByName('ATIVO').AsBoolean;
  Result.AtualizadoEm := AQry.FieldByName('ATUALIZADO_EM').AsDateTime;
end;

class function TProdutoRepository.Filtro(const ABusca: string; out ABuscaParam: string): string;
begin
  Result := Filtro(ABusca, ABuscaParam, TFiltroSync.Nenhum);
end;

class function TProdutoRepository.Filtro(const ABusca: string; out ABuscaParam: string;
  const ASync: TFiltroSync): string;
begin
  if ASync.Ativo then
    Result := 'WHERE ATUALIZADO_EM >= :DESDE'
  else
    Result := 'WHERE ATIVO = TRUE';
  ABuscaParam := Trim(ABusca);
  if ABuscaParam <> '' then
    Result := Result + ' AND (DESCRICAO CONTAINING :BUSCA OR CODIGO_BARRAS = :BUSCA_CODIGO)';
end;

function TProdutoRepository.Listar(const APaginacao: TPaginacao; const ABusca: string;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TProduto>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LWhere, LBusca: string;
begin
  LWhere := Filtro(ABusca, LBusca, ASync);
  Result := TObjectList<TProduto>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM PRODUTOS ' + LWhere;
      if ASync.Ativo then
        LQry.ParamByName('DESDE').AsDateTime := ASync.Desde;
      if LBusca <> '' then
      begin
        LQry.ParamByName('BUSCA').AsString := LBusca;
        LQry.ParamByName('BUSCA_CODIGO').AsString := Copy(LBusca, 1, 14);
      end;
      LQry.Open;
      ATotal := LQry.Fields[0].AsInteger;
      LQry.Close;

      LQry.SQL.Text :=
        'SELECT ' + CAMPOS + ' FROM PRODUTOS ' + LWhere + OrdemListagem(ASync) +
        ' OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY';
      if ASync.Ativo then
        LQry.ParamByName('DESDE').AsDateTime := ASync.Desde;
      if LBusca <> '' then
      begin
        LQry.ParamByName('BUSCA').AsString := LBusca;
        LQry.ParamByName('BUSCA_CODIGO').AsString := Copy(LBusca, 1, 14);
      end;
      LQry.ParamByName('OFFSET').AsInteger := APaginacao.Offset;
      LQry.ParamByName('LIMITE').AsInteger := APaginacao.Limite;
      LQry.Open;
      while not LQry.Eof do
      begin
        Result.Add(LerProduto(LQry));
        LQry.Next;
      end;
    finally
      LQry.Free;
      LCon.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TProdutoRepository.BuscarPorId(AId: Integer): TProduto;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT ' + CAMPOS + ' FROM PRODUTOS WHERE ID = :ID AND ATIVO = TRUE', [AId]);
    if not LQry.IsEmpty then
      Result := LerProduto(LQry);
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TProdutoRepository.BuscarPorCodigoBarras(const ACodigo: string): TProduto;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT ' + CAMPOS + ' FROM PRODUTOS WHERE CODIGO_BARRAS = :CODIGO AND ATIVO = TRUE', [ACodigo]);
    if not LQry.IsEmpty then
      Result := LerProduto(LQry);
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TProdutoRepository.CodigoBarrasEmUso(const ACodigo: string; AIgnorarId: Integer): Integer;
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    // inativo também conta: o índice único do banco não olha o ATIVO
    Result := LCon.ExecSQLScalar(
      'SELECT COALESCE(MAX(ID), 0) FROM PRODUTOS WHERE CODIGO_BARRAS = :CODIGO AND ID <> :ID',
      [ACodigo, AIgnorarId]);
  finally
    LCon.Free;
  end;
end;

procedure TProdutoRepository.Inserir(AProduto: TProduto);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open(
      'INSERT INTO PRODUTOS (DESCRICAO, PRECO, ESTOQUE, CODIGO_BARRAS) ' +
      'VALUES (:DESCRICAO, :PRECO, :ESTOQUE, :CODIGO_BARRAS) RETURNING ID',
      [AProduto.Descricao, AProduto.Preco, AProduto.Estoque, CodigoOuNulo(AProduto.CodigoBarras)]);
    AProduto.Id := LQry.FieldByName('ID').AsInteger;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TProdutoRepository.Atualizar(AProduto: TProduto);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL(
      'UPDATE PRODUTOS SET DESCRICAO = :DESCRICAO, PRECO = :PRECO, ESTOQUE = :ESTOQUE, ' +
      'CODIGO_BARRAS = :CODIGO_BARRAS WHERE ID = :ID',
      [AProduto.Descricao, AProduto.Preco, AProduto.Estoque, CodigoOuNulo(AProduto.CodigoBarras), AProduto.Id]);
  finally
    LCon.Free;
  end;
end;

procedure TProdutoRepository.Inativar(AId: Integer);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL('UPDATE PRODUTOS SET ATIVO = FALSE WHERE ID = :ID', [AId]);
  finally
    LCon.Free;
  end;
end;

end.
