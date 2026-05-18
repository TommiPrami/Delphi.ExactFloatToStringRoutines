program ExactFloatToStringDemo;

uses
  Forms,
  EFTSDForm.Main in 'EFTSDForm.Main.pas' {EFTSDMainForm},
  Delphi.ExactFloatToString in '..\Delphi.ExactFloatToString.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TFTSDMainForm, EFTSDMainForm);
  Application.Run;
end.
