unit Repository.Usuario;

interface

uses
  Model.Usuario;

type
  IUsuarioRepository = interface
    ['{36C914CB-2C39-42D5-80BA-71AFE6B17A0E}']
    function BuscarPorLogin(const ALogin: string): TUsuario; // nil se não achar, quem chama libera
  end;

  TUsuarioRepository = class(TInterfacedObject, IUsuarioRepository)
  public
    function BuscarPorLogin(const ALogin: string): TUsuario;
  end;

implementation

uses
  FireDAC.Comp.Client, Infra.Conexao;

function TUsuarioRepository.BuscarPorLogin(const ALogin: string): TUsuario;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text := 'SELECT ID, NOME, LOGIN, SENHA_HASH, ATIVO FROM USUARIOS WHERE LOGIN = :LOGIN';
    LQry.ParamByName('LOGIN').AsString := ALogin;
    LQry.Open;

    if LQry.IsEmpty then
      Exit;

    Result := TUsuario.Create;
    Result.Id := LQry.FieldByName('ID').AsInteger;
    Result.Nome := LQry.FieldByName('NOME').AsString;
    Result.Login := LQry.FieldByName('LOGIN').AsString;
    Result.SenhaHash := LQry.FieldByName('SENHA_HASH').AsString;
    Result.Ativo := LQry.FieldByName('ATIVO').AsBoolean;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

end.
