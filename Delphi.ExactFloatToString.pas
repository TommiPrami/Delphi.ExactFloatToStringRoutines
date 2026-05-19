unit Delphi.ExactFloatToString;

(* *****************************************************************************

  This module includes
    (a) functions for converting a floating binary point number to its
        *exact* decimal representation in an AnsiString;
    (b) functions for parsing the floating point types into sign, exponent,
        and mantissa; and
    (c) function for analyzing a extended float number into its type (zero,
        normal, infinity, etc.)

  Its intended use is for trouble shooting problems with floating point numbers.

  This code uses dynamic arrays, overloaded calls, and optional parameters.

  These routines are not very optimized for speed or space.
    I plan to replace the individual bit-shifts and multiplies-by-ten with multiple versions of same.
    Consider making an object so that the arrays don't have to reallocated so often.
    And consider making an output buffer character array so that the Result will be allocated only once.

  Rev. 6/21/2018  Updated to Unicode strings and code cleanup
  Rev. 1/1/2003   by JFH to add the three ParseFloat functions.
  Rev. 12/26/2002 by JFH to bracket the DEBUG code with conditionals.
  Rev. 12/25/2002 by JFH to fix 1E20 (BinExp) problem and check for zero and other special values.
  Pgm. 12/24/2002 by John Herbster for Delphi programmers everywhere.

***************************************************************************** *)

{ Turn DEBUG on to make available detail debugging at expense of speed.}
{.$DEFINE DEBUG}

interface

uses
  System.SysUtils;

type
  TSglWord = Word;     //Consider Byte or Word
  TDblWord = LongWord; //Consider Word or LongWord

  TExtendedFloat = packed record
    Mantissa: Int64;
    Exponent: Word;  //Sign and Exponent
  end;

  TFloatParts = packed record
    case Byte of
      0: (W: TDblWord);
      1: (L, H: TSglWord);
    end;

  { This call uses the global DecimalSeparator and ThousandSeparator. It can be slow for very large or very small
    extended numbers.) }
  function ExactFloatToStr(const AValue: Extended): string; overload; inline;
  function ExactFloatToStr(const AValue: Extended; const AFormatSettings: TFormatSettings): string; overload;
  function ExactFloatToStrEx(const AValue: Extended; const ADecimalPoint: string = '.'; const AThousandsSep: string = '';
    const ADigitGroups: Integer = 0): string;


  // These calls parse a float value to its sign, exponent, and mantissa.
  function ParseFloat(const AValue: Extended): string; overload;
  function ParseFloat(const AValue: Double): string; overload;
  function ParseFloat(const AValue: Single): string; overload;

  // This is the basic conversion engine.
  function FloatingBinPointToDecStr(const AValue; const AValNbrBits, AValBinExp: Integer; const ANegative: Boolean;
    const ADecimalPoint: string = '.'; const AThousandsSep: string = ''; const ADigitGroups: Integer = 0): string;

type
  TTypeFloat = (tfUnknown, tfNormal, tfZero, tfDenormal, tfIndefinite, tfInfinity, tfQuietNan, tfSignalingNan);

  procedure AnalyzeFloat(const AValue: Extended; var ANumberType: TTypeFloat; var ANegative: Boolean; var AExponent: Word;
    var AMantissa: Int64);

(*
const
  TODO: Make this configurable

  // Different spaces you can use for digit grouping. SI recommends ThinSpace
  ThinSpace: WideChar          = #$2009; // U+2009 THIN SPACE
  NarrowNoBreakSpace: WideChar = #$202F; // U+202F NARROW NO-BREAK SPACE
  FigureSpace: WideChar        = #$2007; // U+2007 FIGURE SPACE
*)

var
  LogFmtX: procedure(const AFormat: string; const AData: array of const; const AIndent: Integer = 0) of object;

implementation

uses
  Winapi.Windows;

const
//  SizeOfAryElem = SizeOf(TSglWord);
  BitsInBufElem = SizeOf(TSglWord) * 8; // SizeOfAryElem*8;

var
  SPositiveSign: string =              '+';          // LOCALE_SPOSITIVESIGN, at most 4 characters
  SNegativeSign: string =              '-';          // LOCALE_SNEGATIVESIGN, at most 4 characters
  SPosInfinity:  string =              'Infinity';   // LOCALE_SPOSINFINITY
  SNegInfinity:  string =              '-Infinity';  // LOCALE_SNEGINFINITY
  SNativeDigits: array[0..9] of Char = '0123456789'; // LOCALE_SNATIVEDIGITS
  INegNumber:    Integer =             1;            // LOCALE_INEGNUMBER 0 = "(1.1), 1 = "-1.1", 2 = "- 1.1", 3 = "1.1-", 4 = "1.1 -"
  SGrouping:     string =              '3;0';        // LOCALE_SGROUPING
  SIGN_ARRAY: array[Boolean] of Char = '+-';

{$IFDEF DEBUG}
procedure LogFmt(const AFormat: string; const AData: array of const; const AIndent: Integer = 0);
begin
  if Assigned(LogFmtX) then
    LogFmtX(AFormat, AData, AIndent);
end;
{$ENDIF}

procedure MultiplyAndAdd(const AMultiplican, AMultiplier, ACarryIn: TSglWord; var ACarryOut, AProduct: TSglWord);
var
  LTmp: TFloatParts;
begin
  LTmp.W := AMultiplican * AMultiplier + ACarryIn;

  ACarryOut := LTmp.H;
  AProduct := LTmp.L;
end;

function DivideAndRemainder(const ANumeratorHi, ANumeratorLo: TSglWord; const ADivisor: TSglWord; var AQuotient, ARemainder: TSglWord): Boolean;
var
  LTmp1: TFloatParts;
  LTmp2: TFloatParts;
begin
  Result := ADivisor <> 0;

  if Result then
  begin
    LTmp1.H := ANumeratorHi;
    LTmp1.L := ANumeratorLo;
    LTmp2.W := LTmp1.W div ADivisor;

    if LTmp2.H <> 0 then
      Result := False
    else
    begin
      AQuotient := LTmp2.L;
      ARemainder := LTmp1.W mod ADivisor;
    end;
  end;
end;

function AddSign(const AStringValue: string; const AIsNegative: Boolean): string;
begin
  {
    LOCALE_INEGNUMBER
      0 = "(1.1)
      1 = "-1.1"
      2 = "- 1.1"
      3 = "1.1-"
      4 = "1.1 -"
  }
  if AIsNegative then
  begin
    case INegNumber of
      0: Result := '(' + AStringValue + ')';           // "(1.1)"
      1: Result := SNegativeSign + AStringValue;       // "-1.1"
      2: Result := SNegativeSign + ' ' + AStringValue; // "- 1.1"
      3: Result := AStringValue + SNegativeSign;       // "1.1-"
      4: Result := AStringValue + ' ' + SNegativeSign; // "1.1 -"
      else
        Result := SNegativeSign + AStringValue;
    end
  end
  else
  begin
    case INegNumber of
      0: Result := AStringValue;                       // "(1.1)"
      1: Result := SPositiveSign + AStringValue;       // "-1.1"
      2: Result := SPositiveSign + ' ' + AStringValue; // "- 1.1"
      3: Result := AStringValue + SPositiveSign;       // "1.1-"
      4: Result := AStringValue + ' ' + SPositiveSign; // "1.1 -"
      else
        Result := SPositiveSign + AStringValue;
    end;
  end;
end;

function FloatingBinPointToDecStr(const AValue; const AValNbrBits, AValBinExp: Integer; const ANegative: Boolean;
    const ADecimalPoint: string = '.'; const AThousandsSep: string = ''; const ADigitGroups: Integer = 0): string;

{$IFDEF DEBUG}
  procedure LogManExp(const ARem: string; const AMan: array of TSglWord; const ABinExp, ADecExp, ANbrManElem: Integer);
  var
    LStringValue: string;
    LIndex: Integer;
  begin
    LogFmt('%s: BinExp=%d, DecExp=%d, NbrManElem=%d', [ARem, ABinExp, ADecExp, ANbrManElem]);
    LStringValue := '';

    for LIndex := 0 to ANbrManElem - 1 do
      LStringValue := Format(' %2.2x', [AMan[LIndex]]) + LStringValue;

    LogFmt('%s', [LStringValue], 1);
  end;
{$ENDIF}

var
  LMantissaArray: array of TSglWord;
  LCryE: TSglWord;
  LCry: TDblWord;
  LMantissaCount: Integer;
  LBinExp: Integer; // neg of # binary fraction bits
  LDecExp: Integer; // neg of # decimal fraction bits
  LDeximalCount: Integer;
  LIndex: Integer;
  LMantissaIndex: Integer;
  LTmpInt: Integer;
  LChar: Char;
  LTempFloatParts: TFloatParts;
begin
  {
    Value = Mantissa * 2^BinExp * 10^DecExp
  }

  { Load Mantissa and binary exponent: }
  LMantissaCount := (AValNbrBits + BitsInBufElem - 1) div BitsInBufElem;
  SetLength(LMantissaArray, LMantissaCount);
  Move(AValue, LMantissaArray[0], (AValNbrBits + 7) div 8); {Assuming little endian input}

  { Set exponents: (Value = Mantissa * 2^BinExp * 10^DecExp) }
  LBinExp := AValBinExp;
  LDecExp := 0;

  { Reduce mantissa to minimum number of bits (i.e. while mantissa is odd, div by 2 and inc binary exponent): }
{$IFDEF DEBUG}
  LogManExp('Before trimming', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

  while (LMantissaCount > 0) and (LBinExp < 0) and not Odd(LMantissaArray[0]) do
  begin
    LCry := 0;

    for LIndex := LMantissaCount - 1 downto 0 do
    begin
      LTmpInt := (LCry shl BitsInBufElem) or LMantissaArray[LIndex];
      LMantissaArray[LIndex] := (LTmpInt shr 1);
      LCry := LTmpInt and 1;
    end;

    Inc(LBinExp);

{$IFDEF DEBUG}
    LogManExp('Shifting down', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

    if LMantissaArray[LMantissaCount - 1] = 0 then
      Dec(LMantissaCount);
  end;

  { Check for zero: }
  if LMantissaCount = 0 then
  begin
    Result := AddSign(Result, ANegative);
    Exit;
  end;

   {
      Repeatably multiply by 10 until there is no more fraction. Decrement the DecExp at the same time.
      Note that a multiply by 10 is same as mul. by 5 and inc of BinExp exponent.
      Also note that a multiply by 5 adds two or three bits to number of mantissa bits.
   }
  LDeximalCount := -LBinExp; {Observe! 0.5, 0.25, 0.125, 0.0625, 0.03125, ...}
  LIndex := LMantissaCount + (3 * LDeximalCount + BitsInBufElem - 1) div BitsInBufElem;

  if Length(LMantissaArray) < LIndex then
    SetLength(LMantissaArray, LIndex);

{$IFDEF DEBUG}
  LogManExp('Prep mul out', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

  LIndex := 1;
  while LIndex <= LDeximalCount do
  begin
    LCryE := 0;

    for LMantissaIndex := 0 to LMantissaCount - 1 do
      MultiplyAndAdd(LMantissaArray[LMantissaIndex], 5, LCryE, LCryE, LMantissaArray[LMantissaIndex]);

    if LCryE <> 0 then
    begin
      Inc(LMantissaCount);
      LMantissaArray[LMantissaCount - 1] := LCryE;
    end;

    Inc(LBinExp);
    Dec(LDecExp);

{$IFDEF DEBUG}
    LogManExp('Mul out', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

    Inc(LIndex);
  end;

{$IFDEF DEBUG}
  LogManExp('Finished multiplies', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

  { Finish reducing BinExp to 0 by shifting mantissa up: }
  while LBinExp > 0 do
  begin
    LCry := 0;

    for LIndex := 0 to LMantissaCount - 1 do
    begin
      LTempFloatParts.W := LMantissaArray[LIndex] shl 1;
      LMantissaArray[LIndex] := LTempFloatParts.L + LCry;
      LCry := LTempFloatParts.H;
    end;

    Dec(LBinExp);

    if LCry <> 0 then
    begin
      Inc(LMantissaCount);

      if Length(LMantissaArray) < LMantissaCount then
        SetLength(LMantissaArray, LMantissaCount);

      LMantissaArray[LMantissaCount - 1] := LCry;
    end;

{$IFDEF DEBUG}
    LogManExp('Shifting up', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}
  end;

   { Repeatably divide by 10 and use remainders to create decimal AnsiString: }
  Result := ''; {DEBUG}

{$IFDEF DEBUG}
  LogManExp('Before division', LMantissaArray, LBinExp, LDecExp, LMantissaCount);
{$ENDIF}

  repeat
    { If not first then place separators: }
    if Result <> '' then
    begin
      if LDecExp = 0 then
        Result := ADecimalPoint + Result
      else if (ADigitGroups = 5) and ((LDecExp mod 5) = 0) then
        Result := AThousandsSep + Result
      else if (ADigitGroups = 3) and ((LDecExp mod 3) = 0) then
        Result := AThousandsSep + Result;
    end;

    { DivideAndRemainder mantissa array by 10: }
    LCryE := 0;

    for LIndex := LMantissaCount - 1 downto 0 do
      DivideAndRemainder(LCryE, LMantissaArray[LIndex], 10, LMantissaArray[LIndex], LCryE); // DivideAndRemainder(NumeratorHi, NumeratorLo: Byte;  Divisor: Byte; var Quotient, Remainder: Byte): boolean;

    Inc(LDecExp);
    LChar := SNativeDigits[LCryE];
    Result := LChar + Result;

    if (LMantissaCount > 0) and (LMantissaArray[LMantissaCount - 1] = 0) then
      Dec(LMantissaCount);
  until (LDecExp > 0) and (LMantissaCount = 0);

  Result := AddSign(Result, ANegative);
end;

procedure AnalyzeFloat(const AValue: Extended; var ANumberType: TTypeFloat; var ANegative: Boolean; var AExponent: Word;
  var AMantissa: Int64);
var
  LValueRec: TExtendedFloat absolute AValue;
begin
  AMantissa := LValueRec.Mantissa;
  ANegative := (LValueRec.Exponent and $8000) <> 0;
  AExponent := (LValueRec.Exponent and $7FFF);

  if AExponent = $7FFF then
  begin
    if (AMantissa = 0) then
      ANumberType := tfInfinity
    else
    begin
      AMantissa := (AMantissa and $3FFFFFFFFFFFFFFF);

      if ((LValueRec.Mantissa and $4000000000000000) = 0) then
        ANumberType := tfSignalingNan
      else if (AMantissa = 0) then
        ANumberType := tfIndefinite
      else
        ANumberType := tfQuietNan
    end
  end
  else if (AExponent = 0) then
  begin
    if (AMantissa = 0) then
      ANumberType := tfZero
    else
      ANumberType := tfDenormal
  end
  else
    ANumberType := tfNormal;
end;

function ExactFloatToStrEx(const AValue: Extended; const ADecimalPoint: string = '.'; const AThousandsSep: string = '';
  const ADigitGroups: Integer = 0): string;

  function IsSpace(const AStringValue: string): Boolean;
  begin
    Result := False;

    if Length(AStringValue) <> 1 then
      Exit;

    case Word(AStringValue[1]) of
      $00A0, $1680, $2000, $2001, $2002, $2003, $2004, $2005,
      $2006, $2007, $2008, $2009, $200A, $202F, $205F, $3000: Result := True;
    end;
  end;

var
  LNumberType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
  LThousandsSeparator: string;
  L0DigitGroups: Integer;
const
  BIAS = $3FFF;
begin
{
  ThousandsSep:
      ' ': group digits in groups of 5
      '', #0: no digit grouping
}
  AnalyzeFloat(AValue, LNumberType, LNegative, LExponent, LMantissa);

  //Convert legacy #0 char to an actual empty string.
  if AThousandsSep = #0 then
    LThousandsSeparator := ''
  else
    LThousandsSeparator := AThousandsSep;

  // If a ThousandsSeparator is present, but the DigitGroups parameter is zero, then auto-guess grouping
  // (Because why else would you specify a separator if you didn't want one)
  if (ADigitGroups = 0) and (LThousandsSeparator <> '') then
  begin
    if IsSpace(LThousandsSeparator) then
      L0DigitGroups := 5
    else
      L0DigitGroups := 3;
  end
  else
    L0DigitGroups := ADigitGroups;

  case LNumberType of
    tfNormal:       Result := FloatingBinPointToDecStr(LMantissa, 64, (LExponent - BIAS) - 63, LNegative, ADecimalPoint,
      LThousandsSeparator, L0DigitGroups);
    tfDenormal:     Result := FloatingBinPointToDecStr(LMantissa, 64, (-BIAS - 62), LNegative, ADecimalPoint,
      LThousandsSeparator, L0DigitGroups);
    tfQuietNan:     Result := Format('QNaN(%d)', [LMantissa]);
    tfSignalingNan: Result := Format('SNaN(%d)', [LMantissa]);
    tfZero:         Result := AddSign('0', LNegative);
    tfIndefinite:   Result := 'Indefinite';
    tfInfinity:
      begin
        if LNegative then
          Result := SPosInfinity
        else
          Result := SNegInfinity;
      end;
    else
      Result := 'UnknownNumberType';
  end;
end;

function ExactFloatToStr(const AValue: Extended): string;
begin
  Result := ExactFloatToStr(AValue, FormatSettings);
end;

function ExactFloatToStr(const AValue: Extended; const AFormatSettings: TFormatSettings): string; overload;
var
  LDigitGroups: Integer;
begin
{
    Handling groups is fairly difficult.

      Specification  Resulting string
      3;0            3,000,000,000,000
      3;2;0          30,00,00,00,00,000
      3              3000000000,000
      3;2            30000000,00,000

    We'll just read the first digit
}
  LDigitGroups := 0;

  if SGrouping <> '' then
  begin
    case SGrouping[1] of
      '0'..'9': LDigitGroups := Ord(SGrouping[1]) - Ord('0');
    end;
  end;

  Result := ExactFloatToStrEx(AValue, AFormatSettings.DecimalSeparator, AFormatSettings.ThousandSeparator, LDigitGroups);
end;

function ParseFloat(const AValue: Extended): string;
var
  LValueRec: TExtendedFloat absolute AValue;
begin
  // This call parses an extended value to its sign, exponent, and mantissa.
  Result := Format('Ext(Sgn="%s",Exp=$%4.4x,Man=$%16.16x)', [SIGN_ARRAY[(LValueRec.Exponent and $8000) <> 0], (LValueRec.Exponent and $7FFF),
    LValueRec.Mantissa]);
end;

function ParseFloat(const AValue: Double): string;
var
  LValueRec: Int64 absolute AValue;
begin
  // This call parses a double value to its sign, exponent, and mantissa.
  Result := Format('Dbl(Sgn="%s",Exp=$%3.3x,Man=$%13.13x)', [SIGN_ARRAY[(LValueRec and $8000000000000000) <> 0],
    ((LValueRec and $7FF0000000000000) shr 52), (LValueRec and $000FFFFFFFFFFFFF)]);
end;

function ParseFloat(const AValue: Single): string;
var
  LValueRec: LongInt absolute AValue;
begin
  { This call parses a single value to its sign, exponent, and mantissa. }
  Result := Format('Sgl(Sgn="%s",Exp=$%2.2x,Man=$%6.6x)', [SIGN_ARRAY[(LValueRec and $80000000) <> 0],
    ((LValueRec and $7F800000) shr 23), (LValueRec and $007FFFFF)]);
end;

procedure InitFormatSettings;
const
  //Windows Vista
  LOCALE_SPOSINFINITY = $0000006a;   // + Infinity, eg "infinity"
  LOCALE_SNEGINFINITY = $0000006b;   // - Infinity, eg "-infinity"
var
  LLocaleID: LCID;
  LStringValue: string;
begin
  LLocaleID := LOCALE_USER_DEFAULT;

{$IFDEF MSWINDOWS}
  {$WARN SYMBOL_PLATFORM OFF}
  SPositiveSign := GetLocaleStr(LLocaleID, LOCALE_SPOSITIVESIGN, '+'); // at most 4 characters
  SNegativeSign := GetLocaleStr(LLocaleID, LOCALE_SNEGATIVESIGN, '-'); // at most 4 characters
  SPosInfinity  := GetLocaleStr(LLocaleID, LOCALE_SPOSINFINITY,  'Infinity');   //
  SNegInfinity  := GetLocaleStr(LLocaleID, LOCALE_SNEGINFINITY,  '-Infinity');  //
  SGrouping     := GetLocaleStr(LLocaleID, LOCALE_SGROUPING,     '3;0');        //

  INegNumber    := StrToIntDef(GetLocaleStr(LLocaleID, LOCALE_INEGNUMBER, '1'), 1);

  LStringValue := GetLocaleStr(LLocaleID, LOCALE_SNATIVEDIGITS, '0123456789');

  if Length(LStringValue) = 10 then
    Move(LStringValue[1], SNativeDigits[0], 10 * SizeOf(Char));
  {$WARN SYMBOL_PLATFORM ON}
{$ENDIF}
end;

initialization
  InitFormatSettings;

end.
