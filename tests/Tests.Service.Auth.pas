unit Tests.Service.Auth;

interface

uses
  DUnitX.TestFramework,
  Model.Usuario,
  Repository.Usuario,
  Infra.Token,
  Service.Auth,
  Repository.Sessao,
  Tests.Fakes;

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
    function BuscarPorId(AId: Integer): TUsuario;
    property UltimoLoginBuscado: string read FUltimoLoginBuscado;
    property Usuario: TUsuario read FUsuario;
  end;

  TGeradorTokenFake = class(TInterfacedObject, IGeradorToken)
  public
    function Gerar(const AUsuario: TUsuario): TTokenAcesso;
  end;

  [TestFixture]
  TTestsAuthService = class
  private
    FAgora: TDateTime;
    FSessoes: TSessaoRepositoryFake;
    FSessoesIntf: ISessaoRepository;
    function CriarService(const ARepository: IUsuarioRepository): IAuthService;
    procedure VerificarRequisicaoInvalida(const ALogin, ASenha: string);
    procedure VerificarSessaoExpirada(const AService: IAuthService; const ARefresh: string);
  public
    [Setup]
    procedure Preparar;
    [Test]
    procedure LoginDevolveRefreshEGuardaSoOHash;
    [Test]
    procedure RenovarRotacionaOToken;
    [Test]
    procedure ReusoDeTokenRevogadoDerrubaAFamilia;
    [Test]
    procedure RefreshExpiradoRecusado;
    [Test]
    procedure RefreshDeUsuarioInativoRecusado;
    [Test]
    procedure RefreshDesconhecidoRecusado;
    [Test]
    procedure SairRevogaASessao;
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
  System.DateUtils,
  Model.Sessao,
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

function TUsuarioRepositoryFake.BuscarPorId(AId: Integer): TUsuario;
begin
  if (FUsuario = nil) or (FUsuario.Id <> AId) then
    Exit(nil);
  Result := BuscarPorLogin(FUsuario.Login);
end;

{ TGeradorTokenFake }

function TGeradorTokenFake.Gerar(const AUsuario: TUsuario): TTokenAcesso;
begin
  Result.Token := TOKEN_FAKE;
  Result.ExpiraEm := Now + 1;
end;

{ TTestsAuthService }

procedure TTestsAuthService.Preparar;
begin
  FAgora := EncodeDateTime(2026, 11, 22, 10, 0, 0, 0);
  FSessoes := TSessaoRepositoryFake.Create;
  FSessoesIntf := FSessoes;
end;

function TTestsAuthService.CriarService(const ARepository: IUsuarioRepository): IAuthService;
begin
  Result := TAuthService.Create(ARepository, FSessoesIntf, TGeradorTokenFake.Create, 30,
    function: TDateTime
    begin
      Result := FAgora;
    end);
end;

procedure TTestsAuthService.VerificarSessaoExpirada(const AService: IAuthService; const ARefresh: string);
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      AService.Renovar(ARefresh);
    end,
    ENaoAutorizado, TAuthService.MENSAGEM_SESSAO_EXPIRADA);
end;

procedure TTestsAuthService.LoginDevolveRefreshEGuardaSoOHash;
var
  LToken: TTokenAcesso;
  LSessao: TSessao;
begin
  LToken := CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True))
    .Login('ana', 'ana123', 'Moto G');

  Assert.IsNotEmpty(LToken.RefreshToken);
  Assert.AreEqual(1, FSessoes.Sessoes.Count);
  LSessao := FSessoes.Sessoes[0];
  Assert.AreNotEqual(LToken.RefreshToken, LSessao.TokenHash);
  Assert.AreEqual(64, LSessao.TokenHash.Length);
  Assert.AreEqual('Moto G', LSessao.Dispositivo);
  Assert.AreEqual(IncDay(FAgora, 30), LSessao.ExpiraEm);
  Assert.AreEqual(IncDay(FAgora, 30), LToken.RefreshExpiraEm);
end;

procedure TTestsAuthService.RenovarRotacionaOToken;
var
  LService: IAuthService;
  R1, R2, R3: string;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True));
  R1 := LService.Login('ana', 'ana123', '').RefreshToken;
  R2 := LService.Renovar(R1).RefreshToken;

  Assert.AreNotEqual(R1, R2);
  Assert.IsTrue(FSessoes.Sessoes[0].Revogada, 'a sessão de r1 deveria estar revogada');
  Assert.AreEqual(FSessoes.Sessoes[0].Familia, FSessoes.Sessoes[1].Familia);

  R3 := LService.Renovar(R2).RefreshToken;
  Assert.IsNotEmpty(R3);
end;

procedure TTestsAuthService.ReusoDeTokenRevogadoDerrubaAFamilia;
var
  LService: IAuthService;
  R1, R2: string;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True));
  R1 := LService.Login('ana', 'ana123', '').RefreshToken;
  R2 := LService.Renovar(R1).RefreshToken;

  VerificarSessaoExpirada(LService, R1); // alguém reusou o token antigo
  VerificarSessaoExpirada(LService, R2); // então o atual também cai
end;

procedure TTestsAuthService.RefreshExpiradoRecusado;
var
  LService: IAuthService;
  R1: string;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True));
  R1 := LService.Login('ana', 'ana123', '').RefreshToken;
  FAgora := IncDay(FAgora, 31);
  VerificarSessaoExpirada(LService, R1);
end;

procedure TTestsAuthService.RefreshDeUsuarioInativoRecusado;
var
  LRepo: TUsuarioRepositoryFake;
  LRepoIntf: IUsuarioRepository;
  LService: IAuthService;
  R1: string;
begin
  LRepo := TUsuarioRepositoryFake.Create('ana', 'ana123', True);
  LRepoIntf := LRepo;
  LService := CriarService(LRepoIntf);
  R1 := LService.Login('ana', 'ana123', '').RefreshToken;
  LRepo.Usuario.Ativo := False;
  VerificarSessaoExpirada(LService, R1);
end;

procedure TTestsAuthService.RefreshDesconhecidoRecusado;
begin
  VerificarSessaoExpirada(CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True)), 'qualquer-coisa');
  VerificarSessaoExpirada(CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True)), '');
end;

procedure TTestsAuthService.SairRevogaASessao;
var
  LService: IAuthService;
  R1: string;
begin
  LService := CriarService(TUsuarioRepositoryFake.Create('ana', 'ana123', True));
  R1 := LService.Login('ana', 'ana123', '').RefreshToken;
  LService.Sair(R1);
  VerificarSessaoExpirada(LService, R1);

  LService.Sair('token-que-nao-existe'); // não deve levantar erro
  Assert.Pass;
end;

procedure TTestsAuthService.Login_CredenciaisValidas_RetornaToken;
var
  LToken: TTokenAcesso;
begin
  LToken := CriarService(TUsuarioRepositoryFake.Create('admin', 'senha123', True))
    .Login('admin', 'senha123', '');

  Assert.AreEqual(TOKEN_FAKE, LToken.Token);
end;

procedure TTestsAuthService.Login_NormalizaLoginAntesDeBuscar;
var
  LRepositorio: TUsuarioRepositoryFake;
  LRepositorioIntf: IUsuarioRepository;
begin
  LRepositorio := TUsuarioRepositoryFake.Create('admin', 'senha123', True);
  LRepositorioIntf := LRepositorio; // mantém a referência viva durante o teste

  CriarService(LRepositorioIntf).Login('  Admin ', 'senha123', '');

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
      LService.Login('admin', 'errada', '');
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
      LService.Login('ninguem', 'senha123', '');
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
      LService.Login('admin', 'senha123', '');
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
      LService.Login(ALogin, ASenha, '');
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
