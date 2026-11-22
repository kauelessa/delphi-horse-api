unit Repository.Visita;

interface

uses
  System.Generics.Collections, Model.Visita, Model.Paginacao;

type
  IVisitaRepository = interface
    ['{2E8B6C40-7F19-4D3A-9C52-A1E4B07D3F68}']
    function Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TVisita>;
    function BuscarPorUuid(const AUuid: string): TVisita; // nil se não achar
    // levanta EUuidDuplicado se outra visita com o mesmo UUID gravou antes
    procedure Inserir(AVisita: TVisita);
  end;

  TVisitaRepository = class(TInterfacedObject, IVisitaRepository)
  public
    function Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync; out ATotal: Integer): TObjectList<TVisita>;
    function BuscarPorUuid(const AUuid: string): TVisita;
    procedure Inserir(AVisita: TVisita);
  end;

implementation

uses
  System.SysUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Stan.Error,
  Infra.Conexao, Infra.Excecoes;

const
  SQL_SELECT =
    'SELECT V.ID, V.UUID, V.CLIENTE_ID, C.NOME AS NOME_CLIENTE, V.USUARIO_ID, V.DATA_VISITA, ' +
    '       V.LATITUDE, V.LONGITUDE, V.PRECISAO_M, V.MOTIVO, V.OBSERVACAO, V.ATUALIZADO_EM ' +
    '  FROM VISITAS V ' +
    '  JOIN CLIENTES C ON C.ID = V.CLIENTE_ID ';

function LerVisita(AQry: TFDQuery): TVisita;
begin
  Result := TVisita.Create;
  Result.Id := AQry.FieldByName('ID').AsInteger;
  Result.Uuid := Trim(AQry.FieldByName('UUID').AsString);
  Result.ClienteId := AQry.FieldByName('CLIENTE_ID').AsInteger;
  Result.NomeCliente := AQry.FieldByName('NOME_CLIENTE').AsString;
  Result.UsuarioId := AQry.FieldByName('USUARIO_ID').AsInteger;
  Result.Data := AQry.FieldByName('DATA_VISITA').AsDateTime;
  if not AQry.FieldByName('LATITUDE').IsNull then
    Result.DefinirLocalizacao(AQry.FieldByName('LATITUDE').AsFloat, AQry.FieldByName('LONGITUDE').AsFloat,
      AQry.FieldByName('PRECISAO_M').AsFloat);
  Result.Motivo := TMotivoVisita.DeTexto(AQry.FieldByName('MOTIVO').AsString);
  Result.Observacao := AQry.FieldByName('OBSERVACAO').AsString;
  Result.AtualizadoEm := AQry.FieldByName('ATUALIZADO_EM').AsDateTime;
end;

function TVisitaRepository.Listar(const APaginacao: TPaginacao; const ASync: TFiltroSync;
  out ATotal: Integer): TObjectList<TVisita>;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
  LWhere: string;

  procedure Parametros;
  begin
    if ASync.UsuarioId > 0 then
      LQry.ParamByName('USUARIO_ID').AsInteger := ASync.UsuarioId;
    if ASync.Ativo then
      LQry.ParamByName('DESDE').AsDateTime := ASync.Desde;
  end;

begin
  LWhere := 'WHERE 1 = 1';
  if ASync.UsuarioId > 0 then
    LWhere := LWhere + ' AND V.USUARIO_ID = :USUARIO_ID';
  if ASync.Ativo then
    LWhere := LWhere + ' AND V.ATUALIZADO_EM >= :DESDE';

  Result := TObjectList<TVisita>.Create;
  try
    LCon := TConexao.Criar;
    LQry := TFDQuery.Create(nil);
    try
      LQry.Connection := LCon;
      LQry.SQL.Text := 'SELECT COUNT(*) FROM VISITAS V ' + LWhere;
      Parametros;
      LQry.Open;
      ATotal := LQry.Fields[0].AsInteger;
      LQry.Close;

      if ASync.Ativo then
        LQry.SQL.Text := SQL_SELECT + LWhere + ' ORDER BY V.ATUALIZADO_EM, V.ID'
      else
        LQry.SQL.Text := SQL_SELECT + LWhere + ' ORDER BY V.DATA_VISITA DESC, V.ID DESC';
      LQry.SQL.Add('OFFSET :OFFSET ROWS FETCH NEXT :LIMITE ROWS ONLY');
      Parametros;
      LQry.ParamByName('OFFSET').AsInteger := APaginacao.Offset;
      LQry.ParamByName('LIMITE').AsInteger := APaginacao.Limite;
      LQry.Open;
      while not LQry.Eof do
      begin
        Result.Add(LerVisita(LQry));
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

function TVisitaRepository.BuscarPorUuid(const AUuid: string): TVisita;
var
  LCon: TFDConnection;
  LQry: TFDQuery;
begin
  Result := nil;
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.Open(SQL_SELECT + 'WHERE V.UUID = :UUID', [AUuid]);
    if not LQry.IsEmpty then
      Result := LerVisita(LQry);
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

procedure TVisitaRepository.Inserir(AVisita: TVisita);
var
  LCon: TFDConnection;
  LQry: TFDQuery;

  procedure Opcional(const ANome: string; ATipo: TFieldType; const AValor: Variant; ATem: Boolean);
  begin
    LQry.ParamByName(ANome).DataType := ATipo;
    if ATem then
      LQry.ParamByName(ANome).Value := AValor
    else
      LQry.ParamByName(ANome).Clear;
  end;

begin
  LCon := TConexao.Criar;
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := LCon;
    LQry.SQL.Text :=
      'INSERT INTO VISITAS (UUID, CLIENTE_ID, USUARIO_ID, DATA_VISITA, LATITUDE, LONGITUDE, PRECISAO_M, ' +
      '  MOTIVO, OBSERVACAO) ' +
      'VALUES (:UUID, :CLIENTE_ID, :USUARIO_ID, :DATA_VISITA, :LATITUDE, :LONGITUDE, :PRECISAO_M, ' +
      '  :MOTIVO, :OBSERVACAO) RETURNING ID, ATUALIZADO_EM';
    LQry.ParamByName('UUID').AsString := AVisita.Uuid;
    LQry.ParamByName('CLIENTE_ID').AsInteger := AVisita.ClienteId;
    LQry.ParamByName('USUARIO_ID').AsInteger := AVisita.UsuarioId;
    LQry.ParamByName('DATA_VISITA').AsDateTime := AVisita.Data;
    Opcional('LATITUDE', ftFloat, AVisita.Latitude, AVisita.TemLocalizacao);
    Opcional('LONGITUDE', ftFloat, AVisita.Longitude, AVisita.TemLocalizacao);
    Opcional('PRECISAO_M', ftFloat, AVisita.Precisao, AVisita.TemLocalizacao);
    LQry.ParamByName('MOTIVO').AsString := AVisita.Motivo.ToString;
    Opcional('OBSERVACAO', ftWideString, AVisita.Observacao, AVisita.Observacao <> '');
    try
      LQry.Open;
    except
      // pelo nome do índice: com a outra transação aberta o Kind não vem como ekUKViolated
      on E: EFDDBEngineException do
        if E.Message.ToUpper.Contains('UQ_VISITAS_UUID') then
          raise EUuidDuplicado.Create(E.Message)
        else
          raise;
    end;
    AVisita.Id := LQry.FieldByName('ID').AsInteger;
    AVisita.AtualizadoEm := LQry.FieldByName('ATUALIZADO_EM').AsDateTime;
  finally
    LQry.Free;
    LCon.Free;
  end;
end;

end.
