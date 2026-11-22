unit Repository.Relogio;

interface

type
  IRelogioRepository = interface
    ['{6A0E2F51-93C4-4B7D-A8E2-1F5C3D7B9E46}']
    // hora do banco, a mesma base de tempo do ATUALIZADO_EM
    function AgoraNoServidor: TDateTime;
  end;

  TRelogioRepository = class(TInterfacedObject, IRelogioRepository)
  public
    function AgoraNoServidor: TDateTime;
  end;

const
  // Uma transação pode gravar ATUALIZADO_EM às 10:00:00 e só confirmar às 10:00:05;
  // quem sincronizou às 10:00:02 não a viu. Devolver a marca um pouco atrasada faz a
  // próxima sincronização pegar de novo esse intervalo (o app grava por id, repetir não faz mal).
  MARGEM_SINCRONIZACAO_MINUTOS = 2;

{ Marca "servidorEm" das listagens: lida ANTES da consulta e já com a margem. }
function MarcaDeSincronizacao(const ARelogio: IRelogioRepository): TDateTime;

implementation

uses
  System.SysUtils, System.DateUtils, FireDAC.Comp.Client, Infra.Conexao;

function MarcaDeSincronizacao(const ARelogio: IRelogioRepository): TDateTime;
var
  LAgora: TDateTime;
begin
  if Assigned(ARelogio) then
    LAgora := ARelogio.AgoraNoServidor
  else
    LAgora := Now;
  Result := IncMinute(LAgora, -MARGEM_SINCRONIZACAO_MINUTOS);
end;

function TRelogioRepository.AgoraNoServidor: TDateTime;
var
  LCon: TFDConnection;
begin
  LCon := TConexao.Criar;
  try
    Result := LCon.ExecSQLScalar('SELECT LOCALTIMESTAMP FROM RDB$DATABASE');
  finally
    LCon.Free;
  end;
end;

end.
