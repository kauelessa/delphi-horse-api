unit Repository.Sessao;

interface

uses
  Model.Sessao;

type
  ISessaoRepository = interface
    ['{B4E1C7A2-5D93-4F0B-8E6A-2C71D9F35A84}']
    procedure Inserir(ASessao: TSessao);
    function BuscarPorHash(const AHash: string): TSessao; // nil se não achar; quem chama libera
    // False se já estava revogada (outra renovação chegou antes)
    function Revogar(AId: Integer): Boolean;
    procedure RevogarFamilia(const AFamilia: string);
  end;

  TSessaoRepository = class(TInterfacedObject, ISessaoRepository)
  public
    procedure Inserir(ASessao: TSessao);
    function BuscarPorHash(const AHash: string): TSessao;
    function Revogar(AId: Integer): Boolean;
    procedure RevogarFamilia(const AFamilia: string);
  end;

implementation

uses
  System.SysUtils, FireDAC.Comp.Client, Data.DB, Infra.Conexao;

procedure TSessaoRepository.Inserir(ASessao: TSessao);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open(
      'INSERT INTO SESSOES (FAMILIA, USUARIO_ID, TOKEN_HASH, DISPOSITIVO, CRIADA_EM, EXPIRA_EM) ' +
      'VALUES (:FAMILIA, :USUARIO_ID, :TOKEN_HASH, :DISPOSITIVO, :CRIADA_EM, :EXPIRA_EM) RETURNING ID',
      [ASessao.Familia, ASessao.UsuarioId, ASessao.TokenHash, ASessao.Dispositivo,
       ASessao.CriadaEm, ASessao.ExpiraEm]);
    ASessao.Id := LQry.Fields[0].AsInteger;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TSessaoRepository.BuscarPorHash(const AHash: string): TSessao;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT ID, FAMILIA, USUARIO_ID, TOKEN_HASH, DISPOSITIVO, CRIADA_EM, EXPIRA_EM, REVOGADA ' +
      'FROM SESSOES WHERE TOKEN_HASH = :HASH', [AHash]);
    if LQry.IsEmpty then
      Exit;

    Result := TSessao.Create;
    Result.Id := LQry.FieldByName('ID').AsInteger;
    Result.Familia := Trim(LQry.FieldByName('FAMILIA').AsString);
    Result.UsuarioId := LQry.FieldByName('USUARIO_ID').AsInteger;
    Result.TokenHash := Trim(LQry.FieldByName('TOKEN_HASH').AsString);
    Result.Dispositivo := LQry.FieldByName('DISPOSITIVO').AsString;
    Result.CriadaEm := LQry.FieldByName('CRIADA_EM').AsDateTime;
    Result.ExpiraEm := LQry.FieldByName('EXPIRA_EM').AsDateTime;
    Result.Revogada := LQry.FieldByName('REVOGADA').AsBoolean;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TSessaoRepository.Revogar(AId: Integer): Boolean;
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    // a condição no WHERE decide quem ganha se duas renovações chegarem juntas
    Result := LCon.ExecSQL('UPDATE SESSOES SET REVOGADA = TRUE WHERE ID = :ID AND REVOGADA = FALSE',
      [AId]) > 0;
  finally
    LCon.Free;
  end;
end;

procedure TSessaoRepository.RevogarFamilia(const AFamilia: string);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL('UPDATE SESSOES SET REVOGADA = TRUE WHERE FAMILIA = :FAMILIA AND REVOGADA = FALSE',
      [AFamilia]);
  finally
    LCon.Free;
  end;
end;

end.
