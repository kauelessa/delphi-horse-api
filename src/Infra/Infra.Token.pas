unit Infra.Token;

{ Abstração do gerador de tokens de acesso. Fica separada da implementação
  JWT (Infra.JWT) para que os testes de Service não dependam da biblioteca
  JOSE. }

interface

uses
  Model.Usuario;

type
  TTokenAcesso = record
    Token: string;
    ExpiraEm: TDateTime;
  end;

  IGeradorToken = interface
    ['{543A403E-967C-4DB9-B5FE-14DDF5A7C0F1}']
    function Gerar(const AUsuario: TUsuario): TTokenAcesso;
  end;

implementation

end.
