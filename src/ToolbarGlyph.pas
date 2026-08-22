{ ************************************************************************** }
{                                                                            }
{ ToolbarGlyph                                                               }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit ToolbarGlyph;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}Windows{$ELSE}Winapi.Windows{$ENDIF};

type
  TToolbarGlyph = record
    Bmp: HBITMAP;
    Light: HICON;
    Dark: HICON;
    Painted: Integer;
  end;

function GlyphSide: Integer;

function BuildToolbarGlyph(const Side: Integer): TToolbarGlyph;

implementation

const
  Supersample = 4;
  Field = 16;
  Stroke = 1.1;

type
  TQuad = packed record
    B, G, R, A: Byte;
  end;
  PQuad = ^TQuad;

  TByteArray = array of Byte;

function CreateSheet(const Side: Integer; out Bits: PQuad; out DC: HDC; out Old: HGDIOBJ): HBITMAP;
var
  Info: TBitmapInfo;
  Screen: HDC;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  Info.bmiHeader.biWidth := Side;
  Info.bmiHeader.biHeight := -Side;
  Info.bmiHeader.biPlanes := 1;
  Info.bmiHeader.biBitCount := 32;
  Info.bmiHeader.biCompression := BI_RGB;
  DC := 0;
  Old := 0;
  Screen := GetDC(0);
  try
    Result := CreateDIBSection(Screen, Info, DIB_RGB_COLORS, Pointer(Bits), 0, 0);
  finally
    ReleaseDC(0, Screen);
  end;
  if Result = 0 then Exit;
  DC := CreateCompatibleDC(0);
  Old := SelectObject(DC, Result);
end;

function RoundPen(const Width: Integer): HPEN;
var
  Brush: TLogBrush;
  Thick: Integer;
begin
  FillChar(Brush, SizeOf(Brush), 0);
  Brush.lbStyle := BS_SOLID;
  Brush.lbColor := $000000;
  Thick := Width;
  if Thick < 1 then Thick := 1;
  Result := ExtCreatePen(PS_GEOMETRIC or PS_SOLID or PS_ENDCAP_ROUND or
    PS_JOIN_ROUND, Thick, Brush, 0, nil);
end;

procedure DrawGlyph(const DC: HDC; const Scale: Double);

  function P(const X, Y: Double): TPoint;
  begin
    Result.X := Round(X * Scale);
    Result.Y := Round(Y * Scale);
  end;

var
  Pen, OldPen, OldBrush: HGDIOBJ;
  Shape: array[0..3] of TPoint;
begin
  Pen := RoundPen(Round(Stroke * Scale));
  OldPen := SelectObject(DC, Pen);
  OldBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));
  try
    Shape[0] := P(3.33, 2);
    Shape[1] := P(3.33, 12.67);
    Shape[2] := P(14, 12.67);
    Polyline(DC, Shape[0], 3);
    Shape[0] := P(2, 3.33);
    Shape[1] := P(3.33, 2);
    Shape[2] := P(4.67, 3.33);
    Polyline(DC, Shape[0], 3);
    Shape[0] := P(12.67, 11.33);
    Shape[1] := P(14, 12.67);
    Shape[2] := P(12.67, 14);
    Polyline(DC, Shape[0], 3);
    Shape[0] := P(4.67, 11.33);
    Shape[1] := P(6, 5.33);
    Shape[2] := P(10, 5.33);
    Shape[3] := P(11.33, 10);
    PolyBezier(DC, Shape[0], 4);
  finally
    SelectObject(DC, OldBrush);
    SelectObject(DC, OldPen);
    DeleteObject(Pen);
  end;
end;

function Coverage(const Side: Integer): TByteArray;
var
  Big: HBITMAP;
  Bits, Row: PQuad;
  DC: HDC;
  Old: HGDIOBJ;
  Wide, X, Y, I, J, Sum: Integer;
begin
  Result := nil;
  Wide := Side * Supersample;
  Big := CreateSheet(Wide, Bits, DC, Old);
  if Big = 0 then Exit;
  try
    Row := Bits;
    for I := 0 to Wide * Wide - 1 do
    begin
      Row.B := 255;
      Row.G := 255;
      Row.R := 255;
      Row.A := 255;
      Inc(Row);
    end;
    DrawGlyph(DC, Supersample);
    GdiFlush;
    SetLength(Result, Side * Side);
    for Y := 0 to Side - 1 do
      for X := 0 to Side - 1 do
      begin
        Sum := 0;
        for J := 0 to Supersample - 1 do
        begin
          Row := Bits;
          Inc(Row, (Y * Supersample + J) * Wide + X * Supersample);
          for I := 0 to Supersample - 1 do
          begin
            Inc(Sum, 255 - Row.B);
            Inc(Row);
          end;
        end;
        Result[Y * Side + X] := Sum div (Supersample * Supersample);
      end;
  finally
    SelectObject(DC, Old);
    DeleteDC(DC);
    DeleteObject(Big);
  end;
end;

function MakeIcon(const Cover: TByteArray; const Side: Integer; const Color: COLORREF): HICON;
var
  Sheet, Mask: HBITMAP;
  Bits: PQuad;
  DC: HDC;
  Old: HGDIOBJ;
  Empty: TByteArray;
  Info: TIconInfo;
  I: Integer;
  A: Byte;
begin
  Result := 0;
  Sheet := CreateSheet(Side, Bits, DC, Old);
  if Sheet = 0 then Exit;
  SelectObject(DC, Old);
  DeleteDC(DC);
  try
    for I := 0 to Side * Side - 1 do
    begin
      A := Cover[I];
      Bits.B := (GetBValue(Color) * A) div 255;
      Bits.G := (GetGValue(Color) * A) div 255;
      Bits.R := (GetRValue(Color) * A) div 255;
      Bits.A := A;
      Inc(Bits);
    end;
    SetLength(Empty, ((Side + 15) div 16) * 2 * Side);
    for I := 0 to Length(Empty) - 1 do
      Empty[I] := 0;
    Mask := CreateBitmap(Side, Side, 1, 1, @Empty[0]);
    if Mask = 0 then Exit;
    try
      FillChar(Info, SizeOf(Info), 0);
      Info.fIcon := True;
      Info.hbmMask := Mask;
      Info.hbmColor := Sheet;
      Result := CreateIconIndirect(Info);
    finally
      DeleteObject(Mask);
    end;
  finally
    DeleteObject(Sheet);
  end;
end;

function MakeBitmap(const Cover: TByteArray; const Side: Integer; const Color: COLORREF): HBITMAP;
var
  Bits: PQuad;
  DC: HDC;
  Old: HGDIOBJ;
  I: Integer;
  A: Byte;
  Face: COLORREF;

  function Mix(const Ink, Back: Byte): Byte;
  begin
    Result := (Ink * A + Back * (255 - A)) div 255;
  end;

begin
  Result := CreateSheet(Side, Bits, DC, Old);
  if Result = 0 then Exit;
  SelectObject(DC, Old);
  DeleteDC(DC);
  Face := GetSysColor(COLOR_BTNFACE);
  for I := 0 to Side * Side - 1 do
  begin
    A := Cover[I];
    Bits.B := Mix(GetBValue(Color), GetBValue(Face));
    Bits.G := Mix(GetGValue(Color), GetGValue(Face));
    Bits.R := Mix(GetRValue(Color), GetRValue(Face));
    Bits.A := 255;
    Inc(Bits);
  end;
end;

function GlyphSide: Integer;
var
  Screen: HDC;
  Dpi: Integer;
begin
  Screen := GetDC(0);
  try
    Dpi := GetDeviceCaps(Screen, LOGPIXELSX);
  finally
    ReleaseDC(0, Screen);
  end;
  if Dpi <= 0 then Dpi := 96;
  Result := MulDiv(Field, Dpi, 96);
  if Result < Field then Result := Field;
end;

function BuildToolbarGlyph(const Side: Integer): TToolbarGlyph;
var
  Cover: TByteArray;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Side < 4 then Exit;
  Cover := Coverage(Side);
  if Cover = nil then Exit;
  for I := 0 to Length(Cover) - 1 do
    if Cover[I] > 0 then Inc(Result.Painted);
  Result.Bmp := MakeBitmap(Cover, Side, RGB($33, $33, $33));
  Result.Light := MakeIcon(Cover, Side, RGB($33, $33, $33));
  Result.Dark := MakeIcon(Cover, Side, RGB($DC, $DC, $DC));
end;

end.
