unit Infra.Config;

{ Configuração da aplicação, lida uma única vez na inicialização a partir
  do config.ini. Depois de carregada é somente leitura, portanto segura
  para ser consultada pelas threads das requisições. }

interface

type
  TConfigBanco = record
    Servidor: string;
    Porta: Integer;
    Arquivo: string;
    Usuario: string;
    Senha: string;
    BibliotecaCliente: string;
  end;

  TConfigJWT = record
    Segredo: string;
    Emissor: string;
    ExpiracaoMinutos: Integer;
  end;

  TConfig = class
  strict private
    class var FPortaServidor: Integer;
    class var FBanco: TConfigBanco;
    class var FJWT: TConfigJWT;
    class procedure Validar; static;
  public
    const TAMANHO_MINIMO_SEGREDO = 32;

    class procedure Carregar(const AArquivo: string); static;
    class function ArquivoPadrao: string; static;

    class property PortaServidor: Integer read FPortaServidor;
    class property Banco: TConfigBanco read FBanco;
    class property JWT: TConfigJWT read FJWT;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

class function TConfig.ArquivoPadrao: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'config.ini';
end;

class procedure TConfig.Carregar(const AArquivo: string);
var
  LIni: TMemIniFile;
begin
  if not FileExists(AArquivo) then
    raise Exception.CreateFmt(
      'Arquivo de configuração não encontrado: %s. ' +
      'Copie o config.example.ini para config.ini e ajuste os valores.', [AArquivo]);

  LIni := TMemIniFile.Create(AArquivo, TEncoding.UTF8);
  try
    FPortaServidor := LIni.ReadInteger('Servidor', 'Porta', 9000);

    FBanco.Servidor := LIni.ReadString('Banco', 'Servidor', 'localhost');
    FBanco.Porta := LIni.ReadInteger('Banco', 'Porta', 3050);
    FBanco.Arquivo := LIni.ReadString('Banco', 'Arquivo', '');
    FBanco.Usuario := LIni.ReadString('Banco', 'Usuario', '');
    FBanco.Senha := LIni.ReadString('Banco', 'Senha', '');
    FBanco.BibliotecaCliente := LIni.ReadString('Banco', 'BibliotecaCliente', '');

    FJWT.Segredo := LIni.ReadString('JWT', 'Segredo', '');
    FJWT.Emissor := LIni.ReadString('JWT', 'Emissor', 'delphi-horse-api');
    FJWT.ExpiracaoMinutos := LIni.ReadInteger('JWT', 'ExpiracaoMinutos', 60);
  finally
    LIni.Free;
  end;

  Validar;
end;

class procedure TConfig.Validar;
begin
  if FBanco.Arquivo.Trim.IsEmpty then
    raise Exception.Create('Configuração inválida: [Banco] Arquivo não informado.');

  if FJWT.Segredo.Length < TAMANHO_MINIMO_SEGREDO then
    raise Exception.CreateFmt(
      'Configuração inválida: [JWT] Segredo deve ter pelo menos %d caracteres.',
      [TAMANHO_MINIMO_SEGREDO]);

  if FJWT.ExpiracaoMinutos <= 0 then
    raise Exception.Create('Configuração inválida: [JWT] ExpiracaoMinutos deve ser maior que zero.');
end;

end.
