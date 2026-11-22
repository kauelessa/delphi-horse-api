unit Service.Pedido;

interface

uses
  System.SysUtils,
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
    procedure Criar(APedido: TPedido); overload;
    procedure Criar(APedido: TPedido; out AJaExistia: Boolean); overload;
    function Cancelar(AId: Integer): TPedido;
    function LerAssinatura(AId: Integer): TBytes;
  end;

  TPedidoService = class(TInterfacedObject, IPedidoService)
  private
    FClientes: IClienteRepository;
    FProdutos: IProdutoRepository;
    FPedidos: IPedidoRepository;
    FRelogio: IRelogioRepository;
    procedure ValidarCliente(APedido: TPedido);
    procedure PrepararItens(APedido: TPedido);
    procedure ValidarDadosDoApp(APedido: TPedido);
    function CarregarPorUuid(APedido: TPedido): Boolean;
    function Agora: TDateTime;
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
    procedure Criar(APedido: TPedido); overload;
    { Pedido do app vem com Uuid (e Origem passa a ser APP). Se o Uuid já existe
      (reenvio), APedido recebe o pedido gravado e AJaExistia fica True.
      Data informada pelo app vale se estiver entre 30 dias atrás e 10 min à frente. }
    procedure Criar(APedido: TPedido; out AJaExistia: Boolean); overload;
    function LerAssinatura(AId: Integer): TBytes;

    { Só pedidos ABERTOS podem ser cancelados; o estoque dos itens é devolvido.
      Retorna o pedido já com o novo status (o chamador libera). }
    function Cancelar(AId: Integer): TPedido;
  end;

implementation

uses
  System.DateUtils,
  Model.Cliente,
  Model.Uuid,
  Model.Imagem,
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

const
  TAMANHO_MAXIMO_OBSERVACAO = 500;
  TAMANHO_MAXIMO_ASSINATURA = 204800;
  DIAS_ATRAS_ACEITOS = 30;
  MINUTOS_A_FRENTE_ACEITOS = 10; // relógio do celular adiantado

function TPedidoService.Agora: TDateTime;
begin
  if Assigned(FRelogio) then
    Result := FRelogio.AgoraNoServidor
  else
    Result := Now;
end;

function TPedidoService.CarregarPorUuid(APedido: TPedido): Boolean;
var
  LExistente: TPedido;
begin
  LExistente := FPedidos.BuscarPorUuid(APedido.Uuid);
  try
    Result := LExistente <> nil;
    if Result then
      APedido.Assign(LExistente);
  finally
    LExistente.Free;
  end;
end;

procedure TPedidoService.ValidarDadosDoApp(APedido: TPedido);
var
  LAgora: TDateTime;
begin
  LAgora := Agora;
  if APedido.Data = 0 then
    APedido.Data := LAgora
  else if (APedido.Data < IncDay(LAgora, -DIAS_ATRAS_ACEITOS)) or
    (APedido.Data > IncMinute(LAgora, MINUTOS_A_FRENTE_ACEITOS)) then
    raise ERegraNegocio.Create('Data do pedido fora do intervalo aceito.');

  APedido.Observacao := APedido.Observacao.Trim;
  if APedido.Observacao.Length > TAMANHO_MAXIMO_OBSERVACAO then
    raise ERegraNegocio.CreateFmt('A observação deve ter no máximo %d caracteres.', [TAMANHO_MAXIMO_OBSERVACAO]);

  if APedido.TemLocalizacao and ((APedido.Latitude < -90) or (APedido.Latitude > 90) or
    (APedido.Longitude < -180) or (APedido.Longitude > 180) or (APedido.Precisao < 0)) then
    raise ERequisicaoInvalida.Create('Localização inválida.');

  if Length(APedido.Assinatura) > 0 then
  begin
    if not TImagem.EhPng(APedido.Assinatura) then
      raise ERequisicaoInvalida.Create('A assinatura deve ser PNG.');
    if Length(APedido.Assinatura) > TAMANHO_MAXIMO_ASSINATURA then
      raise ERequisicaoInvalida.Create('Assinatura maior que 200 KB.');
  end;
end;

procedure TPedidoService.Criar(APedido: TPedido);
var
  LJaExistia: Boolean;
begin
  Criar(APedido, LJaExistia);
end;

procedure TPedidoService.Criar(APedido: TPedido; out AJaExistia: Boolean);
begin
  AJaExistia := False;
  if APedido.Uuid.Trim <> '' then
  begin
    if not TUuid.Valido(APedido.Uuid.Trim) then
      raise ERequisicaoInvalida.Create('"uuid" inválido.');
    APedido.Uuid := TUuid.Normalizar(APedido.Uuid);
    APedido.Origem := opApp;
    AJaExistia := CarregarPorUuid(APedido);
    if AJaExistia then
      Exit;
  end
  else
    APedido.Uuid := '';

  ValidarDadosDoApp(APedido);
  ValidarCliente(APedido);
  PrepararItens(APedido);

  APedido.Status := spAberto;
  try
    FPedidos.Inserir(APedido);
  except
    // o mesmo pedido chegou duas vezes ao mesmo tempo e o outro gravou primeiro
    on EUuidDuplicado do
    begin
      AJaExistia := CarregarPorUuid(APedido);
      if not AJaExistia then
        raise;
    end;
  end;
end;

function TPedidoService.LerAssinatura(AId: Integer): TBytes;
begin
  Buscar(AId).Free; // 404 se o pedido não existe
  Result := FPedidos.LerAssinatura(AId);
  if Length(Result) = 0 then
    raise ENaoEncontrado.CreateFmt('Pedido %d não tem assinatura.', [AId]);
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
