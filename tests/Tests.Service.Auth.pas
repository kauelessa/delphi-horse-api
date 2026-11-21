unit Tests.Service.Auth;

interface

uses
  DUnitX.TestFramework,
  Model.Usuario,
  Repository.Usuario,
  Infra.Token,
  Service.Auth;

type
  { Repositório em memória com um único usuário (ou nenhum). }
  TUsuarioRepositoryFake = class(TInterfacedObject, IUsuarioRepository)
  private
    FUsuario: TUsuario;
    FUltimoLoginBuscado: string;
  public
    constructor Create(const ALogin, ASenha: string; AAtivo: Boolean); overload;
    constructor Create; overload;
    destructor Destroy; override;
    function BuscarPorLogin(const ALogin: string): TUsuario;
    property UltimoLoginBuscado: string read FUltimoLoginBuscado;
  end;

  TGeradorTokenFake = class(TInterfacedObject, IGeradorToken)
  public
    function Gerar(const AUsuario: TUsuario): TTokenAcesso;
  end;

  [TestFixture]
  TTestsAuthService = class
  private
    function CriarService(const ARepository: IUsuarioRepository): IAuthService;
    procedure VerificarRequisicaoInvalida(const ALogin, ASenha: string);
  public
    [Test]
    procedure Login_CredenciaisValidas_RetornaToken;
    [Test]
    procedure Login_NormalizaLoginAntesDeBuscar;
    [Test]
    procedure Login_SenhaErrada_LevantaNaoAutorizado;
    [Test]
    procedure Login_UsuarioInexistente_LevantaNaoAutorizado;
    [Test]
    procedure Login_UsuarioInativo_LevantaNaoAutorizado;
    [Test]
    procedure Login_LoginVazio_LevantaRequisicaoInvalida;
    [Test]
    procedure Login_LoginSoComEspacos_LevantaRequisicaoInvalida;
    [Test]
    procedure Login_SenhaVazia_LevantaRequisicaoInvalida;
  end;

implementation

uses
  System.SysUtils,
  Infra.Excecoes,
  Infra.Senha;

const
  ITERACOES_TESTE = 1000;
  TOKEN_FAKE = 'token-de-teste';

{ TUsuarioRepositoryFake }

constructor TUsuarioRepositoryFake.Create(const ALogin, ASenha: string; AAtivo: Boolean);
begin
  inherited Create;
  FUsuario := TUsuario.Create;
  FUsuario.Id := 1;
  FUsuario.Nome := 'Usuário de Teste';
  FUsuario.Login := ALogin;
  FUsuario.SenhaHash := TSenhaHash.Gerar(ASenha, ITERACOES_TESTE);
  FUsuario.Ativo := AAtivo;
end;

constructor TUsuarioRepositoryFake.Create;
begin
  inherited Create;
  FUsuario := nil;
end;

destructor TUsuarioRepositoryFake.Destroy;
begin
  FUsuario.Free;
  inherited;
end;

function TUsuarioRepositoryFake.BuscarPorLogin(const ALogin: string): TUsuario;
begin
  FUltimoLoginBuscado := ALogin;
  if (FUsuario = nil) or (FUsuario.Login <> ALogin) then
    Exit(nil);

  // Devolve uma cópia, pois o Service libera o objeto recebido.
  Result := TUsuario.Create;
  Result.Id := FUsuario.Id;
  Result.Nome := FUsuario.Nome;
  Result.Login := FUsuario.Login;
  Result.SenhaHash := FUsuario.SenhaHash;
  Result.Ativo := FUsuario.Ativo;
end;

{ TGeradorTokenFake }

function TGeradorTokenFake.Gerar(const AUsuario: TUsuario): TTokenAcesso;
begin
  Result.Token := TOKEN_FAKE;
  Result.ExpiraEm := Now + 1;
end;

{ TTestsAuthService }

function TTestsAuthService.CriarService(const ARepository: IUsuarioRepository): IAuthService;
begin
  Result := TAuthService.Create(ARepository, TGeradorTokenFake.Create);
end;

procedure TTestsAuthService.Login_CredenciaisValidas_RetornaToken;
var
  LToken: TTokenAcesso;
begin
  LToken := CriarService(TUsuarioRepositoryFake.Create('admin', 'senha123', True))
    .Login('admin', 'senha123');

  Assert.AreEqual(TOKEN_FAKE, LToken.Token);
end;

procedure TTestsAuthService.Login_NormalizaLoginAntesDeBuscar;
var
  LRepositorio: TUsuarioRepositoryFake;
  LRepositorioIntf: IUsuarioRepository;
begin
  LRepositorio := TUsuarioRepositoryFake.Create('admin', 'senha123', True);
  LRepositorioIntf := LRepositorio; // mantém a referência viva durante o teste

  CriarService(LRepositorioIntf).Login('  Admin ', 'senha123');

  Assert.AreEqual('admin', LRepositorio.UltimoLoginBuscado);
end;

procedure TTestsAuthService.Login_SenhaErrada_LevantaNaoAutorizado;
var
  LService: IAuthService;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('admin', 'senha123', True));

  Assert.WillRaiseWithMessage(
    procedure
    begin
      LService.Login('admin', 'errada');
    end,
    ENaoAutorizado, TAuthService.MENSAGEM_CREDENCIAIS_INVALIDAS);
end;

procedure TTestsAuthService.Login_UsuarioInexistente_LevantaNaoAutorizado;
var
  LService: IAuthService;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create);

  Assert.WillRaiseWithMessage(
    procedure
    begin
      LService.Login('ninguem', 'senha123');
    end,
    ENaoAutorizado, TAuthService.MENSAGEM_CREDENCIAIS_INVALIDAS);
end;

procedure TTestsAuthService.Login_UsuarioInativo_LevantaNaoAutorizado;
var
  LService: IAuthService;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('admin', 'senha123', False));

  Assert.WillRaise(
    procedure
    begin
      LService.Login('admin', 'senha123');
    end,
    ENaoAutorizado);
end;

procedure TTestsAuthService.VerificarRequisicaoInvalida(const ALogin, ASenha: string);
var
  LService: IAuthService;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('admin', 'senha123', True));

  Assert.WillRaise(
    procedure
    begin
      LService.Login(ALogin, ASenha);
    end,
    ERequisicaoInvalida);
end;

procedure TTestsAuthService.Login_LoginVazio_LevantaRequisicaoInvalida;
begin
  VerificarRequisicaoInvalida('', 'senha123');
end;

procedure TTestsAuthService.Login_LoginSoComEspacos_LevantaRequisicaoInvalida;
begin
  VerificarRequisicaoInvalida('   ', 'senha123');
end;

procedure TTestsAuthService.Login_SenhaVazia_LevantaRequisicaoInvalida;
begin
  VerificarRequisicaoInvalida('admin', '');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsAuthService);

end.
