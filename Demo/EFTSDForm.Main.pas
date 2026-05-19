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
    procedure ButtonAnalyzeFloatClick(ASender: TObject);
    procedure ButtonConvertClick(ASender: TObject);
    procedure ButtonDenormal2Click(ASender: TObject);
    procedure ButtonPiClick(ASender: TObject);
    procedure ButtonSmallestClick(ASender: TObject);
    procedure ButtonSmallestDoubleClick(ASender: TObject);
    procedure ButtonSpecialsClick(ASender: TObject);
    procedure EditFloatValueKeyPress(ASender: TObject; var AKey: Char);
    procedure FormCreate(ASender: TObject);
  private
    procedure TestNumber(const AValue: Extended);
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

procedure TFTSDMainForm.FormCreate(ASender: TObject);
begin
  EditFloatValue.Text := FloatToStr(1.01);
end;

procedure TFTSDMainForm.TestNumber(const AValue: Extended);
var
  LExtendedRec: TExtendedFloat absolute AValue;
  cc: Int64;
  ValE4K: Extended;
  s: string;
begin
  if CheckBoxShowDebug.Checked then
    Delphi.ExactFloatToString.LogFmtX := LogFmt
  else
    Delphi.ExactFloatToString.LogFmtX := nil;

  if Abs(AValue) < 1E-4000 then
  begin
    ValE4K := AValue * 1E4000;
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g, Ge4K=%g', [LExtendedRec.Exponent, LExtendedRec.Mantissa, AValue, ValE4K]);
  end
  else
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g', [LExtendedRec.Exponent, LExtendedRec.Mantissa, AValue]);

  try
    cc := GetCpuClockCycleCount;

    if CheckBoxCallExVer.Checked then
      s := ExactFloatToStrEx(AValue)
    else
      s := ExactFloatToStr(AValue);

    cc := GetCpuClockCycleCount - cc;
    LogFmt('Required %s clock cycles', [ExactFloatToStr(cc)], 1);
    Log(s);
  except
    on e:Exception do
      LogFmt('Exception: %s', [e.Message]);
  end;
end;

procedure StrToFloatProc(const AStr: string; var AValue: Extended);
var
  LStrValue: string;
  LSourceIndex: Integer;
  LDestinationIndex: Integer;
begin
  LStrValue := AStr;
  LDestinationIndex := 0;

  for LSourceIndex := 1 to length(LStrValue) do
  begin
    if CharInSet(LStrValue[LSourceIndex], ['-','0'..'9','.','e','E']) then
    begin
      Inc(LDestinationIndex);
      LStrValue[LDestinationIndex] := LStrValue[LSourceIndex]
    end;
  end;

  SetLength(LStrValue, LDestinationIndex);
  AValue := StrToFloat(LStrValue);
end;

procedure TFTSDMainForm.ButtonConvertClick(ASender: TObject);
var
  LExtendedValue: Extended;
begin
  Screen.Cursor := crHourGlass;
  Log('');

  try
    StrToFloatProc(EditFloatValue.Text, LExtendedValue);
    TestNumber(LExtendedValue);
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.EditFloatValueKeyPress(ASender: TObject; var AKey: Char);
begin
  if AKey <> ^M then
    Exit;

  AKey := #0;
  ButtonConvertClick(ASender);
end;

procedure TFTSDMainForm.ButtonSmallestClick(ASender: TObject);
var
  LExtendedValue: extended;
  LIndex: Integer;
  LExtendedRec: TExtendedFloat absolute LExtendedValue;
begin
  Log('');

  Screen.Cursor := crHourGlass;
  try
    LExtendedRec.Exponent := 0;
    LExtendedRec.Mantissa := $0000000000000001;

    //
    LIndex := 1;
    while LIndex <= 2 do
    begin
      TestNumber(LExtendedValue);

      LExtendedValue := LExtendedValue / 2;

      Inc(LIndex);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonDenormal2Click(ASender: TObject);
var
  LExtendedValue: Extended;
  LIndex: integer;
  LExtendedRec: TExtendedFloat absolute LExtendedValue;
  LExtendedValue2: Extended;
begin
  Log('');
  Screen.Cursor := crHourGlass;
  try
    LExtendedRec.Exponent := 2;
    LExtendedRec.Mantissa := $8000000000000000;

    for LIndex := 1 to 9 do
    begin
      LExtendedValue2 := LExtendedValue * 1e4900;
      LogFmt('Test #%d: Exp=$%4.4x, Man=$%16.16x, G=%g, G2=%g', [LIndex, LExtendedRec.Exponent, LExtendedRec.Mantissa, LExtendedValue, LExtendedValue2]);

      if LIndex in [2, 3, 4] then
        TestNumber(LExtendedValue);

      if LIndex < 5 then
        LExtendedValue := LExtendedValue / 2
      else
        LExtendedValue := LExtendedValue * 2;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonSpecialsClick(ASender: TObject);
const
  NanX = 0 / 0;
  DblSgnX: Int64 = $8000000000000000; {1 bit}
  DblExpX: Int64 = $7FF0000000000000; {11 bits}
  DblManX: Int64 = $000FFFFFFFFFFFFF; {52 bits (+ 1 = 53)}
var
  LExtendedValue: extended;
  LDoubleValue: double;
  LExtendedRec: TExtendedFloat absolute LExtendedValue;
  LDoubleAsInt64: Int64 absolute LDoubleValue;
begin
  Screen.Cursor := crHourGlass;
  try
    { Test infinities: }
    Log('');
    LExtendedRec.Exponent := $7FFF;
    LExtendedRec.Mantissa := $0000000000000000;
    Log('+Inf response = ' + ExactFloatToStr(LExtendedValue));
    LExtendedRec.Exponent := $FFFF;
    LExtendedRec.Mantissa := $0000000000000000;
    Log('-Inf response = ' + ExactFloatToStr(LExtendedValue));

    { Test indefinite: }
    Log('');
    LExtendedValue := NanX;
    LogFmt('Exp=$%4.4x, Man=$%16.16x',[LExtendedRec.Exponent, LExtendedRec.Mantissa]);
    Log('Indefinite response = ' + ExactFloatToStr(LExtendedValue));
    LDoubleValue := LExtendedValue;
    LExtendedValue := LDoubleValue;
    LogFmt('Dbl: Exp=$%3.3x, Man=$%13.13x', [(LDoubleAsInt64 shr (13 * 4)), (LDoubleAsInt64 and DblManX)]);
    LogFmt('Ext: Exp=$%4.4x, Man=$%16.16x',[LExtendedRec.Exponent, LExtendedRec.Mantissa]);
    Log('Indefinite dbl rsp. = ' + ExactFloatToStr(LExtendedValue));

    { Test QNANs: }
    Log('');
    LExtendedRec.Exponent := $7FFF;
    LExtendedRec.Mantissa := Int64($C100000000000000);
    Log('QNAN(1) response = ' + ExactFloatToStr(LExtendedValue));
    LExtendedRec.Exponent := $7FFF;
    LExtendedRec.Mantissa := Int64($8100000000000000);
    Log('SNAN(1) response = ' + ExactFloatToStr(LExtendedValue));
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonSmallestDoubleClick(ASender: TObject);
var
  LDoubleaValue1: Double;
  LDoubleaValue2: Double;
begin
  Log('');

  LDoubleaValue1 := 1.00;

  repeat
    LDoubleaValue2 := LDoubleaValue1;
    LDoubleaValue1 := LDoubleaValue1 / 2;
  until LDoubleaValue1 = 0.00;

  EditFloatValue.Text := FloatToStr(LDoubleaValue2);
  TestNumber(LDoubleaValue2);
end;

procedure TFTSDMainForm.ButtonPiClick(ASender: TObject);
var
  LExtendedValue: Extended;
  LDoubleValue: Double;
begin
  Log('');
  LExtendedValue := Pi;
  EditFloatValue.Text := FloatToStr(LExtendedValue);
  TestNumber(LExtendedValue);

  LDoubleValue := Pi;
  EditFloatValue.Text := FloatToStr(LDoubleValue);
  TestNumber(LDoubleValue);
end;

procedure TFTSDMainForm.ButtonAnalyzeFloatClick(ASender: TObject);
var
  LExtendedValue1: Extended;
  LExtendedValue2: Extended;
  LDoubleValue: Double;
  LSingleValue: Single;
  LIndex: Integer;
  { Equivalence a record to var ext: }
  LExtendedRec: TExtendedFloat absolute LExtendedValue1;
  LDoubleAsInt64: Int64 absolute LDoubleValue;
  LSingleAsLongInt: LongInt absolute LSingleValue;
  s: string;
begin
  Assert(SizeOf(LExtendedRec) = SizeOf(LExtendedValue1));
  Assert(SizeOf(LDoubleAsInt64) = SizeOf(LDoubleValue));
  Assert(SizeOf(LSingleAsLongInt) = SizeOf(LSingleValue));

  for LIndex := 0 to 20 do
  begin
    case LIndex of
      0:
        begin
          Log('');
          Log('Check simple numbers.');
          LExtendedValue1 := 15.00;
        end;
      3:
        begin
          Log('');
          Log('Check crossover into LSingleValue denormal.');

          { Set ext = 2 * <single normal minimum>: }
          LSingleAsLongInt := LongInt(2) shl 23;
          LExtendedValue1 := LSingleValue;
        end;
      7: begin
          Log('');
          Log('Check crossover into LDoubleValue denormal.');

          { Set ext = 2 * <double normal minimum>: }
          LDoubleAsInt64 := Int64(2) shl 52;
          s := ParseFloat(LDoubleValue);
          LExtendedValue1 := LDoubleValue;
        end;
      11:
        begin
          Log('');
          Log('Check crossover into ext denormal.');

          { Set ext = 2 * <extended normal minimum>: }
          LExtendedRec.Exponent := 2;
          LExtendedRec.Mantissa := $8000000000000000;
        end;
      15:
        begin
          Log('');
          Log('Check cross over into zero.');

          { Set ext = 2 * <external denormal minimum>: }
          LExtendedRec.Exponent := 0;
          LExtendedRec.Mantissa := $0000000000000002;
        end;
      else
      begin
        { Divide the number to be analyzed by 2: }
        LExtendedValue1 := LExtendedValue1 / 2;
        Log('Divide by 2 and check', 1);
      end;
    end;

    LDoubleValue := LExtendedValue1;
    LSingleValue := LExtendedValue1;

    { Set ext2 to same ext value times 10^4900: }
    LExtendedValue2 := LExtendedValue1 * 1e4900;

    { log analysis }
    Log(Format('%2.2d: Nbr=%g ((Nbr x 1e4900)=%g)',[LIndex, LExtendedValue1, LExtendedValue2]), 1);
    Log(ParseFloat(LExtendedValue1) + ' ' + ParseFloat(LDoubleValue) + ' ' + ParseFloat(LSingleValue), 1);
  end;
end;

end.
