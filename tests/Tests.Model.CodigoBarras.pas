unit Tests.Model.CodigoBarras;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsCodigoBarras = class
  public
    [Test]
    [TestCase('EAN13', '7891000315507')]
    [TestCase('EAN8', '96385074')]
    [TestCase('UPCA', '036000291452')]
    [TestCase('GTIN14', '17891000315504')]
    [TestCase('Seed', '7891000000014')]
    procedure Valido(const ACodigo: string);

    [Test]
    [TestCase('DigitoErrado', '7891000315508')]
    [TestCase('Letra', '789100031550A')]
    [TestCase('Vazio', '')]
    [TestCase('TamanhoInvalido', '78910003155')]
    [TestCase('ComEspaco', '7891000 315507')]
    procedure Invalido(const ACodigo: string);
  end;

implementation

uses
  Model.CodigoBarras;

procedure TTestsCodigoBarras.Valido(const ACodigo: string);
begin
  Assert.IsTrue(TCodigoBarras.Valido(ACodigo), ACodigo);
end;

procedure TTestsCodigoBarras.Invalido(const ACodigo: string);
begin
  Assert.IsFalse(TCodigoBarras.Valido(ACodigo), ACodigo);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsCodigoBarras);

end.
