unit Model.Pedido;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TStatusPedido = (spAberto, spCancelado);

  // API = criado direto na API (cliente VCL, Postman); APP = veio do app de força de vendas
  TOrigemPedido = (opApi, opApp);

  TOrigemPedidoHelper = record helper for TOrigemPedido
    function ToString: string;
    class function DeTexto(const AValor: string): TOrigemPedido; static;
  end;

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
    FUuid: string;
    FUsuarioId: Integer;
    FNomeVendedor: string;
    FLatitude: Double;
    FLongitude: Double;
    FPrecisao: Double;
    FTemLocalizacao: Boolean;
    FObservacao: string;
    FOrigem: TOrigemPedido;
    FAssinatura: TBytes;
    FTemAssinatura: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function AdicionarItem(AProdutoId, AQuantidade: Integer): TPedidoItem;
    procedure DefinirLocalizacao(ALatitude, ALongitude, APrecisao: Double);
    // cópia completa, com itens (usada quando o pedido já existia pelo UUID)
    procedure Assign(AOrigem: TPedido);

    property Id: Integer read FId write FId;
    property ClienteId: Integer read FClienteId write FClienteId;
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    property Data: TDateTime read FData write FData;
    property Status: TStatusPedido read FStatus write FStatus;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;
    property Uuid: string read FUuid write FUuid;
    property UsuarioId: Integer read FUsuarioId write FUsuarioId; // vendedor; 0 nos antigos
    property NomeVendedor: string read FNomeVendedor write FNomeVendedor;
    property Latitude: Double read FLatitude;
    property Longitude: Double read FLongitude;
    property Precisao: Double read FPrecisao; // metros
    property TemLocalizacao: Boolean read FTemLocalizacao;
    property Observacao: string read FObservacao write FObservacao;
    property Origem: TOrigemPedido read FOrigem write FOrigem;
    // PNG; só vem preenchida na criação. Na leitura do banco vale TemAssinatura.
    property Assinatura: TBytes read FAssinatura write FAssinatura;
    property TemAssinatura: Boolean read FTemAssinatura write FTemAssinatura;
    property Itens: TObjectList<TPedidoItem> read FItens;
  end;

implementation

{ TOrigemPedidoHelper }

function TOrigemPedidoHelper.ToString: string;
begin
  case Self of
    opApi: Result := 'API';
    opApp: Result := 'APP';
  end;
end;

class function TOrigemPedidoHelper.DeTexto(const AValor: string): TOrigemPedido;
begin
  if SameText(AValor, 'APP') then
    Result := opApp
  else
    Result := opApi;
end;

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

procedure TPedido.DefinirLocalizacao(ALatitude, ALongitude, APrecisao: Double);
begin
  FLatitude := ALatitude;
  FLongitude := ALongitude;
  FPrecisao := APrecisao;
  FTemLocalizacao := True;
end;

procedure TPedido.Assign(AOrigem: TPedido);
var
  LItem, LNovo: TPedidoItem;
begin
  FId := AOrigem.Id;
  FClienteId := AOrigem.ClienteId;
  FNomeCliente := AOrigem.NomeCliente;
  FData := AOrigem.Data;
  FStatus := AOrigem.Status;
  FValorTotal := AOrigem.ValorTotal;
  FAtualizadoEm := AOrigem.AtualizadoEm;
  FUuid := AOrigem.Uuid;
  FUsuarioId := AOrigem.UsuarioId;
  FNomeVendedor := AOrigem.NomeVendedor;
  FLatitude := AOrigem.Latitude;
  FLongitude := AOrigem.Longitude;
  FPrecisao := AOrigem.Precisao;
  FTemLocalizacao := AOrigem.TemLocalizacao;
  FObservacao := AOrigem.Observacao;
  FOrigem := AOrigem.Origem;
  FAssinatura := Copy(AOrigem.Assinatura);
  FTemAssinatura := AOrigem.TemAssinatura;

  FItens.Clear;
  for LItem in AOrigem.Itens do
  begin
    LNovo := AdicionarItem(LItem.ProdutoId, LItem.Quantidade);
    LNovo.Id := LItem.Id;
    LNovo.DescricaoProduto := LItem.DescricaoProduto;
    LNovo.PrecoUnitario := LItem.PrecoUnitario;
    LNovo.ValorTotal := LItem.ValorTotal;
  end;
end;

function TPedido.AdicionarItem(AProdutoId, AQuantidade: Integer): TPedidoItem;
begin
  Result := TPedidoItem.Create;
  Result.ProdutoId := AProdutoId;
  Result.Quantidade := AQuantidade;
  FItens.Add(Result);
end;

end.
