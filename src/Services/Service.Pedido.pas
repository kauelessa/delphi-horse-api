unit Service.Pedido;

interface

uses
  System.Generics.Collections,
  Model.Pedido,
  Model.Paginacao,
  Repository.Cliente,
  Repository.Produto,
  Repository.Pedido,
  Repository.Relogio;

type
  IPedidoService = interface
    ['{2F6B8D04-A9C3-4E71-95B2-C7E1D3F0A869}']
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TPedido>;
    function Buscar(AId: Integer): TPedido;
    procedure Criar(APedido: TPedido);
    function Cancelar(AId: Integer): TPedido;
  end;

  TPedidoService = class(TInterfacedObject, IPedidoService)
  private
    FClientes: IClienteRepository;
    FProdutos: IProdutoRepository;
    FPedidos: IPedidoRepository;
    FRelogio: IRelogioRepository;
    procedure ValidarCliente(APedido: TPedido);
    procedure PrepararItens(APedido: TPedido);
  public
    constructor Create(const AClientes: IClienteRepository;
      const AProdutos: IProdutoRepository; const APedidos: IPedidoRepository;
      const ARelogio: IRelogioRepository = nil);

    { AClienteId = 0 lista os pedidos de todos os clientes. }
    function Listar(const APaginacao: TPaginacao; AClienteId: Integer; const ASync: TFiltroSync;
      out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TPedido>;
    function Buscar(AId: Integer): TPedido;

    { Recebe o pedido apenas com ClienteId e itens (ProdutoId + Quantidade).
      Valida cliente, produtos e estoque, copia o preço atual de cada produto
      para o item (o pedido não muda se o preço do produto mudar depois),
      calcula os totais e grava. A baixa de estoque acontece na mesma
      transação da gravação, dentro do repositório. }
    procedure Criar(APedido: TPedido);

    { Só pedidos ABERTOS podem ser cancelados; o estoque dos itens é devolvido.
      Retorna o pedido já com o novo status (o chamador libera). }
    function Cancelar(AId: Integer): TPedido;
  end;

implementation

uses
  System.SysUtils,
  Model.Cliente,
  Model.Produto,
  Infra.Excecoes;

constructor TPedidoService.Create(const AClientes: IClienteRepository;
  const AProdutos: IProdutoRepository; const APedidos: IPedidoRepository;
  const ARelogio: IRelogioRepository);
begin
  inherited Create;
  FRelogio := ARelogio;
  FClientes := AClientes;
  FProdutos := AProdutos;
  FPedidos := APedidos;
end;

function TPedidoService.Listar(const APaginacao: TPaginacao; AClienteId: Integer;
  const ASync: TFiltroSync; out ATotal: Integer; out AServidorEm: TDateTime): TObjectList<TPedido>;
begin
  AServidorEm := MarcaDeSincronizacao(FRelogio);
  Result := FPedidos.Listar(APaginacao, AClienteId, ASync, ATotal);
end;

function TPedidoService.Buscar(AId: Integer): TPedido;
begin
  Result := FPedidos.BuscarPorId(AId);
  if Result = nil then
    raise ENaoEncontrado.CreateFmt('Pedido %d não encontrado.', [AId]);
end;

procedure TPedidoService.ValidarCliente(APedido: TPedido);
var
  LCliente: TCliente;
begin
  if APedido.ClienteId <= 0 then
    raise ERequisicaoInvalida.Create('Informe o cliente do pedido.');

  LCliente := FClientes.BuscarPorId(APedido.ClienteId);
  try
    if LCliente = nil then
      raise ERegraNegocio.CreateFmt('Cliente %d não encontrado ou inativo.', [APedido.ClienteId]);
    APedido.NomeCliente := LCliente.Nome;
  finally
    LCliente.Free;
  end;
end;

procedure TPedidoService.PrepararItens(APedido: TPedido);
var
  LItem: TPedidoItem;
  LProduto: TProduto;
  LProdutosVistos: TList<Integer>;
begin
  if APedido.Itens.Count = 0 then
    raise ERegraNegocio.Create('O pedido deve ter ao menos um item.');

  APedido.ValorTotal := 0;
  LProdutosVistos := TList<Integer>.Create;
  try
    for LItem in APedido.Itens do
    begin
      if LItem.Quantidade <= 0 then
        raise ERegraNegocio.CreateFmt('A quantidade do produto %d deve ser maior que zero.', [LItem.ProdutoId]);

      // Item repetido complicaria a conferência de estoque; o cliente da API
      // deve somar as quantidades em um único item.
      if LProdutosVistos.Contains(LItem.ProdutoId) then
        raise ERegraNegocio.CreateFmt('O produto %d aparece mais de uma vez no pedido.', [LItem.ProdutoId]);
      LProdutosVistos.Add(LItem.ProdutoId);

      LProduto := FProdutos.BuscarPorId(LItem.ProdutoId);
      try
        if LProduto = nil then
          raise ERegraNegocio.CreateFmt('Produto %d não encontrado ou inativo.', [LItem.ProdutoId]);

        if LProduto.Estoque < LItem.Quantidade then
          raise ERegraNegocio.CreateFmt('Estoque insuficiente para "%s" (disponível: %d).',
            [LProduto.Descricao, LProduto.Estoque]);

        LItem.DescricaoProduto := LProduto.Descricao;
        LItem.PrecoUnitario := LProduto.Preco;
        LItem.ValorTotal := LProduto.Preco * LItem.Quantidade;
        APedido.ValorTotal := APedido.ValorTotal + LItem.ValorTotal;
      finally
        LProduto.Free;
      end;
    end;
  finally
    LProdutosVistos.Free;
  end;
end;

procedure TPedidoService.Criar(APedido: TPedido);
begin
  ValidarCliente(APedido);
  PrepararItens(APedido);

  APedido.Data := Now;
  APedido.Status := spAberto;
  FPedidos.Inserir(APedido);
end;

function TPedidoService.Cancelar(AId: Integer): TPedido;
begin
  Result := Buscar(AId);
  try
    if Result.Status = spCancelado then
      raise ERegraNegocio.Create('Pedido já está cancelado.');

    FPedidos.Cancelar(Result);
    Result.Status := spCancelado;
  except
    Result.Free;
    raise;
  end;
end;

end.
