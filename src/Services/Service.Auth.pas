unit Service.Auth;

interface

uses
  Repository.Usuario,
  Infra.Token;

type
  IAuthService = interface
    ['{7A19C005-EE21-4919-A3B1-431322EE0614}']
    function Login(const ALogin, ASenha: string): TTokenAcesso;
  end;

  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FRepository: IUsuarioRepository;
    FGeradorToken: IGeradorToken;
  public
    const MENSAGEM_CREDENCIAIS_INVALIDAS = 'Login ou senha inválidos.';

    constructor Create(const ARepository: IUsuarioRepository;
      const AGeradorToken: IGeradorToken);
    function Login(const ALogin, ASenha: string): TTokenAcesso;
  end;

implementation

uses
  System.SysUtils,
  Model.Usuario,
  Infra.Excecoes,
  Infra.Senha;

constructor TAuthService.Create(const ARepository: IUsuarioRepository;
  const AGeradorToken: IGeradorToken);
begin
  inherited Create;
  FRepository := ARepository;
  FGeradorToken := AGeradorToken;
end;

function TAuthService.Login(const ALogin, ASenha: string): TTokenAcesso;
var
  LUsuario: TUsuario;
begin
  if ALogin.Trim.IsEmpty or ASenha.IsEmpty then
    raise ERequisicaoInvalida.Create('Informe login e senha.');

  LUsuario := FRepository.BuscarPorLogin(ALogin.Trim.ToLower);
  try
    // Mesma mensagem para usuário inexistente e senha errada,
    // para não revelar quais logins existem.
    if (LUsuario = nil) or not TSenhaHash.Verificar(ASenha, LUsuario.SenhaHash) then
      raise ENaoAutorizado.Create(MENSAGEM_CREDENCIAIS_INVALIDAS);

    if not LUsuario.Ativo then
      raise ENaoAutorizado.Create('Usuário inativo.');

    Result := FGeradorToken.Gerar(LUsuario);
  finally
    LUsuario.Free;
  end;
end;

end.
