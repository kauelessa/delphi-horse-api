unit Tests.Model.Documento;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsDocumento = class
  public
    [Test]
    [TestCase('ComMascara', '529.982.247-25,52998224725')]
    [TestCase('CNPJComMascara', '11.222.333/0001-81,11222333000181')]
    [TestCase('AlfanumericoMinusculo', '12.abc.345/01de-35,12ABC34501DE35')]
    procedure Normalizar_RemoveMascaraEConverteMaiusculas(const AEntrada, AEsperado: string);

    [Test]
    [TestCase('CPF1', '52998224725')]
    [TestCase('CPF2', '12345678909')]
    [TestCase('CNPJNumerico', '11222333000181')]
    [TestCase('CNPJAlfanumerico', '12ABC34501DE35')]
    procedure Valido_DocumentosCorretos_RetornaTrue(const ADocumento: string);

    [Test]
    [TestCase('CPFDigitoErrado', '52998224724')]
    [TestCase('CPFTodosIguais', '11111111111')]
    [TestCase('CNPJDigitoErrado', '11222333000180')]
    [TestCase('CNPJTodosIguais', '00000000000000')]
    [TestCase('CNPJAlfanumericoDigitoErrado', '12ABC34501DE34')]
    [TestCase('CPFComLetra', '5299822472A')]
    [TestCase('CNPJComLetraNoDigito', '12ABC34501DE3A')]
    [TestCase('TamanhoErrado', '1234567890')]
    procedure Valido_DocumentosIncorretos_RetornaFalse(const ADocumento: string);
  end;

implementation

uses
  Model.Documento;

procedure TTestsDocumento.Normalizar_RemoveMascaraEConverteMaiusculas(const AEntrada, AEsperado: string);
begin
  Assert.AreEqual(AEsperado, TDocumento.Normalizar(AEntrada));
end;

procedure TTestsDocumento.Valido_DocumentosCorretos_RetornaTrue(const ADocumento: string);
begin
  Assert.IsTrue(TDocumento.Valido(ADocumento));
end;

procedure TTestsDocumento.Valido_DocumentosIncorretos_RetornaFalse(const ADocumento: string);
begin
  Assert.IsFalse(TDocumento.Valido(ADocumento));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsDocumento);

end.
