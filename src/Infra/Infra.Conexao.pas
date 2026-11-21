unit Infra.Conexao;

{ Fábrica de conexões FireDAC com Firebird.

  O Horse atende cada requisição em uma thread, e TFDConnection não deve
  ser compartilhada entre threads. Por isso registramos uma definição de
  conexão com pool (Pooled=True) e cada repositório cria a sua própria
  TFDConnection a partir dela: criar/liberar a conexão apenas pega e
  devolve uma conexão física do pool. }

interface

uses
  System.Classes,
  FireDAC.Comp.Client,
  Infra.Config;

type
  TConexao = class
  strict private
    class var FConfigurada: Boolean;
    class var FBanco: TConfigBanco;
    class procedure PreencherParametros(AParams: TStrings); static;
  public
    const NOME_DEFINICAO = 'DelphiHorseApi_Firebird';
    const MAXIMO_CONEXOES_POOL = 50;

    class procedure Configurar(const ABanco: TConfigBanco); static;
    { Cria o banco caso o arquivo ainda não exista no servidor (OpenMode =
      OpenOrCreate), com charset padrão UTF8. Usa uma conexão própria, fora
      do pool: o OpenOrCreate não deve valer para as conexões das requisições.
      O usuário configurado precisa ter permissão de criar bancos. }
    class procedure CriarBancoSeNaoExistir; static;
    { O chamador é responsável por liberar a conexão retornada. }
    class function Criar: TFDConnection; static;
  end;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.DApt,
  FireDAC.ConsoleUI.Wait;

var
  GDriverLink: TFDPhysFBDriverLink;

class procedure TConexao.PreencherParametros(AParams: TStrings);
begin
  AParams.Values['Server'] := FBanco.Servidor;
  AParams.Values['Port'] := FBanco.Porta.ToString;
  AParams.Values['Database'] := FBanco.Arquivo;
  AParams.Values['User_Name'] := FBanco.Usuario;
  AParams.Values['Password'] := FBanco.Senha;
  AParams.Values['Protocol'] := 'TCPIP';
  // Na criação do banco, também vira o DEFAULT CHARACTER SET.
  AParams.Values['CharacterSet'] := 'UTF8';
end;

class procedure TConexao.Configurar(const ABanco: TConfigBanco);
var
  LParametros: TStringList;
begin
  FBanco := ABanco;

  if not ABanco.BibliotecaCliente.Trim.IsEmpty then
  begin
    GDriverLink := TFDPhysFBDriverLink.Create(nil);
    GDriverLink.VendorLib := ABanco.BibliotecaCliente;
  end;

  LParametros := TStringList.Create;
  try
    PreencherParametros(LParametros);
    LParametros.Values['Pooled'] := 'True';
    LParametros.Values['POOL_MaximumItems'] := MAXIMO_CONEXOES_POOL.ToString;

    FDManager.AddConnectionDef(NOME_DEFINICAO, 'FB', LParametros);
  finally
    LParametros.Free;
  end;

  FConfigurada := True;
end;

class procedure TConexao.CriarBancoSeNaoExistir;
var
  LCon: TFDConnection;
begin
  if not FConfigurada then
    raise Exception.Create('Conexão não configurada. Chame TConexao.Configurar na inicialização.');

  LCon := TFDConnection.Create(nil);
  try
    LCon.DriverName := 'FB';
    LCon.LoginPrompt := False;
    PreencherParametros(LCon.Params);
    LCon.Params.Values['OpenMode'] := 'OpenOrCreate';
    LCon.Connected := True;
  finally
    LCon.Free;
  end;
end;

class function TConexao.Criar: TFDConnection;
begin
  if not FConfigurada then
    raise Exception.Create('Conexão não configurada. Chame TConexao.Configurar na inicialização.');

  Result := TFDConnection.Create(nil);
  try
    Result.ConnectionDefName := NOME_DEFINICAO;
    Result.LoginPrompt := False;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

initialization

finalization
  FDManager.Close;
  GDriverLink.Free;

end.
