unit Tests.Infra.Relatorio.Fortes;

// Gera PDFs de verdade com o Fortes (sem banco): confere que sai um PDF e não um erro.

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Infra.Relatorio;

type
  [TestFixture]
  TTestsGeradorFortes = class
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

// PNG válido pequeno, para testar a assinatura no espelho (usado também pelo teste do FastReport)
function PngDeTeste: TBytes;

implementation

uses
  System.Classes, System.DateUtils, Vcl.Graphics, Vcl.Imaging.pngimage, Model.Pedido, Model.Relatorio,
  Infra.Relatorio.Fortes;

function PngDeTeste: TBytes;
var
  LPng: TPngImage;
  LStream: TBytesStream;
begin
  LPng := TPngImage.CreateBlank(COLOR_RGB, 8, 120, 40);
  LStream := TBytesStream.Create;
  try
    LPng.Canvas.Pen.Color := clBlack;
    LPng.Canvas.MoveTo(5, 30);
    LPng.Canvas.LineTo(115, 10);
    LPng.SaveToStream(LStream);
    Result := Copy(LStream.Bytes, 0, LStream.Size);
  finally
    LStream.Free;
    LPng.Free;
  end;
end;

procedure TTestsGeradorFortes.Setup;
begin
  FGerador := TGeradorFortes.Create;
end;

procedure TTestsGeradorFortes.VerificarPdf(const ABytes: TBytes);
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

procedure TTestsGeradorFortes.EspelhoComItensLocalEAssinatura;
var
  LDados: TRelEspelho;
  LItem: TPedidoItem;
begin
  LDados.Pedido := TPedido.Create;
  try
    LDados.Pedido.Id := 31;
    LDados.Pedido.NomeCliente := 'Comercial Exemplo Ltda';
    LDados.Pedido.NomeVendedor := 'Ana Vendedora';
    LDados.Pedido.Data := EncodeDateTime(2026, 11, 22, 10, 30, 0, 0);
    LDados.Pedido.Observacao := 'Entregar pela manhã';
    LDados.Pedido.DefinirLocalizacao(-23.5505, -46.6333, 8);
    LItem := LDados.Pedido.AdicionarItem(3, 2);
    LItem.DescricaoProduto := 'Monitor 27"';
    LItem.PrecoUnitario := 1599;
    LItem.ValorTotal := 3198;
    LItem := LDados.Pedido.AdicionarItem(1, 1);
    LItem.DescricaoProduto := 'Teclado mecânico';
    LItem.PrecoUnitario := 349.90;
    LItem.ValorTotal := 349.90;
    LDados.Pedido.ValorTotal := 3547.90;
    LDados.Assinatura := PngDeTeste;

    VerificarPdf(FGerador.EspelhoPedido(LDados));
  finally
    LDados.Pedido.Free;
  end;
end;

procedure TTestsGeradorFortes.EspelhoComAssinaturaCorrompidaAindaGeraPdf;
var
  LDados: TRelEspelho;
begin
  LDados.Pedido := TPedido.Create;
  try
    LDados.Pedido.Id := 32;
    LDados.Pedido.NomeCliente := 'Maria';
    LDados.Pedido.Data := EncodeDate(2026, 11, 22);
    // começa como PNG (passou na validação da API), mas o resto é lixo
    LDados.Assinatura := TBytes.Create($89, $50, $4E, $47, $0D, $0A, $1A, $0A, 0, 0, 0, 0, 1, 2, 3);
    VerificarPdf(FGerador.EspelhoPedido(LDados));
  finally
    LDados.Pedido.Free;
  end;
end;

procedure TTestsGeradorFortes.PedidosPorPeriodoVazio;
var
  LDados: TRelPedidos;
begin
  LDados.Cabecalho := Cabecalho('Pedidos por período');
  LDados.Linhas := nil;
  VerificarPdf(FGerador.PedidosPorPeriodo(LDados));
end;

procedure TTestsGeradorFortes.PedidosPorPeriodoComLinhas;
var
  LDados: TRelPedidos;
  I: Integer;
begin
  LDados.Cabecalho := Cabecalho('Pedidos por período');
  SetLength(LDados.Linhas, 80); // mais de uma página
  for I := 0 to High(LDados.Linhas) do
  begin
    LDados.Linhas[I].Id := I + 1;
    LDados.Linhas[I].Data := EncodeDate(2026, 11, 1 + I mod 28);
    LDados.Linhas[I].Cliente := 'Cliente ' + IntToStr(I + 1);
    LDados.Linhas[I].Status := 'ABERTO';
    LDados.Linhas[I].NotaNumero := I mod 3;
    LDados.Linhas[I].Valor := 10 * (I + 1);
  end;
  VerificarPdf(FGerador.PedidosPorPeriodo(LDados));
end;

procedure TTestsGeradorFortes.VendasPorProduto;
var
  LDados: TRelVendasProduto;
begin
  LDados.Cabecalho := Cabecalho('Vendas por produto');
  SetLength(LDados.Linhas, 2);
  LDados.Linhas[0].Produto := 'Monitor 27"';
  LDados.Linhas[0].Quantidade := 4;
  LDados.Linhas[0].Valor := 6396;
  LDados.Linhas[1].Produto := 'Mouse sem fio';
  LDados.Linhas[1].Quantidade := 10;
  LDados.Linhas[1].Valor := 1299;
  VerificarPdf(FGerador.VendasPorProduto(LDados));
end;

procedure TTestsGeradorFortes.Visitas;
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
  TDUnitX.RegisterTestFixture(TTestsGeradorFortes);

end.
