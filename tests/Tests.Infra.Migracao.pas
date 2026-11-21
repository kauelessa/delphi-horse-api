unit Tests.Infra.Migracao;

interface

uses
  System.Classes,
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsMigracao = class
  private
    FAplicados: TStringList;
    function Nomes(const AArquivos: TArray<string>): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Pendentes_OrdenaPeloNomeDoArquivo;
    [Test]
    procedure Pendentes_IgnoraJaAplicados;
    [Test]
    procedure Pendentes_ComparaNomeSemDiferenciarMaiusculas;
    [Test]
    procedure Pendentes_SeedsDesligados_PulaSeeds;
    [Test]
    procedure Pendentes_SeedsLigados_IncluiSeedsNaOrdem;
    [Test]
    procedure Pendentes_TudoAplicado_RetornaVazio;

    [Test]
    [TestCase('Seed', 'database\002_seed_usuario_admin.sql,True')]
    [TestCase('Maiusculas', '004_SEED_dados.sql,True')]
    [TestCase('Tabela', 'database\001_create_tables.sql,False')]
    [TestCase('SeedSoNaPasta', 'C:\_seed_\003_create.sql,False')]
    procedure EhSeed(const AArquivo: string; AEsperado: Boolean);
  end;

implementation

uses
  System.SysUtils,
  Infra.Migracao;

const
  SCRIPTS: TArray<string> = [
    'database\003_create_tables_vendas.sql',
    'database\001_create_tables.sql',
    'database\004_seed_dados_exemplo.sql',
    'database\002_seed_usuario_admin.sql'];

procedure TTestsMigracao.Setup;
begin
  FAplicados := TStringList.Create;
  FAplicados.CaseSensitive := False;
end;

procedure TTestsMigracao.TearDown;
begin
  FAplicados.Free;
end;

function TTestsMigracao.Nomes(const AArquivos: TArray<string>): string;
var
  LArquivo: string;
begin
  Result := '';
  for LArquivo in AArquivos do
  begin
    if not Result.IsEmpty then
      Result := Result + ',';
    Result := Result + ExtractFileName(LArquivo).Substring(0, 3);
  end;
end;

procedure TTestsMigracao.Pendentes_OrdenaPeloNomeDoArquivo;
begin
  Assert.AreEqual('001,002,003,004',
    Nomes(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, True)));
end;

procedure TTestsMigracao.Pendentes_IgnoraJaAplicados;
begin
  FAplicados.Add('001_create_tables.sql');
  FAplicados.Add('002_seed_usuario_admin.sql');
  Assert.AreEqual('003,004',
    Nomes(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, True)));
end;

procedure TTestsMigracao.Pendentes_ComparaNomeSemDiferenciarMaiusculas;
begin
  FAplicados.Add('001_CREATE_TABLES.SQL');
  Assert.AreEqual('002,003,004',
    Nomes(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, True)));
end;

procedure TTestsMigracao.Pendentes_SeedsDesligados_PulaSeeds;
begin
  Assert.AreEqual('001,003',
    Nomes(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, False)));
end;

procedure TTestsMigracao.Pendentes_SeedsLigados_IncluiSeedsNaOrdem;
begin
  // seed pulado antes não fica registrado, então roda quando a opção é ligada
  FAplicados.Add('001_create_tables.sql');
  FAplicados.Add('003_create_tables_vendas.sql');
  Assert.AreEqual('002,004',
    Nomes(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, True)));
end;

procedure TTestsMigracao.Pendentes_TudoAplicado_RetornaVazio;
var
  LScript: string;
begin
  for LScript in SCRIPTS do
    FAplicados.Add(ExtractFileName(LScript));
  Assert.AreEqual(0, Length(TMigrador.ScriptsPendentes(SCRIPTS, FAplicados, True)));
end;

procedure TTestsMigracao.EhSeed(const AArquivo: string; AEsperado: Boolean);
begin
  Assert.AreEqual(AEsperado, TMigrador.EhSeed(AArquivo));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsMigracao);

end.
