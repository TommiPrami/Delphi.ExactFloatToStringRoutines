unit Tests.Delphi.ExactFloatToString;

interface

uses
  DUnitX.TestFramework,
  Delphi.ExactFloatToString;

type
  [TestFixture]
  TTestAnalyzeFloat = class
  public
    [Test] procedure ClassifiesPositiveZero;
    [Test] procedure ClassifiesNegativeZero;
    [Test] procedure ClassifiesNormalOne;
    [Test] procedure ClassifiesPositiveInfinity;
    [Test] procedure ClassifiesNegativeInfinity;
    [Test] procedure ClassifiesIndefinite;
    [Test] procedure ClassifiesQuietNan;
    [Test] procedure ClassifiesSignalingNan;
    [Test] procedure ClassifiesDenormal;
  end;

  [TestFixture]
  TTestParseFloat = class
  public
    [Test] procedure ExtendedOneFormatsExpectedBits;
    [Test] procedure ExtendedNegativeOneShowsNegativeSign;
    [Test] procedure DoubleOneFormatsExpectedBits;
    [Test] procedure SingleOneFormatsExpectedBits;
  end;

  [TestFixture]
  TTestExactFloatToStrEx = class
  public
    [Test] procedure ZeroEmitsZeroDigit;
    [Test] procedure NegativeZeroEmitsZeroDigitWithNegativeSign;
    [Test] procedure OneEmitsOne;
    [Test] procedure NegativeOneEmitsOneWithNegativeSign;
    [Test] procedure HalfEmitsZeroPointFive;
    [Test] procedure QuarterEmitsZeroPointTwoFive;
    [Test] procedure OneAndAHalfEmitsOnePointFive;
    [Test] procedure FifteenEmitsFifteen;
    [Test] procedure HundredEmitsHundred;
    [Test] procedure OneSixteenthEmitsExactDecimal;
    [Test] procedure DoubleZeroPointOneHasKnownExactDecimal;
    [Test] procedure PositiveInfinityIsNotNegative;
    [Test] procedure NegativeInfinityStartsWithMinus;
    [Test] procedure IndefiniteEmitsIndefiniteKeyword;
    [Test] procedure QuietNanEmitsQNaNWithPayload;
    [Test] procedure SignalingNanEmitsSNaNWithPayload;
    [Test] procedure SmallestExtendedDenormalProducesNonEmptyDigits;
  end;

implementation

uses
  System.SysUtils;

{ Test helpers }

function MakeExtended(const AExponent: Word; const AMantissa: Int64): Extended;
var
  LRecord: TExtendedFloat absolute Result;
begin
  LRecord.Exponent := AExponent;
  LRecord.Mantissa := AMantissa;
end;

function ExtractDigits(const AStringValue: string): string;
var
  LIndex: Integer;
begin
  Result := '';

  for LIndex := 1 to Length(AStringValue) do
    if CharInSet(AStringValue[LIndex], ['0'..'9', '.']) then
      Result := Result + AStringValue[LIndex];
end;

function HasNegativeSign(const AStringValue: string): Boolean;
begin
  Result := (Pos('-', AStringValue) > 0) or (Pos('(', AStringValue) > 0);
end;

{ TTestAnalyzeFloat }

procedure TTestAnalyzeFloat.ClassifiesPositiveZero;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  LValue := MakeExtended($0000, $0000000000000000);
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfZero), Ord(LType));
  Assert.IsFalse(LNegative);
end;

procedure TTestAnalyzeFloat.ClassifiesNegativeZero;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  LValue := MakeExtended($8000, $0000000000000000);
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfZero), Ord(LType));
  Assert.IsTrue(LNegative);
end;

procedure TTestAnalyzeFloat.ClassifiesNormalOne;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  LValue := 1.0;
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfNormal), Ord(LType));
  Assert.IsFalse(LNegative);
  Assert.AreEqual($3FFF, Integer(LExponent));
  Assert.AreEqual(Int64($8000000000000000), LMantissa);
end;

procedure TTestAnalyzeFloat.ClassifiesPositiveInfinity;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  LValue := MakeExtended($7FFF, $0000000000000000);
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfInfinity), Ord(LType));
  Assert.IsFalse(LNegative);
end;

procedure TTestAnalyzeFloat.ClassifiesNegativeInfinity;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  LValue := MakeExtended($FFFF, $0000000000000000);
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfInfinity), Ord(LType));
  Assert.IsTrue(LNegative);
end;

procedure TTestAnalyzeFloat.ClassifiesIndefinite;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  // Indefinite: exponent=$7FFF, top 2 mantissa bits set, payload zero.
  LValue := MakeExtended($FFFF, Int64($C000000000000000));
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfIndefinite), Ord(LType));
end;

procedure TTestAnalyzeFloat.ClassifiesQuietNan;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  // Quiet NaN: exponent=$7FFF, bit 62 set, payload non-zero.
  LValue := MakeExtended($7FFF, Int64($C100000000000000));
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfQuietNan), Ord(LType));
end;

procedure TTestAnalyzeFloat.ClassifiesSignalingNan;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  // Signaling NaN: exponent=$7FFF, bit 62 clear, payload non-zero.
  LValue := MakeExtended($7FFF, Int64($8100000000000000));
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfSignalingNan), Ord(LType));
end;

procedure TTestAnalyzeFloat.ClassifiesDenormal;
var
  LValue: Extended;
  LType: TTypeFloat;
  LNegative: Boolean;
  LExponent: Word;
  LMantissa: Int64;
begin
  // Smallest positive denormal: exponent=0, mantissa=1.
  LValue := MakeExtended($0000, $0000000000000001);
  AnalyzeFloat(LValue, LType, LNegative, LExponent, LMantissa);

  Assert.AreEqual(Ord(tfDenormal), Ord(LType));
  Assert.IsFalse(LNegative);
end;

{ TTestParseFloat }

procedure TTestParseFloat.ExtendedOneFormatsExpectedBits;
var
  LValue: Extended;
begin
  LValue := 1.0;

  Assert.AreEqual('Ext(Sgn="+",Exp=$3fff,Man=$8000000000000000)', ParseFloat(LValue));
end;

procedure TTestParseFloat.ExtendedNegativeOneShowsNegativeSign;
var
  LValue: Extended;
begin
  LValue := -1.0;

  Assert.AreEqual('Ext(Sgn="-",Exp=$3fff,Man=$8000000000000000)', ParseFloat(LValue));
end;

procedure TTestParseFloat.DoubleOneFormatsExpectedBits;
var
  LValue: Double;
begin
  LValue := 1.0;

  Assert.AreEqual('Dbl(Sgn="+",Exp=$3ff,Man=$0000000000000)', ParseFloat(LValue));
end;

procedure TTestParseFloat.SingleOneFormatsExpectedBits;
var
  LValue: Single;
begin
  LValue := 1.0;

  Assert.AreEqual('Sgl(Sgn="+",Exp=$7f,Man=$000000)', ParseFloat(LValue));
end;

{ TTestExactFloatToStrEx }

procedure TTestExactFloatToStrEx.ZeroEmitsZeroDigit;
var
  LResult: string;
begin
  LResult := ExactFloatToStrEx(0.0, '.', '');

  Assert.AreEqual('0', ExtractDigits(LResult));
  Assert.IsFalse(HasNegativeSign(LResult), 'positive zero should not carry a negative sign');
end;

procedure TTestExactFloatToStrEx.NegativeZeroEmitsZeroDigitWithNegativeSign;
var
  LValue: Extended;
  LResult: string;
begin
  LValue := MakeExtended($8000, $0000000000000000);
  LResult := ExactFloatToStrEx(LValue, '.', '');

  Assert.AreEqual('0', ExtractDigits(LResult));
  Assert.IsTrue(HasNegativeSign(LResult), 'negative zero should be marked negative');
end;

procedure TTestExactFloatToStrEx.OneEmitsOne;
begin
  Assert.AreEqual('1', ExtractDigits(ExactFloatToStrEx(1.0, '.', '')));
end;

procedure TTestExactFloatToStrEx.NegativeOneEmitsOneWithNegativeSign;
var
  LResult: string;
begin
  LResult := ExactFloatToStrEx(-1.0, '.', '');

  Assert.AreEqual('1', ExtractDigits(LResult));
  Assert.IsTrue(HasNegativeSign(LResult));
end;

procedure TTestExactFloatToStrEx.HalfEmitsZeroPointFive;
begin
  Assert.AreEqual('0.5', ExtractDigits(ExactFloatToStrEx(0.5, '.', '')));
end;

procedure TTestExactFloatToStrEx.QuarterEmitsZeroPointTwoFive;
begin
  Assert.AreEqual('0.25', ExtractDigits(ExactFloatToStrEx(0.25, '.', '')));
end;

procedure TTestExactFloatToStrEx.OneAndAHalfEmitsOnePointFive;
begin
  Assert.AreEqual('1.5', ExtractDigits(ExactFloatToStrEx(1.5, '.', '')));
end;

procedure TTestExactFloatToStrEx.FifteenEmitsFifteen;
begin
  Assert.AreEqual('15', ExtractDigits(ExactFloatToStrEx(15.0, '.', '')));
end;

procedure TTestExactFloatToStrEx.HundredEmitsHundred;
begin
  Assert.AreEqual('100', ExtractDigits(ExactFloatToStrEx(100.0, '.', '')));
end;

procedure TTestExactFloatToStrEx.OneSixteenthEmitsExactDecimal;
begin
  // 1/16 is exactly 0.0625 in binary, so the exact decimal is finite and short.
  Assert.AreEqual('0.0625', ExtractDigits(ExactFloatToStrEx(1 / 16, '.', '')));
end;

procedure TTestExactFloatToStrEx.DoubleZeroPointOneHasKnownExactDecimal;
const
  EXPECTED = '0.1000000000000000055511151231257827021181583404541015625';
var
  LDouble: Double;
  LExtended: Extended;
begin
  // The Double round of 0.1 has a well-known exact decimal expansion.
  // Promoting to Extended is loss-less, so the engine must produce exactly this string.
  LDouble := 0.1;
  LExtended := LDouble;

  Assert.AreEqual(EXPECTED, ExtractDigits(ExactFloatToStrEx(LExtended, '.', '')));
end;

procedure TTestExactFloatToStrEx.PositiveInfinityIsNotNegative;
var
  LValue: Extended;
  LResult: string;
begin
  // Keyword content comes from LOCALE_SPOSINFINITY (e.g. "Infinity" on en-US, "∞" on fi-FI),
  // so only the sign behavior is portable across machines.
  LValue := MakeExtended($7FFF, $0000000000000000);
  LResult := ExactFloatToStrEx(LValue, '.', '');

  Assert.IsFalse(LResult.IsEmpty, 'infinity output must not be empty');
  Assert.IsFalse(LResult.StartsWith('-'), 'positive infinity must not start with "-"');
end;

procedure TTestExactFloatToStrEx.NegativeInfinityStartsWithMinus;
var
  LValue: Extended;
  LResult: string;
begin
  LValue := MakeExtended($FFFF, $0000000000000000);
  LResult := ExactFloatToStrEx(LValue, '.', '');

  Assert.IsFalse(LResult.IsEmpty, 'infinity output must not be empty');
  Assert.IsTrue(LResult.StartsWith('-'), 'negative infinity must start with "-"');
end;

procedure TTestExactFloatToStrEx.IndefiniteEmitsIndefiniteKeyword;
var
  LValue: Extended;
begin
  LValue := MakeExtended($FFFF, Int64($C000000000000000));

  Assert.AreEqual('Indefinite', ExactFloatToStrEx(LValue, '.', ''));
end;

procedure TTestExactFloatToStrEx.QuietNanEmitsQNaNWithPayload;
var
  LValue: Extended;
  LResult: string;
begin
  LValue := MakeExtended($7FFF, Int64($C100000000000000));
  LResult := ExactFloatToStrEx(LValue, '.', '');

  Assert.StartsWith('QNaN(', LResult);
  Assert.EndsWith(')', LResult);
end;

procedure TTestExactFloatToStrEx.SignalingNanEmitsSNaNWithPayload;
var
  LValue: Extended;
  LResult: string;
begin
  LValue := MakeExtended($7FFF, Int64($8100000000000000));
  LResult := ExactFloatToStrEx(LValue, '.', '');

  Assert.StartsWith('SNaN(', LResult);
  Assert.EndsWith(')', LResult);
end;

procedure TTestExactFloatToStrEx.SmallestExtendedDenormalProducesNonEmptyDigits;
var
  LValue: Extended;
  LResult: string;
  LDigits: string;
begin
  // Mantissa=1, Exponent=0: smallest positive denormal Extended. Value is roughly 3.6e-4951.
  LValue := MakeExtended($0000, $0000000000000001);
  LResult := ExactFloatToStrEx(LValue, '.', '');
  LDigits := ExtractDigits(LResult);

  Assert.IsTrue(LDigits.StartsWith('0.'), 'denormal must start with "0."');
  Assert.IsTrue(LDigits.EndsWith('5'), 'final digit must be 5 (powers of 1/2 end in 5)');
  Assert.IsTrue(Length(LDigits) > 4000, 'denormal expansion should be thousands of digits long');
end;

end.
