unit Infra.Migracao;

{ Migrações de banco aplicadas na inicialização da API.

  Os scripts .sql da pasta configurada (database/ por padrão) rodam em ordem
  alfabética do nome do arquivo, por isso a numeração 001_, 002_... Cada
  script aplicado é registrado na tabela SCHEMA_VERSAO e nunca roda de novo,
  então um script já publicado não deve ser alterado: crie um novo.

  Scripts com "_seed_" no nome trazem dados de exemplo (inclusive o usuário
  admin/admin123) e só rodam com [Migracao] ExecutarSeeds=1. Um seed pulado
  não é registrado: se a opção for ligada depois, ele roda na próxima subida.

  Cada script roda dentro de uma transação explícita. Como os scripts
  terminam com COMMIT próprio (para também rodarem no isql), uma falha no
  meio de um script pode deixar parte dele aplicada. Nesse caso a API não
  sobe, mostra o erro, e o script não é marcado como aplicado. }

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  Infra.Config;

type
  TMigrador = class
  strict private
    FConfig: TConfigMigracao;
    FUltimoErro: string;
    constructor Create(const AConfig: TConfigMigracao);
    procedure ScriptErro(ASender, AInitiator: TObject; var AException: Exception);
    procedure GarantirTabelaControle(ACon: TFDConnection);
    procedure CarregarAplicados(ACon: TFDConnection; AAplicados: TStrings);
    procedure AplicarScript(ACon: TFDConnection; const AArquivo: string);
    function Aplicar: TArray<string>;
  public
    const MARCADOR_SEED = '_seed_';

    { Aplica os scripts pendentes e devolve os nomes dos que foram executados. }
    class function Executar(const AConfig: TConfigMigracao): TArray<string>; static;

    { Regras de seleção, separadas do banco para serem testadas isoladamente.
      AAplicados deve ser uma lista sem diferenciação de maiúsculas. }
    class function EhSeed(const AArquivo: string): Boolean; static;
    class function ScriptsPendentes(const AArquivos: TArray<string>;
      AAplicados: TStrings; AExecutarSeeds: Boolean): TArray<string>; static;
  end;

implementation

uses
  System.IOUtils,
  System.StrUtils,
  System.Generics.Defaults,
  System.Generics.Collections,
  FireDAC.Stan.Intf,
  FireDAC.Comp.Script,
  FireDAC.Comp.ScriptCommands, // registra COMMIT, SET TERM etc. no TFDScript
  Infra.Conexao;

{ TMigrador }

constructor TMigrador.Create(const AConfig: TConfigMigracao);
begin
  inherited Create;
  FConfig := AConfig;
end;

class function TMigrador.Executar(const AConfig: TConfigMigracao): TArray<string>;
var
  LMigrador: TMigrador;
begin
  LMigrador := TMigrador.Create(AConfig);
  try
    Result := LMigrador.Aplicar;
  finally
    LMigrador.Free;
  end;
end;

class function TMigrador.EhSeed(const AArquivo: string): Boolean;
begin
  Result := ContainsText(ExtractFileName(AArquivo), MARCADOR_SEED);
end;

class function TMigrador.ScriptsPendentes(const AArquivos: TArray<string>;
  AAplicados: TStrings; AExecutarSeeds: Boolean): TArray<string>;
var
  LOrdenados: TArray<string>;
  LPendentes: TList<string>;
  LArquivo: string;
begin
  LOrdenados := Copy(AArquivos);
  TArray.Sort<string>(LOrdenados, TComparer<string>.Construct(
    function(const AEsquerda, ADireita: string): Integer
    begin
      Result := CompareText(ExtractFileName(AEsquerda), ExtractFileName(ADireita));
    end));

  LPendentes := TList<string>.Create;
  try
    for LArquivo in LOrdenados do
    begin
      if AAplicados.IndexOf(ExtractFileName(LArquivo)) >= 0 then
        Continue;
      if EhSeed(LArquivo) and not AExecutarSeeds then
        Continue;
      LPendentes.Add(LArquivo);
    end;
    Result := LPendentes.ToArray;
  finally
    LPendentes.Free;
  end;
end;

function TMigrador.Aplicar: TArray<string>;
var
  LCon: TFDConnection;
  LAplicados: TStringList;
  LArquivo: string;
begin
  if not TDirectory.Exists(FConfig.Pasta) then
    raise Exception.CreateFmt('Pasta de scripts não encontrada: %s', [FConfig.Pasta]);

  LAplicados := TStringList.Create;
  LCon := TConexao.Criar;
  try
    LAplicados.CaseSensitive := False;

    GarantirTabelaControle(LCon);
    CarregarAplicados(LCon, LAplicados);

    Result := ScriptsPendentes(TDirectory.GetFiles(FConfig.Pasta, '*.sql'),
      LAplicados, FConfig.ExecutarSeeds);

    for LArquivo in Result do
    begin
      // Transação explícita é obrigatória: no autocommit cada comando já é
      // confirmado sozinho, e o COMMIT do script chega ao Firebird sem
      // transação aberta ("invalid transaction handle").
      LCon.StartTransaction;
      try
        AplicarScript(LCon, LArquivo);
        // se o script não terminar com COMMIT, o registro entra junto com ele
        if not LCon.InTransaction then
          LCon.StartTransaction;
        LCon.ExecSQL('INSERT INTO SCHEMA_VERSAO (SCRIPT) VALUES (:SCRIPT)',
          [ExtractFileName(LArquivo)]);
        LCon.Commit;
      except
        if LCon.InTransaction then
          LCon.Rollback;
        raise;
      end;
    end;
  finally
    LCon.Free;
    LAplicados.Free;
  end;
end;

procedure TMigrador.GarantirTabelaControle(ACon: TFDConnection);
begin
  if ACon.ExecSQLScalar(
    'SELECT COUNT(*) FROM RDB$RELATIONS WHERE RDB$RELATION_NAME = ''SCHEMA_VERSAO''') > 0 then
    Exit;

  ACon.ExecSQL(
    'CREATE TABLE SCHEMA_VERSAO (' +
    '  SCRIPT       VARCHAR(100) NOT NULL,' +
    '  APLICADO_EM  TIMESTAMP DEFAULT LOCALTIMESTAMP NOT NULL,' +
    '  CONSTRAINT PK_SCHEMA_VERSAO PRIMARY KEY (SCRIPT)' +
    ')');
end;

procedure TMigrador.CarregarAplicados(ACon: TFDConnection; AAplicados: TStrings);
var
  LQry: TFDQuery;
begin
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := ACon;
    LQry.Open('SELECT SCRIPT FROM SCHEMA_VERSAO');
    while not LQry.Eof do
    begin
      AAplicados.Add(LQry.Fields[0].AsString.Trim);
      LQry.Next;
    end;
  finally
    LQry.Free;
  end;
end;

procedure TMigrador.ScriptErro(ASender, AInitiator: TObject; var AException: Exception);
begin
  FUltimoErro := AException.Message;
end;

procedure TMigrador.AplicarScript(ACon: TFDConnection; const AArquivo: string);
var
  LScript: TFDScript;
  LSucesso: Boolean;
begin
  FUltimoErro := '';
  LScript := TFDScript.Create(nil);
  try
    LScript.Connection := ACon;
    LScript.ScriptOptions.FileEncoding := ecUTF8;
    LScript.ScriptOptions.BreakOnError := True;
    LScript.OnError := ScriptErro;
    LScript.SQLScriptFileName := AArquivo;

    try
      LSucesso := LScript.ExecuteAll;
    except
      on E: Exception do
        raise Exception.CreateFmt('Falha ao aplicar %s: %s', [ExtractFileName(AArquivo), E.Message]);
    end;

    if not LSucesso then
      raise Exception.CreateFmt('Falha ao aplicar %s: %s', [ExtractFileName(AArquivo), FUltimoErro]);
  finally
    LScript.Free;
  end;
end;

end.
