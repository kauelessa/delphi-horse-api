unit Repository.Cliente;

interface

uses
  System.SysUtils, System.Generics.Collections, Model.Cliente, Model.Paginacao;

type
  IClienteRepository = interface
    ['{71B2C062-19ED-40BC-AFE0-FA17E92AEEDE}']
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TCliente>;
    function BuscarPorId(AId: Integer): TCliente; // só ativos; nil se não achar
    function BuscarPorUuid(const AUuid: string): TCliente; // ativo ou não; nil se não achar
    procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
    procedure GravarFoto(AId: Integer; const AFoto: TBytes);
    function LerFoto(AId: Integer): TBytes; // vazio se não tiver
    function DocumentoEmUso(const ADocumento: string; AIgnorarId: Integer): Boolean;
    procedure Inserir(ACliente: TCliente);
    procedure Atualizar(ACliente: TCliente);
    procedure Inativar(AId: Integer);
  end;

  TClienteRepository = class(TInterfacedObject, IClienteRepository)
  public
    function Listar(const APaginacao: TPaginacao; const ABusca: string; const ASync: TFiltroSync;
      out ATotal: Integer): TObjectList<TCliente>;
    function BuscarPorId(AId: Integer): TCliente;
    function BuscarPorUuid(const AUuid: string): TCliente;
    procedure GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
    procedure GravarFoto(AId: Integer; const AFoto: TBytes);
    function LerFoto(AId: Integer): TBytes;
    function DocumentoEmUso(const ADocumento: string; AIgnorarId: Integer): Boolean;
    procedure Inserir(ACliente: TCliente);
    procedure Atualizar(ACliente: TCliente);
    procedure Inativar(AId: Integer);
    /// WHERE da listagem e valores dos parâmetros :BUSCA e :DOCUMENTO.
    /// O texto da busca nunca entra no SQL, só nos parâmetros.
    class function Filtro(const ABusca: string; out ABuscaParam, ADocumentoParam: string): string; overload; static;
    /// Com ASync ativo a base deixa de ser "só ativos" e passa a ser "alterados desde".
    class function Filtro(const ABusca: string; out ABuscaParam, ADocumentoParam: string;
      const ASync: TFiltroSync): string; overload; static;
  end;

implementation

uses
  System.Classes, System.Variants, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Stan.Error,
  Model.Documento, Infra.Conexao, Infra.Excecoes;

const
  SQL_SELECT = 'SELECT ID, NOME, DOCUMENTO, EMAIL, TELEFONE, ATIVO, ATUALIZADO_EM, UUID, ' +
    'LATITUDE, LONGITUDE, CASE WHEN FOTO IS NULL THEN FALSE ELSE TRUE END AS TEM_FOTO FROM CLIENTES ';

// na sincronização a ordem precisa ser estável entre páginas mesmo com nomes iguais
function OrdemListagem(const ASync: TFiltroSync; const AOrdemNormal: string): string;
begin
  if ASync.Ativo then
    Result := ' ORDER BY ATUALIZADO_EM, ID'
  else
    Result := ' ORDER BY ' + AOrdemNormal;
end;

function LerCliente(AQry: TFDQuery): TCliente;
begin
  Result := TCliente.Create;
  Result.Id := AQry.FieldByName('ID').AsInteger;
  Result.Nome := AQry.FieldByName('NOME').AsString;
  Result.Documento := AQry.FieldByName('DOCUMENTO').AsString;
  Result.Email := AQry.FieldByName('EMAIL').AsString;
  Result.Telefone := AQry.FieldByName('TELEFONE').AsString;
  Result.Ativo := AQry.FieldByName('ATIVO').AsBoolean;
  Result.AtualizadoEm := AQry.FieldByName('ATUALIZADO_EM').AsDateTime;
  Result.Uuid := Trim(AQry.FieldByName('UUID').AsString);
  if not AQry.FieldByName('LATITUDE').IsNull then
    Result.DefinirLocalizacao(AQry.FieldByName('LATITUDE').AsFloat, AQry.FieldByName('LONGITUDE').AsFloat);
  Result.TemFoto := AQry.FieldByName('TEM_FOTO').AsBoolean;
end;

// corrida no índice único: decide se foi o UUID (reenvio) ou o documento
procedure TratarViolacaoUnica(E: EFDDBEngineException);
begin
  if E.Message.ToUpper.Contains('UQ_CLIENTES_UUID') then
    raise EUuidDuplicado.Create(E.Message);
  raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.');
end;

// email/telefone vazios vão como NULL
procedure PreencherParams(AQry: TFDQuery; ACliente: TCliente);
  procedure Opcional(const ANome, AValor: string);
  begin
    AQry.ParamByName(ANome).DataType := ftWideString;
    if AValor.IsEmpty then
      AQry.ParamByName(ANome).Clear
    else
      AQry.ParamByName(ANome).AsWideString := AValor;
  end;
begin
  AQry.ParamByName('NOME').AsWideString := ACliente.Nome;
  AQry.ParamByName('DOCUMENTO').AsWideString := ACliente.Documento;
  Opcional('EMAIL', ACliente.Email);
  Opcional('TELEFONE', ACliente.Telefone);
end;

class function TClienteRepository.Filtro(const ABusca: string; out ABuscaParam,
  ADocumentoParam: string): string;
begin
  Result := Filtro(ABusca, ABuscaParam, ADocumentoParam, TFiltroSync.Nenhum);
end;

class function TClienteRepository.Filtro(const ABusca: string; out ABuscaParam,
  ADocumentoParam: string; const ASync: TFiltroSync): string;
begin
  if ASync.Ativo then
    Result := 'WHERE ATUALIZADO_EM >= :DESDE'
  else
    Result := 'WHERE ATIVO = TRUE';
  ABuscaParam := Trim(ABusca);
  ADocumentoParam := '';
  if ABuscaParam = '' then
    Exit;

  // documento é gravado normalizado, então "529.982.247-25" precisa virar "52998224725"
  ADocumentoParam := TDocumento.Normalizar(ABuscaParam);
  if ADocumentoParam = '' then
    Result := Result + ' AND (NOME CONTAINING :BUSCA)'
  else
    Result := Result + ' AND (NOME CONTAINING :BUSCA OR DOCUMENTO CONTAINING :DOCUMENTO)';
end;

function TClienteRepository.Listar(const APaginacao: TPaginacao; const ABusca: string;
  const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TCliente>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LWhere, LBusca, LDocumento: string;

  procedure PreencherFiltro(AQry: TFDQuery);
  begin
    if ASync.Ativo then
      AQry.ParamByName('DESDE').AsDateTime := ASync.Desde;
    if LBusca = '' then
      Exit;
    AQry.ParamByName('BUSCA').AsString := LBusca;
    if LDocumento <> '' then
      AQry.ParamByName('DOCUMENTO').AsString := LDocumento;
  end;

begin
  LWhere := Filtro(ABusca, LBusca, LDocumento, ASync);
  Result := TObjectList<TCliente>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM CLIENTES ' + LWhere;
      PreencherFiltro(LQry);
      LQry.Open;
      ATotal := LQry.Fields[0].AsInteger;
      LQry.Close;

      LQry.SQL.Text := SQL_SELECT + LWhere + OrdemListagem(ASync, 'NOME') +
        ' OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY';
      PreencherFiltro(LQry);
      LQry.ParamByName('OFFSET').AsInteger := APaginacao.Offset;
      LQry.ParamByName('LIMITE').AsInteger := APaginacao.Limite;
      LQry.Open;
      while not LQry.Eof do
      begin
        Result.Add(LerCliente(LQry));
        LQry.Next;
      end;
    finally
      LQry.Free;
      LCon.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TClienteRepository.BuscarPorId(AId: Integer): TCliente;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text := SQL_SELECT + 'WHERE ID = :ID AND ATIVO = TRUE';
    LQry.ParamByName('ID').AsInteger := AId;
    LQry.Open;
    if not LQry.IsEmpty then
      Result := LerCliente(LQry);
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TClienteRepository.BuscarPorUuid(const AUuid: string): TCliente;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open(SQL_SELECT + 'WHERE UUID = :UUID', [AUuid]);
    if not LQry.IsEmpty then
      Result := LerCliente(LQry);
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TClienteRepository.GravarLocalizacao(AId: Integer; ALatitude, ALongitude: Double);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL('UPDATE CLIENTES SET LATITUDE = :LAT, LONGITUDE = :LON WHERE ID = :ID',
      [ALatitude, ALongitude, AId]);
  finally
    LCon.Free;
  end;
end;

procedure TClienteRepository.GravarFoto(AId: Integer; const AFoto: TBytes);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LStream: TBytesStream;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  LStream := TBytesStream.Create(AFoto);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text := 'UPDATE CLIENTES SET FOTO = :FOTO WHERE ID = :ID';
    LQry.ParamByName('FOTO').LoadFromStream(LStream, ftBlob);
    LQry.ParamByName('ID').AsInteger := AId;
    LQry.ExecSQL;
  finally
    LStream.Free;
    LQry.Free;
    LCon.Free;
  end;
end;

function TClienteRepository.LerFoto(AId: Integer): TBytes;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open('SELECT FOTO FROM CLIENTES WHERE ID = :ID AND FOTO IS NOT NULL', [AId]);
    if not LQry.IsEmpty then
      Result := LQry.Fields[0].AsBytes;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

function TClienteRepository.DocumentoEmUso(const ADocumento: string; AIgnorarId: Integer): Boolean;
var
  LCon: TFDConnection;
begin
  // considera inativos também: o UNIQUE do banco vale pra todos
  LCon := TConexao.Criar;
  try
    Result := LCon.ExecSQLScalar(
      'SELECT COUNT(*) FROM CLIENTES WHERE DOCUMENTO = :DOCUMENTO AND ID <> :ID',
      [ADocumento, AIgnorarId]) > 0;
  finally
    LCon.Free;
  end;
end;

procedure TClienteRepository.Inserir(ACliente: TCliente);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'INSERT INTO CLIENTES (NOME, DOCUMENTO, EMAIL, TELEFONE, UUID, LATITUDE, LONGITUDE) ' +
      'VALUES (:NOME, :DOCUMENTO, :EMAIL, :TELEFONE, :UUID, :LATITUDE, :LONGITUDE) RETURNING ID, ATUALIZADO_EM';
    PreencherParams(LQry, ACliente);
    LQry.ParamByName('UUID').DataType := ftString;
    if ACliente.Uuid = '' then
      LQry.ParamByName('UUID').Clear
    else
      LQry.ParamByName('UUID').AsString := ACliente.Uuid;
    LQry.ParamByName('LATITUDE').DataType := ftFloat;
    LQry.ParamByName('LONGITUDE').DataType := ftFloat;
    if ACliente.TemLocalizacao then
    begin
      LQry.ParamByName('LATITUDE').AsFloat := ACliente.Latitude;
      LQry.ParamByName('LONGITUDE').AsFloat := ACliente.Longitude;
    end
    else
    begin
      LQry.ParamByName('LATITUDE').Clear;
      LQry.ParamByName('LONGITUDE').Clear;
    end;
    try
      LQry.Open;
    except
      // corrida entre dois cadastros com o mesmo documento/UUID: o UNIQUE segura
      on E: EFDDBEngineException do
        if E.Message.ToUpper.Contains('UQ_CLIENTES_UUID') or (E.Kind = ekUKViolated) then
          TratarViolacaoUnica(E)
        else
          raise;
    end;
    ACliente.Id := LQry.FieldByName('ID').AsInteger;
    ACliente.AtualizadoEm := LQry.FieldByName('ATUALIZADO_EM').AsDateTime;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TClienteRepository.Atualizar(ACliente: TCliente);
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'UPDATE CLIENTES SET NOME = :NOME, DOCUMENTO = :DOCUMENTO, EMAIL = :EMAIL, ' +
      'TELEFONE = :TELEFONE WHERE ID = :ID';
    PreencherParams(LQry, ACliente);
    LQry.ParamByName('ID').AsInteger := ACliente.Id;
    try
      LQry.ExecSQL;
    except
      on E: EFDDBEngineException do
        if E.Kind = ekUKViolated then
          raise ERegraNegocio.Create('Já existe um cliente com este CPF/CNPJ.')
        else
          raise;
    end;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TClienteRepository.Inativar(AId: Integer);
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    LCon.ExecSQL('UPDATE CLIENTES SET ATIVO = FALSE WHERE ID = :ID', [AId]);
  finally
    LCon.Free;
  end;
end;

end.
