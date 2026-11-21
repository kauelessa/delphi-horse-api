unit Controller.Pedido;

interface

type
  TControllerPedido = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils, System.Generics.Collections,
  Horse, Horse.Commons, Model.Pedido, Model.Paginacao, Repository.Cliente,
  Repository.Produto, Repository.Pedido, Service.Pedido, Controller.Utils, Infra.Excecoes;

function Service: IPedidoService;
begin
  Result := TPedidoService.Create(TClienteRepository.Create, TProdutoRepository.Create,
    TPedidoRepository.Create);
end;

function PedidoParaJSON(APedido: TPedido; AComItens: Boolean): TJSONObject;
var
  LItens: TJSONArray;
  LItem: TPedidoItem;
begin
  Result := TJSONObject.Create
    .AddPair('id', TJSONNumber.Create(APedido.Id))
    .AddPair('cliente', TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(APedido.ClienteId))
      .AddPair('nome', APedido.NomeCliente))
    .AddPair('data', DateToISO8601(APedido.Data, False))
    .AddPair('status', APedido.Status.ToString)
    .AddPair('valorTotal', NumeroJSON(APedido.ValorTotal));

  if not AComItens then
    Exit;

  LItens := TJSONArray.Create;
  Result.AddPair('itens', LItens);
  for LItem in APedido.Itens do
    LItens.AddElement(TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(LItem.Id))
      .AddPair('produtoId', TJSONNumber.Create(LItem.ProdutoId))
      .AddPair('descricao', LItem.DescricaoProduto)
      .AddPair('quantidade', TJSONNumber.Create(LItem.Quantidade))
      .AddPair('precoUnitario', NumeroJSON(LItem.PrecoUnitario))
      .AddPair('valorTotal', NumeroJSON(LItem.ValorTotal)));
end;

// { "clienteId": 1, "itens": [ { "produtoId": 2, "quantidade": 3 } ] }
function PedidoDoJSON(AJson: TJSONObject): TPedido;
var
  LItens: TJSONValue;
  LItem: TJSONValue;
begin
  LItens := AJson.GetValue('itens');
  if not (LItens is TJSONArray) then
    raise ERequisicaoInvalida.Create('"itens" deve ser uma lista.');

  Result := TPedido.Create;
  try
    Result.ClienteId := LerInteiro(AJson, 'clienteId');
    for LItem in TJSONArray(LItens) do
    begin
      if not (LItem is TJSONObject) then
        raise ERequisicaoInvalida.Create('Cada item deve ser um objeto com produtoId e quantidade.');
      Result.AdicionarItem(LerInteiro(TJSONObject(LItem), 'produtoId'),
        LerInteiro(TJSONObject(LItem), 'quantidade'));
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure Listar(AReq: THorseRequest; ARes: THorseResponse);
var
  LPag: TPaginacao;
  LTotal: Integer;
  LLista: TObjectList<TPedido>;
  LDados: TJSONArray;
  LPedido: TPedido;
begin
  LPag := PaginacaoDaQuery(AReq);
  LLista := Service.Listar(LPag,
    AReq.Query.Field('clienteId').InvalidFormatMessage('"clienteId" deve ser um número.').AsInteger,
    LTotal);
  try
    LDados := TJSONArray.Create;
    for LPedido in LLista do
      LDados.AddElement(PedidoParaJSON(LPedido, False));
    ARes.Send<TJSONObject>(RespostaPaginada(LDados, LPag, LTotal));
  finally
    LLista.Free;
  end;
end;

procedure Buscar(AReq: THorseRequest; ARes: THorseResponse);
var
  LPedido: TPedido;
begin
  LPedido := Service.Buscar(IdDaRota(AReq));
  try
    ARes.Send<TJSONObject>(PedidoParaJSON(LPedido, True));
  finally
    LPedido.Free;
  end;
end;

procedure Criar(AReq: THorseRequest; ARes: THorseResponse);
var
  LPedido: TPedido;
begin
  LPedido := PedidoDoJSON(CorpoJSON(AReq));
  try
    Service.Criar(LPedido);
    ARes.Send<TJSONObject>(PedidoParaJSON(LPedido, True)).Status(THTTPStatus.Created);
  finally
    LPedido.Free;
  end;
end;

procedure Cancelar(AReq: THorseRequest; ARes: THorseResponse);
var
  LPedido: TPedido;
begin
  LPedido := Service.Cancelar(IdDaRota(AReq));
  try
    ARes.Send<TJSONObject>(PedidoParaJSON(LPedido, True));
  finally
    LPedido.Free;
  end;
end;

class procedure TControllerPedido.Registrar;
begin
  THorse.Route('/pedidos')
    .Get(Listar)
    .Post(Criar);

  THorse.Get('/pedidos/:id', Buscar);
  // cancelar é uma ação, não uma troca de recurso inteiro: PATCH num sub-recurso
  THorse.Patch('/pedidos/:id/cancelar', Cancelar);
end;

end.
