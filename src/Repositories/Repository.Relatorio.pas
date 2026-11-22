unit Repository.Relatorio;

interface

uses
  Model.Relatorio;

type
  // AFim é inclusivo (o dia inteiro); AUsuarioId > 0 restringe ao vendedor
  IRelatorioRepository = interface
    ['{E7A43C19-6B2D-4F80-8D15-9C2E4A7B0F36}']
    function PedidosPorPeriodo(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelPedido>;
    function VendasPorProduto(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVendaProduto>;
    function Visitas(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVisita>;
    function NomeDoUsuario(AUsuarioId: Integer): string;
  end;

  TRelatorioRepository = class(TInterfacedObject, IRelatorioRepository)
  public
    function PedidosPorPeriodo(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelPedido>;
    function VendasPorProduto(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVendaProduto>;
    function Visitas(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVisita>;
    function NomeDoUsuario(AUsuarioId: Integer): string;
  end;

implementation

uses
  System.SysUtils, System.DateUtils, System.Variants, System.Generics.Collections, Data.DB, FireDAC.Comp.Client,
  FireDAC.Stan.Param, Infra.Conexao;

// o fim vira "antes do dia seguinte" para pegar o dia inteiro
procedure Periodo(AQry: TFDQuery; AInicio, AFim: TDateTime; AUsuarioId: Integer);
begin
  AQry.ParamByName('INICIO').AsDateTime := DateOf(AInicio);
  AQry.ParamByName('FIM').AsDateTime := IncDay(DateOf(AFim));
  AQry.ParamByName('USUARIO_ID').AsInteger := AUsuarioId;
end;

function TRelatorioRepository.PedidosPorPeriodo(AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TArray<TLinhaRelPedido>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LLista: TList<TLinhaRelPedido>;
  L: TLinhaRelPedido;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  LLista := TList<TLinhaRelPedido>.Create;
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'SELECT P.ID, P.DATA_PEDIDO, C.NOME, P.STATUS, P.NOTA_NUMERO, P.VALOR_TOTAL ' +
      '  FROM PEDIDOS P JOIN CLIENTES C ON C.ID = P.CLIENTE_ID ' +
      ' WHERE P.DATA_PEDIDO >= :INICIO AND P.DATA_PEDIDO < :FIM ' +
      '   AND (:USUARIO_ID = 0 OR P.USUARIO_ID = :USUARIO_ID) ' +
      ' ORDER BY P.DATA_PEDIDO, P.ID';
    Periodo(LQry, AInicio, AFim, AUsuarioId);
    LQry.Open;
    while not LQry.Eof do
    begin
      L.Id := LQry.Fields[0].AsInteger;
      L.Data := LQry.Fields[1].AsDateTime;
      L.Cliente := LQry.Fields[2].AsString;
      L.Status := LQry.Fields[3].AsString;
      L.NotaNumero := LQry.Fields[4].AsInteger;
      L.Valor := LQry.Fields[5].AsCurrency;
      LLista.Add(L);
      LQry.Next;
    end;
    Result := LLista.ToArray;
  finally
    LLista.Free;
    LQry.Free;
    LCon.Free;
  end;
end;

function TRelatorioRepository.VendasPorProduto(AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TArray<TLinhaRelVendaProduto>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LLista: TList<TLinhaRelVendaProduto>;
  L: TLinhaRelVendaProduto;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  LLista := TList<TLinhaRelVendaProduto>.Create;
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'SELECT PR.DESCRICAO, SUM(I.QUANTIDADE) AS QTD, SUM(I.VALOR_TOTAL) AS VALOR ' +
      '  FROM PEDIDO_ITENS I ' +
      '  JOIN PEDIDOS P ON P.ID = I.PEDIDO_ID ' +
      '  JOIN PRODUTOS PR ON PR.ID = I.PRODUTO_ID ' +
      ' WHERE P.STATUS <> ''CANCELADO'' ' +
      '   AND P.DATA_PEDIDO >= :INICIO AND P.DATA_PEDIDO < :FIM ' +
      '   AND (:USUARIO_ID = 0 OR P.USUARIO_ID = :USUARIO_ID) ' +
      ' GROUP BY PR.DESCRICAO ORDER BY 3 DESC, 1';
    Periodo(LQry, AInicio, AFim, AUsuarioId);
    LQry.Open;
    while not LQry.Eof do
    begin
      L.Produto := LQry.Fields[0].AsString;
      L.Quantidade := LQry.Fields[1].AsInteger;
      L.Valor := LQry.Fields[2].AsCurrency;
      LLista.Add(L);
      LQry.Next;
    end;
    Result := LLista.ToArray;
  finally
    LLista.Free;
    LQry.Free;
    LCon.Free;
  end;
end;

function TRelatorioRepository.Visitas(AInicio, AFim: TDateTime; AUsuarioId: Integer): TArray<TLinhaRelVisita>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LLista: TList<TLinhaRelVisita>;
  L: TLinhaRelVisita;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  LLista := TList<TLinhaRelVisita>.Create;
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'SELECT V.DATA_VISITA, C.NOME, V.MOTIVO, V.OBSERVACAO ' +
      '  FROM VISITAS V JOIN CLIENTES C ON C.ID = V.CLIENTE_ID ' +
      ' WHERE V.DATA_VISITA >= :INICIO AND V.DATA_VISITA < :FIM ' +
      '   AND (:USUARIO_ID = 0 OR V.USUARIO_ID = :USUARIO_ID) ' +
      ' ORDER BY V.DATA_VISITA';
    Periodo(LQry, AInicio, AFim, AUsuarioId);
    LQry.Open;
    while not LQry.Eof do
    begin
      L.Data := LQry.Fields[0].AsDateTime;
      L.Cliente := LQry.Fields[1].AsString;
      L.Motivo := LQry.Fields[2].AsString;
      L.Observacao := LQry.Fields[3].AsString;
      LLista.Add(L);
      LQry.Next;
    end;
    Result := LLista.ToArray;
  finally
    LLista.Free;
    LQry.Free;
    LCon.Free;
  end;
end;

function TRelatorioRepository.NomeDoUsuario(AUsuarioId: Integer): string;
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    Result := VarToStrDef(LCon.ExecSQLScalar('SELECT NOME FROM USUARIOS WHERE ID = :ID', [AUsuarioId]), '');
  finally
    LCon.Free;
  end;
end;

end.
