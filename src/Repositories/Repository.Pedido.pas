unit Repository.Pedido;

interface

uses
  System.SysUtils, System.Generics.Collections, Model.Pedido, Model.Paginacao;

type
  IPedidoRepository = interface
    ['{9E2D7F41-3B6A-4C85-B1E0-6F4A2C8D5B17}']
    // sem itens, só o cabeçalho (evita N+1 na listagem)
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido; // com itens; nil se não achar
    function BuscarPorUuid(const AUuid: string): TPedido; // com itens; nil se não achar
    function LerAssinatura(AId: Integer): TBytes; // vazio se não tiver
    // levanta EUuidDuplicado se outro pedido com o mesmo UUID gravou antes
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
    procedure GravarFaturamento(AId, ANumero, ASerie: Integer; const AChave: string; AAutorizadaEm: TDateTime);
    procedure LimparFaturamento(AId: Integer);
  end;

  TPedidoRepository = class(TInterfacedObject, IPedidoRepository)
  private
    function Carregar(const ACondicao: string; const AChave: Variant): TPedido;
  public
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TPedido>;
    function BuscarPorId(AId: Integer): TPedido;
    function BuscarPorUuid(const AUuid: string): TPedido;
    function LerAssinatura(AId: Integer): TBytes;
    /// WHERE da listagem ('' sem filtro); os valores vão por parâmetro.
    class function Filtro(AClienteId: Integer; const ASync: TFiltroSync): string; static;
    procedure Inserir(APedido: TPedido);
    procedure Cancelar(APedido: TPedido);
    procedure GravarFaturamento(AId, ANumero, ASerie: Integer; const AChave: string; AAutorizadaEm: TDateTime);
    procedure LimparFaturamento(AId: Integer);
  end;

implementation

uses
  System.Classes, System.Variants, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Stan.Error,
  Infra.Conexao, Infra.Excecoes;

const
  SQL_CABECALHO =
    'SELECT P.ID, P.CLIENTE_ID, C.NOME AS NOME_CLIENTE, P.DATA_PEDIDO, P.STATUS, P.VALOR_TOTAL, ' +
    '       P.ATUALIZADO_EM, P.UUID, P.USUARIO_ID, U.NOME AS NOME_VENDEDOR, P.LATITUDE, P.LONGITUDE, ' +
    '       P.PRECISAO_M, P.OBSERVACAO, P.ORIGEM, ' +
    '       CASE WHEN P.ASSINATURA IS NULL THEN FALSE ELSE TRUE END AS TEM_ASSINATURA, ' +
    '       P.NOTA_NUMERO, P.NOTA_SERIE, P.NOTA_CHAVE, P.NOTA_AUTORIZADA_EM ' +
    '  FROM PEDIDOS P ' +
    '  JOIN CLIENTES C ON C.ID = P.CLIENTE_ID ' +
    '  LEFT JOIN USUARIOS U ON U.ID = P.USUARIO_ID ';

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
  Result.Uuid := Trim(AQry.FieldByName('UUID').AsString);
  Result.UsuarioId := AQry.FieldByName('USUARIO_ID').AsInteger;
  Result.NomeVendedor := AQry.FieldByName('NOME_VENDEDOR').AsString;
  if not AQry.FieldByName('LATITUDE').IsNull then
    Result.DefinirLocalizacao(AQry.FieldByName('LATITUDE').AsFloat, AQry.FieldByName('LONGITUDE').AsFloat,
      AQry.FieldByName('PRECISAO_M').AsFloat);
  Result.Observacao := AQry.FieldByName('OBSERVACAO').AsString;
  Result.Origem := TOrigemPedido.DeTexto(AQry.FieldByName('ORIGEM').AsString);
  Result.TemAssinatura := AQry.FieldByName('TEM_ASSINATURA').AsBoolean;
  if not AQry.FieldByName('NOTA_NUMERO').IsNull then
    Result.DefinirNota(AQry.FieldByName('NOTA_NUMERO').AsInteger, AQry.FieldByName('NOTA_SERIE').AsInteger,
      Trim(AQry.FieldByName('NOTA_CHAVE').AsString), AQry.FieldByName('NOTA_AUTORIZADA_EM').AsDateTime);
end;

procedure Opcional(AParam: TFDParam; ATipo: TFieldType; const AValor: Variant; ATem: Boolean);
begin
  AParam.DataType := ATipo;
  if ATem then
    AParam.Value := AValor
  else
    AParam.Clear;
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
begin
  Result := Carregar('P.ID = :CHAVE', AId);
end;

function TPedidoRepository.BuscarPorUuid(const AUuid: string): TPedido;
begin
  Result := Carregar('P.UUID = :CHAVE', AUuid);
end;

function TPedidoRepository.LerAssinatura(AId: Integer): TBytes;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT ASSINATURA FROM PEDIDOS WHERE ID = :ID AND ASSINATURA IS NOT NULL', [AId]);
    if not LQry.IsEmpty then
      Result := LQry.Fields[0].AsBytes;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

// ACondicao vem só de BuscarPorId/BuscarPorUuid; o valor vai sempre por parâmetro
function TPedidoRepository.Carregar(const ACondicao: string; const AChave: Variant): TPedido;
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
    LQry.Open(SQL_CABECALHO + 'WHERE ' + ACondicao, [AChave]);
    if LQry.IsEmpty then
      Exit;

    Result := LerPedido(LQry);
    try
      LQry.Open(
        'SELECT I.ID, I.PRODUTO_ID, PR.DESCRICAO, I.QUANTIDADE, I.PRECO_UNITARIO, I.VALOR_TOTAL ' +
        '  FROM PEDIDO_ITENS I ' +
        '  JOIN PRODUTOS PR ON PR.ID = I.PRODUTO_ID ' +
        ' WHERE I.PEDIDO_ID = :ID ORDER BY I.ID', [Result.Id]);
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
  LStream: TBytesStream;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LCon.StartTransaction;
    try
      LQry.SQL.Text :=
        'INSERT INTO PEDIDOS (CLIENTE_ID, DATA_PEDIDO, STATUS, VALOR_TOTAL, UUID, USUARIO_ID, ' +
        '  LATITUDE, LONGITUDE, PRECISAO_M, OBSERVACAO, ORIGEM, ASSINATURA) ' +
        'VALUES (:CLIENTE_ID, :DATA_PEDIDO, :STATUS, :VALOR_TOTAL, :UUID, :USUARIO_ID, ' +
        '  :LATITUDE, :LONGITUDE, :PRECISAO_M, :OBSERVACAO, :ORIGEM, :ASSINATURA) ' +
        'RETURNING ID, ATUALIZADO_EM';
      LQry.ParamByName('CLIENTE_ID').AsInteger := APedido.ClienteId;
      LQry.ParamByName('DATA_PEDIDO').AsDateTime := APedido.Data;
      LQry.ParamByName('STATUS').AsString := APedido.Status.ToString;
      LQry.ParamByName('VALOR_TOTAL').AsCurrency := APedido.ValorTotal;
      Opcional(LQry.ParamByName('UUID'), ftString, APedido.Uuid, APedido.Uuid <> '');
      Opcional(LQry.ParamByName('USUARIO_ID'), ftInteger, APedido.UsuarioId, APedido.UsuarioId > 0);
      Opcional(LQry.ParamByName('LATITUDE'), ftFloat, APedido.Latitude, APedido.TemLocalizacao);
      Opcional(LQry.ParamByName('LONGITUDE'), ftFloat, APedido.Longitude, APedido.TemLocalizacao);
      Opcional(LQry.ParamByName('PRECISAO_M'), ftFloat, APedido.Precisao, APedido.TemLocalizacao);
      Opcional(LQry.ParamByName('OBSERVACAO'), ftWideString, APedido.Observacao, APedido.Observacao <> '');
      LQry.ParamByName('ORIGEM').AsString := APedido.Origem.ToString;
      if Length(APedido.Assinatura) > 0 then
      begin
        LStream := TBytesStream.Create(APedido.Assinatura);
        try
          LQry.ParamByName('ASSINATURA').LoadFromStream(LStream, ftBlob);
        finally
          LStream.Free;
        end;
      end
      else
        Opcional(LQry.ParamByName('ASSINATURA'), ftBlob, Null, False);

      try
        LQry.Open;
      except
        // reenvio do app chegando junto com o primeiro: o índice único do UUID segura.
        // Com a outra transação ainda aberta o Firebird diz "visible to active transactions"
        // e o FireDAC não classifica como ekUKViolated, por isso vale o nome do índice.
        on E: EFDDBEngineException do
          if E.Message.ToUpper.Contains('UQ_PEDIDOS_UUID') then
            raise EUuidDuplicado.Create(E.Message)
          else
            raise;
      end;
      APedido.Id := LQry.FieldByName('ID').AsInteger;
      APedido.AtualizadoEm := LQry.FieldByName('ATUALIZADO_EM').AsDateTime;
      APedido.TemAssinatura := Length(APedido.Assinatura) > 0;

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
      // o STATUS no WHERE segura dois cancelamentos simultâneos devolvendo estoque em dobro;
      // a NOTA_NUMERO segura o faturamento que chegou entre a conferência e aqui
      if LCon.ExecSQL(
        'UPDATE PEDIDOS SET STATUS = ''CANCELADO'' ' +
        ' WHERE ID = :ID AND STATUS = ''ABERTO'' AND NOTA_NUMERO IS NULL',
        [APedido.Id]) = 0 then
        raise EConflito.Create('Pedido já cancelado ou faturado; atualize e tente de novo.');

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

procedure TPedidoRepository.GravarFaturamento(AId, ANumero, ASerie: Integer; const AChave: string;
  AAutorizadaEm: TDateTime);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    // mesmas condições do Service, de novo no WHERE: se cancelaram ou faturaram com
    // outra nota nesse meio tempo, não grava
    if LCon.ExecSQL(
      'UPDATE PEDIDOS SET NOTA_NUMERO = :NUMERO, NOTA_SERIE = :SERIE, NOTA_CHAVE = :CHAVE, ' +
      '  NOTA_AUTORIZADA_EM = :AUTORIZADA ' +
      ' WHERE ID = :ID AND STATUS = ''ABERTO'' AND (NOTA_CHAVE IS NULL OR NOTA_CHAVE = :CHAVE_ATUAL)',
      [ANumero, ASerie, AChave, AAutorizadaEm, AId, AChave]) = 0 then
      raise EConflito.Create('Pedido mudou enquanto era faturado; atualize e tente de novo.');
  finally
    LCon.Free;
  end;
end;

procedure TPedidoRepository.LimparFaturamento(AId: Integer);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL('UPDATE PEDIDOS SET NOTA_NUMERO = NULL, NOTA_SERIE = NULL, NOTA_CHAVE = NULL, ' +
      'NOTA_AUTORIZADA_EM = NULL WHERE ID = :ID', [AId]);
  finally
    LCon.Free;
  end;
end;

end.
