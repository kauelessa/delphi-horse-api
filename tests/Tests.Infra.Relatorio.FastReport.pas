unit Tests.Infra.Relatorio.FastReport;

// Mesmos cenários do Fortes, com o FastReport. Só existe com a diretiva FASTREPORT
// (o FastReport é comercial; sem ele a unit compila vazia).

interface

{$IFDEF FASTREPORT}
uses
  System.SysUtils,
  DUnitX.TestFramework,
  Infra.Relatorio;

type
  [TestFixture]
  TTestsGeradorFastReport = class
  private
    FGerador: IGeradorRelatorio;
    procedure VerificarPdf(const ABytes: TBytes);
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure EspelhoComItensLocalEAssinatura;
    [Test]
    procedure EspelhoComAssinaturaCorrompidaAindaGeraPdf;
    [Test]
    procedure PedidosPorPeriodoVazio;
    [Test]
    procedure PedidosPorPeriodoComLinhas;
    [Test]
    procedure VendasPorProduto;
    [Test]
    procedure Visitas;
  end;
{$ENDIF}

implementation

{$IFDEF FASTREPORT}
uses
  System.DateUtils, Model.Pedido, Model.Relatorio, Infra.Relatorio.FastReport, Tests.Infra.Relatorio.Fortes;

procedure TTestsGeradorFastReport.Setup;
begin
  FGerador := TGeradorFastReport.Create;
end;

procedure TTestsGeradorFastReport.VerificarPdf(const ABytes: TBytes);
begin
  Assert.IsTrue(Length(ABytes) > 1000, Format('PDF pequeno demais: %d bytes', [Length(ABytes)]));
  Assert.AreEqual('%PDF', TEncoding.ANSI.GetString(ABytes, 0, 4));
end;

function Cabecalho(const ATitulo: string): TCabecalhoRel;
begin
  Result.Titulo := ATitulo;
  Result.Inicio := EncodeDate(2026, 11, 1);
  Result.Fim := EncodeDate(2026, 11, 30);
  Result.Vendedor := 'Ana Vendedora';
end;

function NovoPedido: TPedido;
var
  LItem: TPedidoItem;
begin
  Result := TPedido.Create;
  Result.Id := 31;
  Result.NomeCliente := 'Comercial Exemplo Ltda';
  Result.NomeVendedor := 'Ana Vendedora';
  Result.Data := EncodeDateTime(2026, 11, 22, 10, 30, 0, 0);
  Result.Observacao := 'Entregar pela manhã';
  Result.DefinirLocalizacao(-23.5505, -46.6333, 8);
  LItem := Result.AdicionarItem(3, 2);
  LItem.DescricaoProduto := 'Monitor 27"';
  LItem.PrecoUnitario := 1599;
  LItem.ValorTotal := 3198;
  Result.ValorTotal := 3198;
end;

procedure TTestsGeradorFastReport.EspelhoComItensLocalEAssinatura;
var
  LDados: TRelEspelho;
begin
  LDados.Pedido := NovoPedido;
  try
    LDados.Assinatura := PngDeTeste;
    VerificarPdf(FGerador.EspelhoPedido(LDados));
  finally
    LDados.Pedido.Free;
  end;
end;

procedure TTestsGeradorFastReport.EspelhoComAssinaturaCorrompidaAindaGeraPdf;
var
  LDados: TRelEspelho;
begin
  LDados.Pedido := NovoPedido;
  try
    LDados.Assinatura := TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0, 0, 0, 0, 1, 2, 3);
    VerificarPdf(FGerador.EspelhoPedido(LDados));
  finally
    LDados.Pedido.Free;
  end;
end;

procedure TTestsGeradorFastReport.PedidosPorPeriodoVazio;
var
  LDados: TRelPedidos;
begin
  LDados.Cabecalho := Cabecalho('Pedidos por período');
  LDados.Linhas := nil;
  VerificarPdf(FGerador.PedidosPorPeriodo(LDados));
end;

procedure TTestsGeradorFastReport.PedidosPorPeriodoComLinhas;
var
  LDados: TRelPedidos;
  I: Integer;
begin
  LDados.Cabecalho := Cabecalho('Pedidos por período');
  SetLength(LDados.Linhas, 80);
  for I := 0 to High(LDados.Linhas) do
  begin
    LDados.Linhas[I].Id := I + 1;
    LDados.Linhas[I].Data := EncodeDate(2026, 11, 1 + I mod 28);
    LDados.Linhas[I].Cliente := 'Cliente ' + IntToStr(I + 1);
    LDados.Linhas[I].Status := 'ABERTO';
    LDados.Linhas[I].Valor := 10 * (I + 1);
  end;
  VerificarPdf(FGerador.PedidosPorPeriodo(LDados));
end;

procedure TTestsGeradorFastReport.VendasPorProduto;
var
  LDados: TRelVendasProduto;
begin
  LDados.Cabecalho := Cabecalho('Vendas por produto');
  SetLength(LDados.Linhas, 1);
  LDados.Linhas[0].Produto := 'Monitor 27"';
  LDados.Linhas[0].Quantidade := 4;
  LDados.Linhas[0].Valor := 6396;
  VerificarPdf(FGerador.VendasPorProduto(LDados));
end;

procedure TTestsGeradorFastReport.Visitas;
var
  LDados: TRelVisitas;
begin
  LDados.Cabecalho := Cabecalho('Visitas');
  SetLength(LDados.Linhas, 1);
  LDados.Linhas[0].Data := EncodeDateTime(2026, 11, 22, 9, 0, 0, 0);
  LDados.Linhas[0].Cliente := 'Mercado Bom Preço';
  LDados.Linhas[0].Motivo := 'SEM_ESTOQUE';
  LDados.Linhas[0].Observacao := 'Volta semana que vem';
  VerificarPdf(FGerador.Visitas(LDados));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsGeradorFastReport);
{$ENDIF}

end.
