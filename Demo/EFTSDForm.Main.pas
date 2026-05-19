unit EFTSDForm.Main;

(* *****************************************************************************

  For Testing ExactFloatToStr and ParseFloat functions.

  Pgm. 12/24/2002 by John Herbster.

**************************************************************************** *)

interface

uses
  System.Classes, Vcl.Controls, Vcl.Dialogs, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls;

type
  TFTSDMainForm = class(TForm)
    ButtonAnalyzeFloat: TButton;
    ButtonConvert: TButton;
    ButtonDenormal2: TButton;
    ButtonPi: TButton;
    ButtonSmallest: TButton;
    ButtonSmallestDouble: TButton;
    ButtonSpecials: TButton;
    CheckBoxCallExVer: TCheckBox;
    CheckBoxShowDebug: TCheckBox;
    EditFloatValue: TEdit;
    MemoLog: TMemo;
    procedure ButtonAnalyzeFloatClick(Sender: TObject);
    procedure ButtonConvertClick(Sender: TObject);
    procedure ButtonDenormal2Click(Sender: TObject);
    procedure ButtonPiClick(Sender: TObject);
    procedure ButtonSmallestClick(Sender: TObject);
    procedure ButtonSmallestDoubleClick(Sender: TObject);
    procedure ButtonSpecialsClick(Sender: TObject);
    procedure EditFloatValueKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
  private
    procedure TestNumber(Value: Extended);
  public
    procedure Log(const AMsg: string; const AIndent: Integer = 0);
    procedure LogFmt(const AFormat: string; const AData: array of const; const AIndent: Integer = 0);
  end;

var
  EFTSDMainForm: TFTSDMainForm;

implementation

{$R *.dfm}

uses
  Winapi.Messages, Winapi.Windows, System.SysUtils, Delphi.ExactFloatToString;

function GetCpuClockCycleCount: Int64;
asm
  dw $310F  // opcode for RDTSC
end;

procedure TFTSDMainForm.Log(const AMsg: string; const AIndent: Integer = 0);
begin
  MemoLog.Lines.Add(StringOfChar(' ', AIndent * 2) + AMsg);
end;

procedure TFTSDMainForm.LogFmt(const AFormat: string; const AData: array of const; const AIndent: Integer = 0);
begin
  Log(Format(AFormat, AData), AIndent);
end;

procedure TFTSDMainForm.FormCreate(Sender: TObject);
begin
  EditFloatValue.Text := FloatToStr(1.01);
end;

procedure TFTSDMainForm.TestNumber(Value: Extended);
var
  ExtX: TExtendedFloat absolute Value;
  cc: Int64;
  ValE4K: Extended;
  s: string;
begin
  if CheckBoxShowDebug.Checked then
    Delphi.ExactFloatToString.LogFmtX := LogFmt
  else
    Delphi.ExactFloatToString.LogFmtX := nil;

  if Abs(Value) < 1E-4000 then
  begin
    ValE4K := Value * 1E4000;
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g, Ge4K=%g', [ExtX.Exponent, ExtX.Mantissa, Value, ValE4K]);
  end
  else
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g', [ExtX.Exponent, ExtX.Mantissa, Value]);

  try
    cc := GetCpuClockCycleCount;

    if CheckBoxCallExVer.Checked then
      s := ExactFloatToStrEx(Value)
    else
      s := ExactFloatToStr(Value);

    cc := GetCpuClockCycleCount - cc;
    LogFmt('Required %s clock cycles',[ExactFloatToStr(cc)], 1);
    Log(s);
  except
    on e:Exception do
      LogFmt('Exception: %s',[e.Message]);
  end;
end;

procedure StrToFloatProc(const AStr: string; var AValue: Extended);
var
  s: string;
  i,j: integer;
begin
  s := AStr;
  j := 0;

  for i := 1 to length(s) do
  begin
    if CharInSet(s[i], ['-','0'..'9','.','e','E']) then
    begin
      Inc(j);
      s[j] := s[i]
    end;
  end;

  SetLength(s,j);
  AValue := StrToFloat(s);
end;

procedure TFTSDMainForm.ButtonConvertClick(Sender: TObject);
var
  ext: Extended;
begin
  Screen.Cursor := crHourGlass;
  Log('');

  try
    StrToFloatProc(EditFloatValue.Text, ext);
    TestNumber(ext);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.EditFloatValueKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> ^M then
    Exit;

  Key := #0;
  ButtonConvertClick(Sender);
end;

procedure TFTSDMainForm.ButtonSmallestClick(Sender: TObject);
var
  ext: extended;
  LIndex: integer;
  ExtX: TExtendedFloat absolute ext;
begin
  Log('');

  Screen.Cursor := crHourGlass;
  try
    ExtX.Exponent := 0;
    ExtX.Mantissa := $0000000000000001;

    //
    LIndex := 1;
    while LIndex <= 2 do
    begin
      TestNumber(ext);

      ext := ext / 2;

      Inc(LIndex);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonDenormal2Click(Sender: TObject);
var
  ext: extended;
  i: integer;
  ExtX: TExtendedFloat absolute ext;
  ext2: extended;
begin
  Log('');
  Screen.Cursor := crHourGlass;
  try
    ExtX.Exponent := 2;
    ExtX.Mantissa := $8000000000000000;

    for i := 1 to 9 do
    begin
      ext2 := ext*1e4900;
      LogFmt('Test #%d: Exp=$%4.4x, Man=$%16.16x, G=%g, G2=%g', [i, ExtX.Exponent, ExtX.Mantissa, ext, ext2]);

      if (i in [2,3,4]) then
        TestNumber(ext);

      if i < 5 then
        ext := ext / 2
      else
        ext := ext * 2;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonSpecialsClick(Sender: TObject);
const
  NanX = 0/0;
  DblSgnX: Int64 = $8000000000000000; {1 bit}
  DblExpX: Int64 = $7FF0000000000000; {11 bits}
  DblManX: Int64 = $000FFFFFFFFFFFFF; {52 bits (+ 1 = 53)}
var
  Ext: extended;
  Dbl: double;
  ExtX: TExtendedFloat absolute ext;
  DblX: int64 absolute dbl;
begin
  Screen.Cursor := crHourGlass;
  try
    { Test infinities: }
    Log('');
    ExtX.Exponent := $7FFF;
    ExtX.Mantissa := $0000000000000000;
    Log('+Inf response = ' + ExactFloatToStr(ext));
    ExtX.Exponent := $FFFF;
    ExtX.Mantissa := $0000000000000000;
    Log('-Inf response = ' + ExactFloatToStr(ext));

    { Test indefinite: }
    Log('');
    ext := NanX;
    LogFmt('Exp=$%4.4x, Man=$%16.16x',[ExtX.Exponent, ExtX.Mantissa]);
    Log('Indefinite response = ' + ExactFloatToStr(ext));
    dbl := ext;
    ext := dbl;
    LogFmt('Dbl: Exp=$%3.3x, Man=$%13.13x', [(DblX shr (13 * 4)), (DblX and DblManX)]);
    LogFmt('Ext: Exp=$%4.4x, Man=$%16.16x',[ExtX.Exponent, ExtX.Mantissa]);
    Log('Indefinite dbl rsp. = ' + ExactFloatToStr(ext));

    { Test QNANs: }
    Log('');
    ExtX.Exponent := $7FFF;
    ExtX.Mantissa := Int64($C100000000000000);
    Log('QNAN(1) response = ' + ExactFloatToStr(ext));
    ExtX.Exponent := $7FFF;
    ExtX.Mantissa := Int64($8100000000000000);
    Log('SNAN(1) response = ' + ExactFloatToStr(ext));
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonSmallestDoubleClick(Sender: TObject);
var
  d1, d2: double;
begin
  Log('');

  d1 := 1;

  repeat
    d2 := d1;
    d1 := d1 / 2;
  until d1 = 0.00;

  EditFloatValue.Text := FloatToStr(d2);
  TestNumber(d2);
end;

procedure TFTSDMainForm.ButtonPiClick(Sender: TObject);
var
  ext: extended;
  d: double;
  ExtX: TExtendedFloat absolute ext;
begin
  Log('');
  ext := pi;
  EditFloatValue.Text := FloatToStr(ext);
  TestNumber(ext);
  d := pi;
  EditFloatValue.Text := FloatToStr(d);
  TestNumber(d);
end;

procedure TFTSDMainForm.ButtonAnalyzeFloatClick(Sender: TObject);
var
  ext, ext2: Extended;
  dbl: Double;
  sgl: Single;
  i: integer;
  { Equivalence a record to var ext: }
  ExtX: TExtendedFloat absolute ext;
  DblX: Int64 absolute dbl;
  SglX: LongInt absolute sgl;
  s: string;
begin
  Assert(SizeOf(ExtX) = SizeOf(ext));
  Assert(SizeOf(DblX) = SizeOf(dbl));
  Assert(SizeOf(SglX) = SizeOf(sgl));

  for i := 0 to 20 do
  begin
    case i of
      0:
        begin
          Log('');
          Log('Check simple numbers.');
          ext := 15;
        end;
      3:
        begin
          Log('');
          Log('Check crossover into sgl denormal.');
          { Set ext = 2 * <single normal minimum>: }
          SglX := LongInt(2) shl 23;
          ext := sgl;
        end;
      7: begin
          Log('');
          Log('Check crossover into dbl denormal.');
          { Set ext = 2 * <double normal minimum>: }
          DblX := Int64(2) shl 52;
          s := ParseFloat(dbl);
          ext := dbl;
        end;
      11:
        begin
          Log('');
          Log('Check crossover into ext denormal.');
          { Set ext = 2 * <extended normal minimum>: }
          ExtX.Exponent := 2;
          ExtX.Mantissa := $8000000000000000;
        end;
      15:
        begin
          Log('');
          Log('Check cross over into zero.');
          { Set ext = 2 * <external denormal minimum>: }
          ExtX.Exponent := 0;
          ExtX.Mantissa := $0000000000000002;
        end;
        { Divide the number to be analyzed by 2: }
      else
        ext := ext / 2;
        Log('vide by 2 and check', 1);
    end;

    dbl := ext;
    sgl := ext;

    { Set ext2 to same ext value times 10^4900: }
    ext2 := ext * 1e4900;

    { log analysis }
    Log(Format('%2.2d: Nbr=%g ((Nbr x 1e4900)=%g)',[i, ext, ext2]), 1);
    Log(ParseFloat(ext) + ' ' + ParseFloat(dbl) + ' ' + ParseFloat(sgl), 1);
  end;
end;

end.
