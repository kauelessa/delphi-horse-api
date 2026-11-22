unit Repository.Produto;

interface

uses
  System.Generics.Collections, Model.Produto, Model.Paginacao;

type
  IProdutoRepository = interface
    ['{4C1E6B2A-8D3F-4E57-9A06-2B7C5D9E1F34}']
    function Listar(const APaginacao: TPaginacao; const ABusca: string; out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto; // só ativos; nil se não achar
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
  end;

  TProdutoRepository = class(TInterfacedObject, IProdutoRepository)
  public
    function Listar(const APaginacao: TPaginacao; const ABusca: string; out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto;
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
    /// WHERE da listagem e valor do parâmetro :BUSCA (nunca concatenado no SQL).
    class function Filtro(const ABusca: string; out ABuscaParam: string): string; static;
  end;

implementation

uses
  System.SysUtils, FireDAC.Comp.Client, FireDAC.Stan.Param, Infra.Conexao;

function LerProduto(AQry: TFDQuery): TProduto;
begin
  Result := TProduto.Create;
  Result.Id := AQry.FieldByName('ID').AsInteger;
  Result.Descricao := AQry.FieldByName('DESCRICAO').AsString;
  Result.Preco := AQry.FieldByName('PRECO').AsCurrency;
  Result.Estoque := AQry.FieldByName('ESTOQUE').AsInteger;
  Result.Ativo := AQry.FieldByName('ATIVO').AsBoolean;
end;

class function TProdutoRepository.Filtro(const ABusca: string; out ABuscaParam: string): string;
begin
  Result := 'WHERE ATIVO = TRUE';
  ABuscaParam := Trim(ABusca);
  if ABuscaParam <> '' then
    Result := Result + ' AND DESCRICAO CONTAINING :BUSCA';
end;

function TProdutoRepository.Listar(const APaginacao: TPaginacao; const ABusca: string;
  out ATotal: Integer): TObjectList<TProduto>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LWhere, LBusca: string;
begin
  LWhere := Filtro(ABusca, LBusca);
  Result := TObjectList<TProduto>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM PRODUTOS ' + LWhere;
      if LBusca <> '' then
        LQry.ParamByName('BUSCA').AsString := LBusca;
      LQry.Open;
      ATotal := LQry.Fields[0].AsInteger;
      LQry.Close;

      LQry.SQL.Text :=
        'SELECT ID, DESCRICAO, PRECO, ESTOQUE, ATIVO FROM PRODUTOS ' + LWhere +
        ' ORDER BY DESCRICAO OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY';
      if LBusca <> '' then
        LQry.ParamByName('BUSCA').AsString := LBusca;
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
    LQry.Open('SELECT ID, DESCRICAO, PRECO, ESTOQUE, ATIVO FROM PRODUTOS WHERE ID = :ID AND ATIVO = TRUE', [AId]);
    if not LQry.IsEmpty then
      Result := LerProduto(LQry);
  finally
    LQry.Free;
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
      'INSERT INTO PRODUTOS (DESCRICAO, PRECO, ESTOQUE) VALUES (:DESCRICAO, :PRECO, :ESTOQUE) RETURNING ID',
      [AProduto.Descricao, AProduto.Preco, AProduto.Estoque]);
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
      'UPDATE PRODUTOS SET DESCRICAO = :DESCRICAO, PRECO = :PRECO, ESTOQUE = :ESTOQUE WHERE ID = :ID',
      [AProduto.Descricao, AProduto.Preco, AProduto.Estoque, AProduto.Id]);
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
