unit EFTSDForm.Main;

(* *****************************************************************************

  For Testing ExactFloatToStr and ParseFloat functions.

  Pgm. 12/24/2002 by John Herbster.

**************************************************************************** *)

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TFTSDMainForm = class(TForm)
    EditFloatValue: TEdit;
    ButtonConvert: TButton;
    MemoLog: TMemo;
    CheckBoxShowDebug: TCheckBox;
    CheckBoxCallExVer: TCheckBox;
    ButtonSmallest: TButton;
    ButtonDenormal2: TButton;
    ButtonSpecials: TButton;
    ButtonSmallestDouble: TButton;
    ButtonPi: TButton;
    ButtonAnalyzeFloat: TButton;
    procedure ButtonConvertClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure EditFloatValueKeyPress(Sender: TObject; var Key: Char);
    procedure ButtonSmallestClick(Sender: TObject);
    procedure ButtonDenormal2Click(Sender: TObject);
    procedure ButtonSpecialsClick(Sender: TObject);
    procedure ButtonSmallestDoubleClick(Sender: TObject);
    procedure ButtonPiClick(Sender: TObject);
    procedure CvtToHex_bClick(Sender: TObject);
    procedure ButtonAnalyzeFloatClick(Sender: TObject);
  private
    procedure TestNumber(Value: Extended);
  public
    procedure Log(const msg: string);
    procedure LogFmt(const Fmt: string; const Data: array of const);
  end;

var
  EFTSDMainForm: TFTSDMainForm;

implementation

{$R *.dfm}

uses
  Delphi.ExactFloatToString;

function GetCpuClockCycleCount: Int64;
asm
  dw $310F  // opcode for RDTSC
end;

procedure TFTSDMainForm.Log(const msg: string);
begin
  MemoLog.Lines.Add(msg);
end;

procedure TFTSDMainForm.LogFmt(const Fmt: string; const Data: array of const);
begin
  Log(Format(Fmt,Data));
end;

procedure TFTSDMainForm.FormCreate(Sender: TObject);
begin
  // TODO: There was no debug thingy, have to chgeck out ShowDebug_ck.Enabled := Delphi.ExactFloatToString.Debug;
  EditFloatValue.Text := FloatToStr(1);
end;

procedure TFTSDMainForm.TestNumber(Value: Extended);
var
  ExtX: packed record
    Man: Int64;
    Exp: word
  end absolute Value;
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
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g, Ge4K=%g', [ExtX.Exp,ExtX.Man,Value,ValE4K]);
  end
  else
    LogFmt('Calling: Exp=$%4.4x, Man=$%16.16x, G=%g', [ExtX.Exp,ExtX.Man,Value]);

  try
    cc := GetCpuClockCycleCount;

    if CheckBoxCallExVer.Checked then
      s := ExactFloatToStrEx(Value)
    else
      s := ExactFloatToStr(Value);

    cc := GetCpuClockCycleCount - cc;
    LogFmt('  Required %s clock cycles',[ExactFloatToStr(cc)]);
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
  MemoLog.Lines.Add('');

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
  ExtX: packed record
      Man: Int64;
      Exp: word
    end absolute ext;
begin
  MemoLog.Lines.Add('');

  Screen.Cursor := crHourGlass;
  try
    ExtX.Exp := 0; 
    ExtX.Man := $0000000000000001;

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
  ExtX: packed record
      Man: Int64;
      Exp: word
    end absolute ext;
  ext2: extended;
begin
  MemoLog.Lines.Add('');
  Screen.Cursor := crHourGlass;
  try
    ExtX.Exp := 2; 
    ExtX.Man := $8000000000000000;

    for i := 1 to 9 do
    begin
      ext2 := ext*1e4900;
      LogFmt('Test #%d: Exp=$%4.4x, Man=$%16.16x, G=%g, G2=%g', [i, ExtX.Exp, ExtX.Man, ext, ext2]);

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
  ExtX: packed record
    Man: Int64;
    Exp: word
    end absolute ext;
  DblX: int64 absolute dbl;
begin
  Screen.Cursor := crHourGlass;
  try
    { Test infinities: }
    Log('');
    ExtX.Exp := $7FFF; ExtX.Man := $0000000000000000;
    Log('+Inf response = ' + ExactFloatToStr(ext));
    ExtX.Exp := $FFFF; ExtX.Man := $0000000000000000;
    Log('-Inf response = ' + ExactFloatToStr(ext));

    { Test indefinite: }
    Log('');
    ext := NanX;
    LogFmt('Exp=$%4.4x, Man=$%16.16x',[ExtX.Exp,ExtX.Man]);
    Log('Indefinite response = ' + ExactFloatToStr(ext));
    dbl := ext;
    ext := dbl;
    LogFmt('Dbl: Exp=$%3.3x, Man=$%13.13x', [(DblX shr (13*4)),(DblX and DblManX)]);
    LogFmt('Ext: Exp=$%4.4x, Man=$%16.16x',[ExtX.Exp,ExtX.Man]);
    Log('Indefinite dbl rsp. = ' + ExactFloatToStr(ext));

    { Test QNANs: }
    Log('');
    ExtX.Exp := $7FFF;
    ExtX.Man := Int64($C100000000000000);
    Log('QNAN(1) response = ' + ExactFloatToStr(ext));
    ExtX.Exp := $7FFF;
    ExtX.Man := Int64($8100000000000000);
    Log('SNAN(1) response = ' + ExactFloatToStr(ext));
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TFTSDMainForm.ButtonSmallestDoubleClick(Sender: TObject);
var
  d1, d2: double;
begin
  MemoLog.Lines.Add('');

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
  ExtX: packed record
      Man: Int64;
      Exp: word
    end absolute ext;
begin
  MemoLog.Lines.Add('');
  ext := pi;
  EditFloatValue.Text := FloatToStr(ext);
  TestNumber(ext);
  d := pi;
  EditFloatValue.Text := FloatToStr(d);
  TestNumber(d);
end;

procedure TFTSDMainForm.CvtToHex_bClick(Sender: TObject);
var
  ext: extended;
var
  ExtX: packed record Man: Int64; Exp: word end absolute ext;
begin
  // TODO:
end;

procedure TFTSDMainForm.ButtonAnalyzeFloatClick(Sender: TObject);
var
  ext, ext2: Extended;
  dbl: Double;
  sgl: Single;
  i: integer;
  { Equivalence a record to var ext: }
  ExtX: packed record
    Man: Int64;
    Exp: word end absolute ext;
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
        MemoLog.Lines.Add('');
        MemoLog.Lines.Add('Check simple numbers.');
        ext := 15;
      end;
    3:
      begin
        MemoLog.Lines.Add('');
        MemoLog.Lines.Add('Check crossover into sgl denormal.');
        { Set ext = 2 * <single normal minimum>: }
        SglX := LongInt(2) shl 23;
        ext := sgl;
      end;
    7: begin
        MemoLog.Lines.Add('');
        MemoLog.Lines.Add('Check crossover into dbl denormal.');
        { Set ext = 2 * <double normal minimum>: }
        DblX := Int64(2) shl 52;
        s := ParseFloat(dbl);
        ext := dbl;
      end;
    11:
      begin
        MemoLog.Lines.Add('');
        MemoLog.Lines.Add('Check crossover into ext denormal.');
        { Set ext = 2 * <extended normal minimum>: }
        ExtX.Exp := 2;
        ExtX.Man := $8000000000000000;
      end;
    15:
      begin
        MemoLog.Lines.Add('');
        MemoLog.Lines.Add('Check cross over into zero.');
        { Set ext = 2 * <external denormal minimum>: }
        ExtX.Exp := 0;
        ExtX.Man := $0000000000000002;
      end;
      { Divide the number to be analyzed by 2: }
    else
      ext := ext / 2;
      MemoLog.Lines.Add(' divide by 2 and check');
    end;

    dbl := ext;
    sgl := ext;

    { Set ext2 to same ext value times 10^4900: }
    ext2 := ext * 1e4900;

    { Save the analysis to memo box: }
    MemoLog.Lines.Add(Format('  %2.2d: Nbr=%g ((Nbr x 1e4900)=%g)',[i, ext, ext2]));
    MemoLog.Lines.Add('  ' + ParseFloat(ext) + ' ' + ParseFloat(dbl) + ' ' + ParseFloat(sgl));
  end;
end;

end.
