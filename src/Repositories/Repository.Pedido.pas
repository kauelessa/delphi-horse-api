unit Repository.Pedido;

interface

uses
  System.Generics.Collections, Model.Pedido, Model.Paginacao;

type
  IPedidoRepository = interface
    ['{9E2D7F41-3B6A-4C85-B1E0-6F4A2C8D5B17}']
    // sem itens, só o cabeçalho (evita N+1 na listagem)
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido; // com itens; nil se não achar
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
  end;

  TPedidoRepository = class(TInterfacedObject, IPedidoRepository)
  public
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido;
    /// WHERE da listagem ('' sem filtro); os valores vão por parâmetro.
    class function Filtro(AClienteId: Integer; const ASync: TFiltroSync): string; static;
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
  end;

implementation

uses
  System.SysUtils, FireDAC.Comp.Client, FireDAC.Stan.Param, Infra.Conexao, Infra.Excecoes;

const
  SQL_CABECALHO =
    'SELECT P.ID, P.CLIENTE_ID, C.NOME AS NOME_CLIENTE, P.DATA_PEDIDO, P.STATUS, P.VALOR_TOTAL, ' +
    '       P.ATUALIZADO_EM ' +
    '  FROM PEDIDOS P ' +
    '  JOIN CLIENTES C ON C.ID = P.CLIENTE_ID ';

function LerPedido(AQry: TFDQuery): TPedido;
begin
  Result := TPedido.Create;
  Result.Id := AQry.FieldByName('ID').AsInteger;
  Result.ClienteId := AQry.FieldByName('CLIENTE_ID').AsInteger;
  Result.NomeCliente := AQry.FieldByName('NOME_CLIENTE').AsString;
  Result.Data := AQry.FieldByName('DATA_PEDIDO').AsDateTime;
  Result.Status := TStatusPedido.DeTexto(AQry.FieldByName('STATUS').AsString);
  Result.ValorTotal := AQry.FieldByName('VALOR_TOTAL').AsCurrency;
  Result.AtualizadoEm := AQry.FieldByName('ATUALIZADO_EM').AsDateTime;
end;

class function TPedidoRepository.Filtro(AClienteId: Integer; const ASync: TFiltroSync): string;
var
  LCondicoes: TArray<string>;
begin
  LCondicoes := [];
  if AClienteId > 0 then
    LCondicoes := LCondicoes + ['P.CLIENTE_ID = :CLIENTE_ID'];
  if ASync.UsuarioId > 0 then
    LCondicoes := LCondicoes + ['P.USUARIO_ID = :USUARIO_ID'];
  if ASync.Ativo then
    LCondicoes := LCondicoes + ['P.ATUALIZADO_EM >= :DESDE'];

  if Length(LCondicoes) = 0 then
    Result := ''
  else
    Result := 'WHERE ' + string.Join(' AND ', LCondicoes) + ' ';
end;

function TPedidoRepository.Listar(const APaginacao: TPaginacao; AClienteId: Integer;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TPedido>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LFiltro: string;

  procedure PreencherFiltro;
  begin
    if AClienteId > 0 then
      LQry.ParamByName('CLIENTE_ID').AsInteger := AClienteId;
    if ASync.UsuarioId > 0 then
      LQry.ParamByName('USUARIO_ID').AsInteger := ASync.UsuarioId;
    if ASync.Ativo then
      LQry.ParamByName('DESDE').AsDateTime := ASync.Desde;
  end;

begin
  LFiltro := Filtro(AClienteId, ASync);

  Result := TObjectList<TPedido>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;

      LQry.SQL.Text := 'SELECT COUNT(*) FROM PEDIDOS P ' + LFiltro;
      PreencherFiltro;
      LQry.Open;
      ATotal := LQry.Fields[0].AsInteger;
      LQry.Close;

      if ASync.Ativo then
        LQry.SQL.Text := SQL_CABECALHO + LFiltro + 'ORDER BY P.ATUALIZADO_EM, P.ID '
      else
        LQry.SQL.Text := SQL_CABECALHO + LFiltro + 'ORDER BY P.ID DESC ';
      LQry.SQL.Add('OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY');
      PreencherFiltro;
      LQry.ParamByName('OFFSET').AsInteger := APaginacao.Offset;
      LQry.ParamByName('LIMITE').AsInteger := APaginacao.Limite;
      LQry.Open;
      while not LQry.Eof do
      begin
        Result.Add(LerPedido(LQry));
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

function TPedidoRepository.BuscarPorId(AId: Integer): TPedido;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LItem: TPedidoItem;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open(SQL_CABECALHO + 'WHERE P.ID = :ID', [AId]);
    if LQry.IsEmpty then
      Exit;

    Result := LerPedido(LQry);
    try
      LQry.Open(
        'SELECT I.ID, I.PRODUTO_ID, PR.DESCRICAO, I.QUANTIDADE, I.PRECO_UNITARIO, I.VALOR_TOTAL ' +
        '  FROM PEDIDO_ITENS I ' +
        '  JOIN PRODUTOS PR ON PR.ID = I.PRODUTO_ID ' +
        ' WHERE I.PEDIDO_ID = :ID ORDER BY I.ID', [AId]);
      while not LQry.Eof do
      begin
        LItem := Result.AdicionarItem(LQry.FieldByName('PRODUTO_ID').AsInteger,
          LQry.FieldByName('QUANTIDADE').AsInteger);
        LItem.Id := LQry.FieldByName('ID').AsInteger;
        LItem.DescricaoProduto := LQry.FieldByName('DESCRICAO').AsString;
        LItem.PrecoUnitario := LQry.FieldByName('PRECO_UNITARIO').AsCurrency;
        LItem.ValorTotal := LQry.FieldByName('VALOR_TOTAL').AsCurrency;
        LQry.Next;
      end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TPedidoRepository.Inserir(APedido: TPedido);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LItem: TPedidoItem;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LCon.StartTransaction;
    try
      LQry.Open(
        'INSERT INTO PEDIDOS (CLIENTE_ID, DATA_PEDIDO, STATUS, VALOR_TOTAL) ' +
        'VALUES (:CLIENTE_ID, :DATA_PEDIDO, :STATUS, :VALOR_TOTAL) RETURNING ID',
        [APedido.ClienteId, APedido.Data, APedido.Status.ToString, APedido.ValorTotal]);
      APedido.Id := LQry.Fields[0].AsInteger;

      for LItem in APedido.Itens do
      begin
        // O Service já conferiu o estoque, mas entre a conferência e aqui outro
        // pedido pode ter levado. A condição no WHERE garante que nunca fica
        // negativo: se não atualizou nada, é porque não tem mais.
        if LCon.ExecSQL(
          'UPDATE PRODUTOS SET ESTOQUE = ESTOQUE - :QTD ' +
          ' WHERE ID = :ID AND ATIVO = TRUE AND ESTOQUE >= :QTD_MINIMA',
          [LItem.Quantidade, LItem.ProdutoId, LItem.Quantidade]) = 0 then
          raise ERegraNegocio.CreateFmt('Estoque insuficiente para "%s".', [LItem.DescricaoProduto]);

        LQry.Open(
          'INSERT INTO PEDIDO_ITENS (PEDIDO_ID, PRODUTO_ID, QUANTIDADE, PRECO_UNITARIO, VALOR_TOTAL) ' +
          'VALUES (:PEDIDO_ID, :PRODUTO_ID, :QUANTIDADE, :PRECO_UNITARIO, :VALOR_TOTAL) RETURNING ID',
          [APedido.Id, LItem.ProdutoId, LItem.Quantidade, LItem.PrecoUnitario, LItem.ValorTotal]);
        LItem.Id := LQry.Fields[0].AsInteger;
      end;

      LCon.Commit;
    except
      LCon.Rollback;
      APedido.Id := 0;
      raise;
    end;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TPedidoRepository.Cancelar(APedido: TPedido);
var
  LCon: TFDConnection;
  LItem: TPedidoItem;
begin
  LCon := TConexao.Criar;
  try
    LCon.StartTransaction;
    try
      // o STATUS no WHERE segura dois cancelamentos simultâneos devolvendo estoque em dobro
      if LCon.ExecSQL(
        'UPDATE PEDIDOS SET STATUS = ''CANCELADO'' WHERE ID = :ID AND STATUS = ''ABERTO''',
        [APedido.Id]) = 0 then
        raise ERegraNegocio.Create('Pedido já está cancelado.');

      for LItem in APedido.Itens do
        LCon.ExecSQL('UPDATE PRODUTOS SET ESTOQUE = ESTOQUE + :QTD WHERE ID = :ID',
          [LItem.Quantidade, LItem.ProdutoId]);

      LCon.Commit;
    except
      LCon.Rollback;
      raise;
    end;
  finally
    LCon.Free;
  end;
end;

end.
