unit Controller.Relatorio;

interface

type
  TControllerRelatorio = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.DateUtils, Horse, Horse.Commons, Repository.Relatorio,
  Repository.Pedido, Model.Paginacao, Infra.Relatorio, Service.Relatorio, Controller.Utils, Infra.Excecoes;

function Service: IRelatorioService;
begin
  Result := TRelatorioService.Create(TRelatorioRepository.Create, TPedidoRepository.Create,
    TRegistroGeradores.Create);
end;

function Motor(AReq: THorseRequest): TMotorRelatorio;
begin
  Result := TMotorRelatorio.DeTexto(AReq.Query.Field('motor').AsString);
end;

// ?inicio=2026-11-01&fim=2026-11-30 (fim inclusivo)
function Data(AReq: THorseRequest; const ACampo: string): TDateTime;
var
  LTexto: string;
begin
  LTexto := AReq.Query.Field(ACampo).AsString.Trim;
  if LTexto = '' then
    Exit(0);
  if not LerDataISO(LTexto, Result) then
    raise ERequisicaoInvalida.CreateFmt('"%s" deve ser uma data no formato AAAA-MM-DD.', [ACampo]);
end;

procedure EnviarPdf(ARes: THorseResponse; const APdf: TBytes; const ANome: string);
var
  LStream: TBytesStream;
begin
  LStream := TBytesStream.Create(APdf);
  try
    ARes.SendFile(LStream, ANome, 'application/pdf');
  finally
    LStream.Free;
  end;
end;

procedure PedidosPorPeriodo(AReq: THorseRequest; ARes: THorseResponse);
begin
  EnviarPdf(ARes, Service.PedidosPorPeriodo(Motor(AReq), Data(AReq, 'inicio'), Data(AReq, 'fim'),
    UsuarioLogado(AReq)), 'pedidos.pdf');
end;

procedure EspelhoPedido(AReq: THorseRequest; ARes: THorseResponse);
var
  LId: Integer;
begin
  LId := IdDaRota(AReq);
  EnviarPdf(ARes, Service.EspelhoPedido(Motor(AReq), LId), Format('pedido-%d.pdf', [LId]));
end;

procedure VendasPorProduto(AReq: THorseRequest; ARes: THorseResponse);
begin
  EnviarPdf(ARes, Service.VendasPorProduto(Motor(AReq), Data(AReq, 'inicio'), Data(AReq, 'fim'),
    UsuarioLogado(AReq)), 'vendas-por-produto.pdf');
end;

procedure Visitas(AReq: THorseRequest; ARes: THorseResponse);
begin
  EnviarPdf(ARes, Service.Visitas(Motor(AReq), Data(AReq, 'inicio'), Data(AReq, 'fim'),
    UsuarioLogado(AReq)), 'visitas.pdf');
end;

class procedure TControllerRelatorio.Registrar;
begin
  // pedidos, vendas e visitas são sempre do vendedor logado
  THorse.Get('/relatorios/pedidos', PedidosPorPeriodo);
  THorse.Get('/relatorios/pedido/:id', EspelhoPedido);
  THorse.Get('/relatorios/vendas-produto', VendasPorProduto);
  THorse.Get('/relatorios/visitas', Visitas);
end;

end.
