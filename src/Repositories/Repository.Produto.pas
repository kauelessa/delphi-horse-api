unit Repository.Produto;

interface

uses
  System.Generics.Collections, Model.Produto, Model.Paginacao;

type
  IProdutoRepository = interface
    ['{4C1E6B2A-8D3F-4E57-9A06-2B7C5D9E1F34}']
    function Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto; // só ativos; nil se não achar
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
  end;

  TProdutoRepository = class(TInterfacedObject, IProdutoRepository)
  public
    function Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TProduto>;
    function BuscarPorId(AId: Integer): TProduto;
    procedure Inserir(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Inativar(AId: Integer);
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

function TProdutoRepository.Listar(const APaginacao: TPaginacao; out ATotal: Integer): TObjectList<TProduto>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := TObjectList<TProduto>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;
      ATotal := LCon.ExecSQLScalar('SELECT COUNT(*) FROM PRODUTOS WHERE ATIVO = TRUE');

      LQry.SQL.Text :=
        'SELECT ID, DESCRICAO, PRECO, ESTOQUE, ATIVO FROM PRODUTOS ' +
        'WHERE ATIVO = TRUE ORDER BY DESCRICAO ' +
        'OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY';
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
