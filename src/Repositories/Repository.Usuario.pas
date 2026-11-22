unit Repository.Usuario;

interface

uses
  Model.Usuario;

type
  IUsuarioRepository = interface
    ['{36C914CB-2C39-42D5-80BA-71AFE6B17A0E}']
    function BuscarPorLogin(const ALogin: string): TUsuario; // nil se não achar, quem chama libera
    function BuscarPorId(AId: Integer): TUsuario;
  end;

  TUsuarioRepository = class(TInterfacedObject, IUsuarioRepository)
  private
    function Buscar(const ACampo: string; const AValor: Variant): TUsuario;
  public
    function BuscarPorLogin(const ALogin: string): TUsuario;
    function BuscarPorId(AId: Integer): TUsuario;
  end;

implementation

uses
  FireDAC.Comp.Client, Data.DB, Infra.Conexao;

function TUsuarioRepository.BuscarPorLogin(const ALogin: string): TUsuario;
begin
  Result := Buscar('LOGIN', ALogin);
end;

function TUsuarioRepository.BuscarPorId(AId: Integer): TUsuario;
begin
  Result := Buscar('ID', AId);
end;

// ACampo vem só destes dois métodos, nunca do usuário
function TUsuarioRepository.Buscar(const ACampo: string; const AValor: Variant): TUsuario;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT ID, NOME, LOGIN, SENHA_HASH, ATIVO FROM USUARIOS WHERE ' + ACampo + ' = :VALOR',
      [AValor]);

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
