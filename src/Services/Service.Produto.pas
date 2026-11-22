unit Service.Produto;

interface

uses
  System.Generics.Collections, Model.Produto, Model.Paginacao, Repository.Produto;

type
  IProdutoService = interface
    ['{E4A7C1B9-2D58-4F03-A6E1-8B9D0F2C7A35}']
    function Listar(const APaginacao: TPaginacao; const ABusca: string; out ATotal: Integer): TObjectList<TProduto>;
    function Buscar(AId: Integer): TProduto;
    function BuscarPorCodigoBarras(const ACodigo: string): TProduto;
    procedure Criar(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Excluir(AId: Integer);
  end;

  TProdutoService = class(TInterfacedObject, IProdutoService)
  private
    FRepository: IProdutoRepository;
    procedure Validar(AProduto: TProduto);
  public
    constructor Create(const ARepository: IProdutoRepository);
    function Listar(const APaginacao: TPaginacao; const ABusca: string; out ATotal: Integer): TObjectList<TProduto>;
    function Buscar(AId: Integer): TProduto;
    function BuscarPorCodigoBarras(const ACodigo: string): TProduto;
    procedure Criar(AProduto: TProduto);
    procedure Atualizar(AProduto: TProduto);
    procedure Excluir(AId: Integer); // inativa, não apaga
  end;

implementation

uses
  System.SysUtils, Model.CodigoBarras, Infra.Excecoes;

constructor TProdutoService.Create(const ARepository: IProdutoRepository);
begin
  inherited Create;
  FRepository := ARepository;
end;

procedure TProdutoService.Validar(AProduto: TProduto);
var
  LOutro: Integer;
begin
  AProduto.Descricao := AProduto.Descricao.Trim;

  if AProduto.Descricao.IsEmpty then
    raise ERequisicaoInvalida.Create('Informe a descrição do produto.');
  if AProduto.Descricao.Length > 150 then
    raise ERegraNegocio.Create('A descrição deve ter no máximo 150 caracteres.');
  if AProduto.Preco <= 0 then
    raise ERegraNegocio.Create('O preço deve ser maior que zero.');
  if AProduto.Estoque < 0 then
    raise ERegraNegocio.Create('O estoque não pode ser negativo.');

  AProduto.CodigoBarras := AProduto.CodigoBarras.Trim;
  if AProduto.CodigoBarras <> '' then
  begin
    if not TCodigoBarras.Valido(AProduto.CodigoBarras) then
      raise ERegraNegocio.Create('Código de barras inválido.');
    LOutro := FRepository.CodigoBarrasEmUso(AProduto.CodigoBarras, AProduto.Id);
    if LOutro > 0 then
      raise ERegraNegocio.CreateFmt('Código de barras já usado pelo produto %d.', [LOutro]);
  end;
end;

function TProdutoService.BuscarPorCodigoBarras(const ACodigo: string): TProduto;
begin
  Result := FRepository.BuscarPorCodigoBarras(ACodigo.Trim);
  if Result = nil then
    raise ENaoEncontrado.CreateFmt('Nenhum produto com o código %s.', [ACodigo.Trim]);
end;

function TProdutoService.Listar(const APaginacao: TPaginacao; const ABusca: string;
  out ATotal: Integer): TObjectList<TProduto>;
begin
  Result := FRepository.Listar(APaginacao, Trim(ABusca), ATotal);
end;

function TProdutoService.Buscar(AId: Integer): TProduto;
begin
  Result := FRepository.BuscarPorId(AId);
  if Result = nil then
    raise ENaoEncontrado.CreateFmt('Produto %d não encontrado.', [AId]);
end;

procedure TProdutoService.Criar(AProduto: TProduto);
begin
  Validar(AProduto);
  AProduto.Ativo := True;
  FRepository.Inserir(AProduto);
end;

procedure TProdutoService.Atualizar(AProduto: TProduto);
begin
  Buscar(AProduto.Id).Free; // 404 se não existir
  Validar(AProduto);
  AProduto.Ativo := True;
  FRepository.Atualizar(AProduto);
end;

procedure TProdutoService.Excluir(AId: Integer);
begin
  Buscar(AId).Free;
  FRepository.Inativar(AId);
end;

end.
