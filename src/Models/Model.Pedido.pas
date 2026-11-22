unit Model.Pedido;

interface

uses
  System.Generics.Collections;

type
  TStatusPedido = (spAberto, spCancelado);

  TStatusPedidoHelper = record helper for TStatusPedido
    function ToString: string;
    class function DeTexto(const AValor: string): TStatusPedido; static;
  end;

  TPedidoItem = class
  private
    FId: Integer;
    FProdutoId: Integer;
    FDescricaoProduto: string;
    FQuantidade: Integer;
    FPrecoUnitario: Currency;
    FValorTotal: Currency;
  public
    property Id: Integer read FId write FId;
    property ProdutoId: Integer read FProdutoId write FProdutoId;
    property DescricaoProduto: string read FDescricaoProduto write FDescricaoProduto;
    property Quantidade: Integer read FQuantidade write FQuantidade;
    property PrecoUnitario: Currency read FPrecoUnitario write FPrecoUnitario;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
  end;

  TPedido = class
  private
    FId: Integer;
    FClienteId: Integer;
    FNomeCliente: string;
    FData: TDateTime;
    FStatus: TStatusPedido;
    FValorTotal: Currency;
    FAtualizadoEm: TDateTime;
    FItens: TObjectList<TPedidoItem>;
  public
    constructor Create;
    destructor Destroy; override;
    function AdicionarItem(AProdutoId, AQuantidade: Integer): TPedidoItem;

    property Id: Integer read FId write FId;
    property ClienteId: Integer read FClienteId write FClienteId;
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    property Data: TDateTime read FData write FData;
    property Status: TStatusPedido read FStatus write FStatus;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
    property Itens: TObjectList<TPedidoItem> read FItens;
  end;

implementation

uses
  System.SysUtils;

{ TStatusPedidoHelper }

function TStatusPedidoHelper.ToString: string;
begin
  case Self of
    spAberto: Result := 'ABERTO';
    spCancelado: Result := 'CANCELADO';
  end;
end;

class function TStatusPedidoHelper.DeTexto(const AValor: string): TStatusPedido;
begin
  if SameText(AValor, 'ABERTO') then
    Result := spAberto
  else if SameText(AValor, 'CANCELADO') then
    Result := spCancelado
  else
    raise EConvertError.CreateFmt('Status de pedido desconhecido: %s', [AValor]);
end;

{ TPedido }

constructor TPedido.Create;
begin
  inherited;
  FItens := TObjectList<TPedidoItem>.Create(True);
end;

destructor TPedido.Destroy;
begin
  FItens.Free;
  inherited;
end;

function TPedido.AdicionarItem(AProdutoId, AQuantidade: Integer): TPedidoItem;
begin
  Result := TPedidoItem.Create;
  Result.ProdutoId := AProdutoId;
  Result.Quantidade := AQuantidade;
  FItens.Add(Result);
end;

end.
