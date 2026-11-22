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
    [Test]
    procedure Cliente_ComDesde_IncluiInativos;
    [Test]
    procedure Cliente_ComDesdeEBusca_JuntaOsDois;
    [Test]
    procedure Produto_ComDesde_IncluiInativos;
    [Test]
    procedure Pedido_SemFiltro_SemWhere;
    [Test]
    procedure Pedido_DoVendedorDesde_FiltraUsuarioEData;
  end;

implementation

uses
  System.SysUtils, System.StrUtils, Model.Paginacao, Repository.Cliente, Repository.Produto,
  Repository.Pedido;

function Desde(AUsuarioId: Integer = 0): TFiltroSync;
begin
  Result := TFiltroSync.APartirDe(EncodeDate(2026, 11, 1));
  Result.UsuarioId := AUsuarioId;
end;

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
  Assert.AreEqual('WHERE ATIVO = TRUE AND (DESCRICAO CONTAINING :BUSCA OR CODIGO_BARRAS = :BUSCA_CODIGO)',
    TProdutoRepository.Filtro(' São Paulo ', LBusca));
  Assert.AreEqual('São Paulo', LBusca);
end;

procedure TTestsFiltroBusca.Cliente_ComDesde_IncluiInativos;
var
  LBusca, LDocumento: string;
begin
  // na sincronização o app precisa saber quem foi inativado
  Assert.AreEqual('WHERE ATUALIZADO_EM >= :DESDE', TClienteRepository.Filtro('', LBusca, LDocumento, Desde));
end;

procedure TTestsFiltroBusca.Cliente_ComDesdeEBusca_JuntaOsDois;
var
  LBusca, LDocumento: string;
begin
  Assert.StartsWith('WHERE ATUALIZADO_EM >= :DESDE AND (NOME CONTAINING :BUSCA',
    TClienteRepository.Filtro('maria', LBusca, LDocumento, Desde));
end;

procedure TTestsFiltroBusca.Produto_ComDesde_IncluiInativos;
var
  LBusca: string;
begin
  Assert.AreEqual('WHERE ATUALIZADO_EM >= :DESDE', TProdutoRepository.Filtro('', LBusca, Desde));
end;

procedure TTestsFiltroBusca.Pedido_SemFiltro_SemWhere;
begin
  Assert.AreEqual('', TPedidoRepository.Filtro(0, TFiltroSync.Nenhum));
end;

procedure TTestsFiltroBusca.Pedido_DoVendedorDesde_FiltraUsuarioEData;
var
  LWhere: string;
begin
  LWhere := TPedidoRepository.Filtro(5, Desde(3));
  Assert.Contains(LWhere, 'P.CLIENTE_ID = :CLIENTE_ID');
  Assert.Contains(LWhere, 'P.USUARIO_ID = :USUARIO_ID');
  Assert.Contains(LWhere, 'P.ATUALIZADO_EM >= :DESDE');
  Assert.StartsWith('WHERE ', LWhere);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsFiltroBusca);

end.
