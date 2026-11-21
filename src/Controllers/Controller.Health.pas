unit Controller.Health;

interface

type
  TControllerHealth = class
  public
    class procedure Registrar; static;
  end;

implementation

uses
  System.JSON, Horse;

class procedure TControllerHealth.Registrar;
begin
  THorse.Get('/health',
    procedure(AReq: THorseRequest; ARes: THorseResponse)
    begin
      ARes.Send<TJSONObject>(TJSONObject.Create.AddPair('status', 'ok'));
    end);
end;

end.
