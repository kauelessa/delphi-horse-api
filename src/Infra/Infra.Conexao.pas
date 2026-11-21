unit Infra.Conexao;

{ Fábrica de conexões FireDAC com Firebird.

  O Horse atende cada requisição em uma thread, e TFDConnection não deve
  ser compartilhada entre threads. Por isso registramos uma definição de
  conexão com pool (Pooled=True) e cada repositório cria a sua própria
  TFDConnection a partir dela: criar/liberar a conexão apenas pega e
  devolve uma conexão física do pool. }

interface

uses
  FireDAC.Comp.Client,
  Infra.Config;

type
  TConexao = class
  strict private
    class var FConfigurada: Boolean;
  public
    const NOME_DEFINICAO = 'DelphiHorseApi_Firebird';
    const MAXIMO_CONEXOES_POOL = 50;

    class procedure Configurar(const ABanco: TConfigBanco); static;
    { O chamador é responsável por liberar a conexão retornada. }
    class function Criar: TFDConnection; static;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
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

class procedure TConexao.Configurar(const ABanco: TConfigBanco);
var
  LParametros: TStringList;
begin
  if not ABanco.BibliotecaCliente.Trim.IsEmpty then
  begin
    GDriverLink := TFDPhysFBDriverLink.Create(nil);
    GDriverLink.VendorLib := ABanco.BibliotecaCliente;
  end;

  LParametros := TStringList.Create;
  try
    LParametros.Values['Server'] := ABanco.Servidor;
    LParametros.Values['Port'] := ABanco.Porta.ToString;
    LParametros.Values['Database'] := ABanco.Arquivo;
    LParametros.Values['User_Name'] := ABanco.Usuario;
    LParametros.Values['Password'] := ABanco.Senha;
    LParametros.Values['Protocol'] := 'TCPIP';
    LParametros.Values['CharacterSet'] := 'UTF8';
    LParametros.Values['Pooled'] := 'True';
    LParametros.Values['POOL_MaximumItems'] := MAXIMO_CONEXOES_POOL.ToString;

    FDManager.AddConnectionDef(NOME_DEFINICAO, 'FB', LParametros);
  finally
    LParametros.Free;
  end;

  FConfigurada := True;
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
