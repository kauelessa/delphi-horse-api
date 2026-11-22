unit Service.Relatorio;

interface

uses
  System.SysUtils, Repository.Relatorio, Repository.Pedido, Infra.Relatorio;

type
  IRelatorioService = interface
    ['{A4C82E17-9D3B-4F65-B0E1-7C5A2D9F3E46}']
    function PedidosPorPeriodo(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
    function EspelhoPedido(AMotor: TMotorRelatorio; APedidoId: Integer): TBytes;
    function VendasPorProduto(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
    function Visitas(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
  end;

  { Busca os dados, monta o DTO e pede o PDF ao motor escolhido.
    AUsuarioId > 0 restringe aos pedidos/visitas daquele vendedor. }
  TRelatorioService = class(TInterfacedObject, IRelatorioService)
  private
    FRelatorios: IRelatorioRepository;
    FPedidos: IPedidoRepository;
    FExecutor: IExecutorRelatorio;
    procedure ValidarPeriodo(AInicio, AFim: TDateTime);
  public
    const DIAS_MAXIMOS = 366;
    constructor Create(const ARelatorios: IRelatorioRepository; const APedidos: IPedidoRepository;
      const AExecutor: IExecutorRelatorio);
    function PedidosPorPeriodo(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
    function EspelhoPedido(AMotor: TMotorRelatorio; APedidoId: Integer): TBytes;
    function VendasPorProduto(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
    function Visitas(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime; AUsuarioId: Integer): TBytes;
  end;

implementation

uses
  System.DateUtils, Model.Pedido, Model.Relatorio, Infra.Excecoes;

constructor TRelatorioService.Create(const ARelatorios: IRelatorioRepository; const APedidos: IPedidoRepository;
  const AExecutor: IExecutorRelatorio);
begin
  inherited Create;
  FRelatorios := ARelatorios;
  FPedidos := APedidos;
  FExecutor := AExecutor;
end;

procedure TRelatorioService.ValidarPeriodo(AInicio, AFim: TDateTime);
begin
  if (AInicio = 0) or (AFim = 0) then
    raise ERequisicaoInvalida.Create('Informe o período (inicio e fim).');
  if DateOf(AFim) < DateOf(AInicio) then
    raise ERequisicaoInvalida.Create('A data final deve ser igual ou posterior à inicial.');
  if DaysBetween(DateOf(AFim), DateOf(AInicio)) > DIAS_MAXIMOS then
    raise ERequisicaoInvalida.CreateFmt('O período deve ter no máximo %d dias.', [DIAS_MAXIMOS]);
end;

function TRelatorioService.PedidosPorPeriodo(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TBytes;
var
  LDados: TRelPedidos;
begin
  ValidarPeriodo(AInicio, AFim);
  LDados.Cabecalho.Titulo := 'Pedidos por período';
  LDados.Cabecalho.Inicio := AInicio;
  LDados.Cabecalho.Fim := AFim;
  LDados.Cabecalho.Vendedor := FRelatorios.NomeDoUsuario(AUsuarioId);
  LDados.Linhas := FRelatorios.PedidosPorPeriodo(AInicio, AFim, AUsuarioId);

  Result := FExecutor.Executar(AMotor,
    function(AGerador: IGeradorRelatorio): TBytes
    begin
      Result := AGerador.PedidosPorPeriodo(LDados);
    end);
end;

function TRelatorioService.EspelhoPedido(AMotor: TMotorRelatorio; APedidoId: Integer): TBytes;
var
  LDados: TRelEspelho;
begin
  LDados.Pedido := FPedidos.BuscarPorId(APedidoId);
  if LDados.Pedido = nil then
    raise ENaoEncontrado.CreateFmt('Pedido %d não encontrado.', [APedidoId]);
  try
    if LDados.Pedido.TemAssinatura or (Length(LDados.Pedido.Assinatura) > 0) then
      LDados.Assinatura := FPedidos.LerAssinatura(APedidoId);

    Result := FExecutor.Executar(AMotor,
      function(AGerador: IGeradorRelatorio): TBytes
      begin
        Result := AGerador.EspelhoPedido(LDados);
      end);
  finally
    LDados.Pedido.Free;
  end;
end;

function TRelatorioService.VendasPorProduto(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TBytes;
var
  LDados: TRelVendasProduto;
begin
  ValidarPeriodo(AInicio, AFim);
  LDados.Cabecalho.Titulo := 'Vendas por produto';
  LDados.Cabecalho.Inicio := AInicio;
  LDados.Cabecalho.Fim := AFim;
  LDados.Cabecalho.Vendedor := FRelatorios.NomeDoUsuario(AUsuarioId);
  LDados.Linhas := FRelatorios.VendasPorProduto(AInicio, AFim, AUsuarioId);

  Result := FExecutor.Executar(AMotor,
    function(AGerador: IGeradorRelatorio): TBytes
    begin
      Result := AGerador.VendasPorProduto(LDados);
    end);
end;

function TRelatorioService.Visitas(AMotor: TMotorRelatorio; AInicio, AFim: TDateTime;
  AUsuarioId: Integer): TBytes;
var
  LDados: TRelVisitas;
begin
  ValidarPeriodo(AInicio, AFim);
  LDados.Cabecalho.Titulo := 'Visitas sem venda';
  LDados.Cabecalho.Inicio := AInicio;
  LDados.Cabecalho.Fim := AFim;
  LDados.Cabecalho.Vendedor := FRelatorios.NomeDoUsuario(AUsuarioId);
  LDados.Linhas := FRelatorios.Visitas(AInicio, AFim, AUsuarioId);

  Result := FExecutor.Executar(AMotor,
    function(AGerador: IGeradorRelatorio): TBytes
    begin
      Result := AGerador.Visitas(LDados);
    end);
end;

end.
