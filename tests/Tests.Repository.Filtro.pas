unit Tests.Repository.Filtro;

interface

uses
  DUnitX.TestFramework;

type
  // monta só o WHERE e os valores dos parâmetros; não precisa de banco
  [TestFixture]
  TTestsFiltroBusca = class
  public
    [Test]
    procedure Cliente_SemBusca_SoAtivos;
    [Test]
    procedure Cliente_BuscaSoEspacos_SoAtivos;
    [Test]
    procedure Cliente_BuscaTexto_FiltraNomeEDocumento;
    [Test]
    procedure Cliente_DocumentoFormatado_ParametroNormalizado;
    [Test]
    procedure Cliente_BuscaSemAlfanumerico_NaoFiltraDocumento;
    [Test]
    procedure Cliente_ApostrofoESimbolos_NuncaVaoNoSQL;
    [Test]
    procedure Produto_SemBusca_SoAtivos;
    [Test]
    procedure Produto_BuscaTexto_FiltraDescricao;
  end;

implementation

uses
  System.SysUtils, System.StrUtils, Repository.Cliente, Repository.Produto;

procedure TTestsFiltroBusca.Cliente_SemBusca_SoAtivos;
var
  LBusca, LDocumento: string;
begin
  Assert.AreEqual('WHERE ATIVO = TRUE', TClienteRepository.Filtro('', LBusca, LDocumento));
end;

procedure TTestsFiltroBusca.Cliente_BuscaSoEspacos_SoAtivos;
var
  LBusca, LDocumento: string;
begin
  Assert.AreEqual('WHERE ATIVO = TRUE', TClienteRepository.Filtro('   ', LBusca, LDocumento));
end;

procedure TTestsFiltroBusca.Cliente_BuscaTexto_FiltraNomeEDocumento;
var
  LWhere, LBusca, LDocumento: string;
begin
  LWhere := TClienteRepository.Filtro('  maria ', LBusca, LDocumento);
  Assert.AreEqual('WHERE ATIVO = TRUE AND (NOME CONTAINING :BUSCA OR DOCUMENTO CONTAINING :DOCUMENTO)', LWhere);
  Assert.AreEqual('maria', LBusca);
  Assert.AreEqual('MARIA', LDocumento);
end;

procedure TTestsFiltroBusca.Cliente_DocumentoFormatado_ParametroNormalizado;
var
  LBusca, LDocumento: string;
begin
  TClienteRepository.Filtro('529.982.247-25', LBusca, LDocumento);
  Assert.AreEqual('52998224725', LDocumento);
end;

procedure TTestsFiltroBusca.Cliente_BuscaSemAlfanumerico_NaoFiltraDocumento;
var
  LBusca, LDocumento: string;
begin
  Assert.AreEqual('WHERE ATIVO = TRUE AND (NOME CONTAINING :BUSCA)',
    TClienteRepository.Filtro('%', LBusca, LDocumento));
  Assert.AreEqual('%', LBusca);
end;

procedure TTestsFiltroBusca.Cliente_ApostrofoESimbolos_NuncaVaoNoSQL;
var
  LWhere, LBusca, LDocumento: string;
begin
  LWhere := TClienteRepository.Filtro('O''Brien & Cia', LBusca, LDocumento);
  Assert.IsFalse(ContainsText(LWhere, 'Brien'), 'o texto da busca não pode ir concatenado no SQL');
  Assert.AreEqual('O''Brien & Cia', LBusca);
end;

procedure TTestsFiltroBusca.Produto_SemBusca_SoAtivos;
var
  LBusca: string;
begin
  Assert.AreEqual('WHERE ATIVO = TRUE', TProdutoRepository.Filtro('', LBusca));
end;

procedure TTestsFiltroBusca.Produto_BuscaTexto_FiltraDescricao;
var
  LBusca: string;
begin
  Assert.AreEqual('WHERE ATIVO = TRUE AND DESCRICAO CONTAINING :BUSCA', TProdutoRepository.Filtro(' São Paulo ', LBusca));
  Assert.AreEqual('São Paulo', LBusca);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsFiltroBusca);

end.
