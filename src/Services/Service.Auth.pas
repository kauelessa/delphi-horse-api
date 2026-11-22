unit Service.Auth;

interface

uses
  System.SysUtils,
  Repository.Usuario,
  Repository.Sessao,
  Infra.Token;

type
  IAuthService = interface
    ['{7A19C005-EE21-4919-A3B1-431322EE0614}']
    function Login(const ALogin, ASenha, ADispositivo: string): TTokenAcesso;
    function Renovar(const ARefreshToken: string): TTokenAcesso;
    procedure Sair(const ARefreshToken: string);
  end;

  { Login com senha devolve o access token (JWT curto) e um refresh token
    opaco. O refresh troca de valor a cada renovação (rotação): a linha
    antiga é revogada e uma nova entra na mesma família. Se um token já
    revogado aparecer de novo, alguém guardou uma cópia dele — a família
    inteira é revogada e o dono volta para o login com senha. }
  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FUsuarios: IUsuarioRepository;
    FSessoes: ISessaoRepository;
    FGeradorToken: IGeradorToken;
    FRefreshDias: Integer;
    FAgora: TFunc<TDateTime>;
    procedure EmitirRefresh(AUsuarioId: Integer; const AFamilia, ADispositivo: string;
      var AToken: TTokenAcesso);
    class function NovoRefreshToken: string; static;
    class function HashDoToken(const AToken: string): string; static;
  public
    const MENSAGEM_CREDENCIAIS_INVALIDAS = 'Login ou senha inválidos.';
    const MENSAGEM_SESSAO_EXPIRADA = 'Sessão expirada. Entre com usuário e senha.';

    constructor Create(const AUsuarios: IUsuarioRepository; const ASessoes: ISessaoRepository;
      const AGeradorToken: IGeradorToken; ARefreshDias: Integer; const AAgora: TFunc<TDateTime> = nil);
    function Login(const ALogin, ASenha, ADispositivo: string): TTokenAcesso;
    function Renovar(const ARefreshToken: string): TTokenAcesso;
    procedure Sair(const ARefreshToken: string);
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.NetEncoding,
  Model.Usuario,
  Model.Sessao,
  Infra.Excecoes,
  Infra.Senha;

const
  TAMANHO_REFRESH = 32; // bytes
  TAMANHO_DISPOSITIVO = 100;

constructor TAuthService.Create(const AUsuarios: IUsuarioRepository; const ASessoes: ISessaoRepository;
  const AGeradorToken: IGeradorToken; ARefreshDias: Integer; const AAgora: TFunc<TDateTime>);
begin
  inherited Create;
  FUsuarios := AUsuarios;
  FSessoes := ASessoes;
  FGeradorToken := AGeradorToken;
  FRefreshDias := ARefreshDias;
  if Assigned(AAgora) then
    FAgora := AAgora
  else
    FAgora :=
      function: TDateTime
      begin
        Result := Now;
      end;
end;

class function TAuthService.NovoRefreshToken: string;
begin
  // base64url sem "=": vai em JSON e às vezes em URL sem precisar escapar
  Result := TNetEncoding.Base64String.EncodeBytesToString(BytesAleatorios(TAMANHO_REFRESH))
    .Replace('+', '-').Replace('/', '_').Replace('=', '');
end;

class function TAuthService.HashDoToken(const AToken: string): string;
begin
  Result := THashSHA2.GetHashString(AToken, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

procedure TAuthService.EmitirRefresh(AUsuarioId: Integer; const AFamilia, ADispositivo: string;
  var AToken: TTokenAcesso);
var
  LSessao: TSessao;
  LToken: string;
begin
  LToken := NovoRefreshToken;
  LSessao := TSessao.Create;
  try
    LSessao.Familia := AFamilia;
    LSessao.UsuarioId := AUsuarioId;
    LSessao.TokenHash := HashDoToken(LToken);
    LSessao.Dispositivo := Copy(ADispositivo.Trim, 1, TAMANHO_DISPOSITIVO);
    LSessao.CriadaEm := FAgora();
    LSessao.ExpiraEm := IncDay(LSessao.CriadaEm, FRefreshDias);
    FSessoes.Inserir(LSessao);

    AToken.RefreshToken := LToken;
    AToken.RefreshExpiraEm := LSessao.ExpiraEm;
  finally
    LSessao.Free;
  end;
end;

function TAuthService.Login(const ALogin, ASenha, ADispositivo: string): TTokenAcesso;
var
  LUsuario: TUsuario;
begin
  if ALogin.Trim.IsEmpty or ASenha.IsEmpty then
    raise ERequisicaoInvalida.Create('Informe login e senha.');

  LUsuario := FUsuarios.BuscarPorLogin(ALogin.Trim.ToLower);
  try
    // Mesma mensagem para usuário inexistente e senha errada,
    // para não revelar quais logins existem.
    if (LUsuario = nil) or not TSenhaHash.Verificar(ASenha, LUsuario.SenhaHash) then
      raise ENaoAutorizado.Create(MENSAGEM_CREDENCIAIS_INVALIDAS);

    if not LUsuario.Ativo then
      raise ENaoAutorizado.Create('Usuário inativo.');

    Result := FGeradorToken.Gerar(LUsuario);
    EmitirRefresh(LUsuario.Id, TGUID.NewGuid.ToString.Trim(['{', '}']).ToLower, ADispositivo, Result);
  finally
    LUsuario.Free;
  end;
end;

function TAuthService.Renovar(const ARefreshToken: string): TTokenAcesso;
var
  LSessao: TSessao;
  LUsuario: TUsuario;
begin
  if ARefreshToken.Trim.IsEmpty then
    raise ENaoAutorizado.Create(MENSAGEM_SESSAO_EXPIRADA);

  LSessao := FSessoes.BuscarPorHash(HashDoToken(ARefreshToken.Trim));
  try
    if LSessao = nil then
      raise ENaoAutorizado.Create(MENSAGEM_SESSAO_EXPIRADA);

    // Revogar só devolve True para quem chegou primeiro; token já revogado
    // (reuso) ou duas renovações simultâneas derrubam a família.
    if LSessao.Revogada or not FSessoes.Revogar(LSessao.Id) then
    begin
      FSessoes.RevogarFamilia(LSessao.Familia);
      raise ENaoAutorizado.Create(MENSAGEM_SESSAO_EXPIRADA);
    end;

    if LSessao.ExpiraEm <= FAgora() then
      raise ENaoAutorizado.Create(MENSAGEM_SESSAO_EXPIRADA);

    LUsuario := FUsuarios.BuscarPorId(LSessao.UsuarioId);
    try
      if (LUsuario = nil) or not LUsuario.Ativo then
      begin
        FSessoes.RevogarFamilia(LSessao.Familia);
        raise ENaoAutorizado.Create(MENSAGEM_SESSAO_EXPIRADA);
      end;

      Result := FGeradorToken.Gerar(LUsuario);
      EmitirRefresh(LUsuario.Id, LSessao.Familia, LSessao.Dispositivo, Result);
    finally
      LUsuario.Free;
    end;
  finally
    LSessao.Free;
  end;
end;

procedure TAuthService.Sair(const ARefreshToken: string);
var
  LSessao: TSessao;
begin
  if ARefreshToken.Trim.IsEmpty then
    Exit;
  LSessao := FSessoes.BuscarPorHash(HashDoToken(ARefreshToken.Trim));
  try
    // token desconhecido: nada a fazer, e não vale a pena avisar quem chamou
    if LSessao <> nil then
      FSessoes.RevogarFamilia(LSessao.Familia);
  finally
    LSessao.Free;
  end;
end;

end.
