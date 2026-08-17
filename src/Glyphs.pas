{ ************************************************************************** }
{                                                                            }
{ Glyphs                                                                     }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit Glyphs;

{$B-}

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.Types, System.Math, Winapi.CommCtrl,
  Vcl.Graphics, Vcl.ImgList, CrossGraph.Types, DarkTheme;

const
  GlyphCount = 24;

procedure BuildGlyphs(const Images: TCustomImageList; const Kind: TThemeKind; const Size: Integer);

type
  TGlyphImage = record
    Color: HBITMAP;
    Mask: HBITMAP;
    Painted: Integer;
  end;

function RenderGlyph(const Index: Integer; const Kind: TThemeKind; const Size: Integer;
  const Back: TColor): TGlyphImage;

implementation

const
  Supersample = 4;
  Field = 16;
  Stroke = 1.1;

type
  TQuad = record
    B, G, R, A: Byte;
  end;
  PQuad = ^TQuad;

  TSketch = record
  private
    FDC: HDC;
    FScale: Extended;
    FPen: HPEN;
    FOldPen: HGDIOBJ;
    FOldBrush: HGDIOBJ;
    function Place(const X, Y: Extended): TPoint;
    procedure UsePen(const Width: Extended);
    procedure NoPen;
  public
    procedure Line(const X1, Y1, X2, Y2: Extended);
    procedure Poly(const Points: array of Extended);
    procedure Curve(const Points: array of Extended);
    procedure Frame(const X, Y, W, H, Radius: Extended);
    procedure Circle(const X, Y, Radius: Extended);
    procedure Dot(const X, Y, Radius: Extended);
    procedure Fill(const X, Y, W, H, Radius: Extended);
  end;

  TDraw = reference to procedure(const Sketch: TSketch);

  TLayer = record
    Color: TColor;
    Draw: TDraw;
  end;

function TSketch.Place(const X, Y: Extended): TPoint;
begin
  Result := Point(Round(X * FScale), Round(Y * FScale));
end;

procedure TSketch.UsePen(const Width: Extended);
var
  Brush: TLogBrush;
  Pen: HPEN;
begin
  FillChar(Brush, SizeOf(Brush), 0);
  Brush.lbStyle := BS_SOLID;
  Brush.lbColor := ColorToRGB(clBlack);
  Pen := ExtCreatePen(PS_GEOMETRIC or PS_SOLID or PS_ENDCAP_ROUND or PS_JOIN_ROUND,
    Max(1, Round(Width * FScale)), Brush, 0, nil);
  SelectObject(FDC, Pen);
  if FPen <> 0 then DeleteObject(FPen);
  FPen := Pen;
  SelectObject(FDC, GetStockObject(NULL_BRUSH));
end;

procedure TSketch.NoPen;
begin
  SelectObject(FDC, GetStockObject(NULL_PEN));
  if FPen <> 0 then DeleteObject(FPen);
  FPen := 0;
  SelectObject(FDC, GetStockObject(BLACK_BRUSH));
end;

procedure TSketch.Line(const X1, Y1, X2, Y2: Extended);
var
  A, B: TPoint;
begin
  UsePen(Stroke);
  A := Place(X1, Y1);
  B := Place(X2, Y2);
  MoveToEx(FDC, A.X, A.Y, nil);
  Winapi.Windows.LineTo(FDC, B.X, B.Y);
end;

procedure TSketch.Poly(const Points: array of Extended);
var
  I: Integer;
  Shape: array of TPoint;
begin
  UsePen(Stroke);
  SetLength(Shape, Length(Points) div 2);
  for I := Low(Shape) to High(Shape) do
    Shape[I] := Place(Points[I * 2], Points[I * 2 + 1]);
  Winapi.Windows.Polyline(FDC, Shape[0], Length(Shape));
end;

procedure TSketch.Curve(const Points: array of Extended);
var
  I: Integer;
  Bezier: array[0..3] of TPoint;
begin
  UsePen(Stroke);
  for I := Low(Bezier) to High(Bezier) do
    Bezier[I] := Place(Points[I * 2], Points[I * 2 + 1]);
  Winapi.Windows.PolyBezier(FDC, Bezier[0], Length(Bezier));
end;

procedure TSketch.Frame(const X, Y, W, H, Radius: Extended);
var
  A, B: TPoint;
begin
  UsePen(Stroke);
  A := Place(X, Y);
  B := Place(X + W, Y + H);
  Winapi.Windows.RoundRect(FDC, A.X, A.Y, B.X, B.Y, Round(Radius * 2 * FScale), Round(Radius * 2 * FScale));
end;

procedure TSketch.Circle(const X, Y, Radius: Extended);
var
  A, B: TPoint;
begin
  UsePen(Stroke);
  A := Place(X - Radius, Y - Radius);
  B := Place(X + Radius, Y + Radius);
  Winapi.Windows.Ellipse(FDC, A.X, A.Y, B.X, B.Y);
end;

procedure TSketch.Dot(const X, Y, Radius: Extended);
var
  A, B: TPoint;
begin
  NoPen;
  A := Place(X - Radius, Y - Radius);
  B := Place(X + Radius, Y + Radius);
  Winapi.Windows.Ellipse(FDC, A.X, A.Y, B.X, B.Y);
end;

procedure TSketch.Fill(const X, Y, W, H, Radius: Extended);
var
  A, B: TPoint;
begin
  NoPen;
  A := Place(X, Y);
  B := Place(X + W, Y + H);
  Winapi.Windows.RoundRect(FDC, A.X, A.Y, B.X, B.Y, Round(Radius * 2 * FScale), Round(Radius * 2 * FScale));
end;

procedure DrawAxes(const S: TSketch);
begin
  S.Poly([3.33, 2, 3.33, 12.67, 14, 12.67]);
  S.Poly([2, 3.33, 3.33, 2, 4.67, 3.33]);
  S.Poly([12.67, 11.33, 14, 12.67, 12.67, 14]);
end;

procedure DrawPanelLeft(const S: TSketch);
begin
  S.Frame(1.8, 2.8, 12.4, 10.4, 1.5);
  S.Line(6.4, 2.8, 6.4, 13.2);
end;

procedure DrawPanelBottom(const S: TSketch);
begin
  S.Frame(1.8, 2.8, 12.4, 10.4, 1.5);
  S.Line(1.8, 9.4, 14.2, 9.4);
end;

function Glyph(const Index: Integer; const Colors: TThemeColors; const Kind: TThemeKind): TArray<TLayer>;

  function One(const Color: TColor; const Draw: TDraw): TArray<TLayer>;
  begin
    SetLength(Result, 1);
    Result[0].Color := Color;
    Result[0].Draw := Draw;
  end;

var
  Palette: TColorArray;
begin
  case Index of
    0: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        DrawAxes(S);
        S.Curve([4.67, 11.33, 6, 5.33, 10, 5.33, 11.33, 10]);
      end);
    1: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Circle(8, 8, 5.67);
        S.Circle(8, 8, 2.33);
        S.Line(8, 8, 12, 5.73);
      end);
    3: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Frame(2.67, 2, 7.33, 8.67, 1.33);
        S.Poly([5.33, 13.33, 11.33, 13.33, 11.33, 5.33]);
      end);
    4: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Frame(3.33, 3.33, 9.33, 10.67, 1.33);
        S.Fill(6, 1.33, 4, 2.33, 1);
      end);
    5: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Poly([4.67, 6, 4.67, 2, 11.33, 2, 11.33, 6]);
        S.Frame(2, 6, 12, 4.67, 1.33);
        S.Fill(4.67, 9.33, 6.67, 4.67, 0.67);
      end);
    6: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Line(2.67, 4, 13.33, 4);
        S.Poly([6, 4, 6, 2.67, 10, 2.67, 10, 4]);
        S.Poly([4, 4, 4.67, 14, 11.33, 14, 12, 4]);
      end);
    7: Result := One(Colors.Accent,
      procedure(const S: TSketch)
      begin
        S.Curve([2, 8, 4.16, 4, 5.84, 4, 8, 8]);
        S.Curve([8, 8, 10.16, 12, 11.84, 12, 14, 8]);
      end);
    8: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Frame(2, 2, 12, 12, 1.33);
        S.Line(2, 6, 14, 6);
        S.Line(2, 10, 14, 10);
        S.Line(6, 2, 6, 14);
        S.Line(10, 2, 10, 14);
      end);
    9: Result := One(Colors.Icon, DrawAxes);
    10: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Line(8, 2, 8, 14);
        S.Line(2, 8, 14, 8);
        S.Dot(8, 8, 2);
      end);
    11: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Line(2.67, 2.67, 13.33, 13.33);
        S.Line(13.33, 2.67, 2.67, 13.33);
        S.Dot(8, 8, 2.1);
      end);
    12: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Curve([2, 8, 3.67, 4.67, 6.33, 4.67, 8, 8]);
        S.Curve([8, 8, 9.67, 11.33, 12.33, 11.33, 14, 8]);
        S.Dot(5, 5.5, 1.7);
        S.Dot(11, 10.5, 1.7);
      end);
    13: Result := One(Colors.Accent,
      procedure(const S: TSketch)
      begin
        S.Poly([8, 1.9, 3.5, 8.2]);
        S.Curve([3.5, 8.2, 1.8, 11.9, 4.7, 14.2, 8, 14.2]);
        S.Curve([8, 14.2, 11.3, 14.2, 14.2, 11.9, 12.5, 8.2]);
        S.Line(12.5, 8.2, 8, 1.9);
      end);
    14: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Poly([2, 13.4, 4.6, 13.4, 4.6, 10.8, 7.2, 10.8, 7.2, 8.2, 9.8, 8.2, 9.8, 5.6, 12.4, 5.6]);
        S.Curve([2, 10.4, 6, 9.8, 8, 2.6, 14, 2.3]);
      end);
    15:
      begin
        Palette := ThemePalette(Kind);
        SetLength(Result, 3);
        Result[0].Color := Palette[0];
        Result[0].Draw := procedure(const S: TSketch)
          begin
            S.Dot(4.6, 5.8, 2.7);
          end;
        Result[1].Color := Palette[1];
        Result[1].Draw := procedure(const S: TSketch)
          begin
            S.Dot(11.2, 6.9, 2.7);
          end;
        Result[2].Color := Palette[2];
        Result[2].Draw := procedure(const S: TSketch)
          begin
            S.Dot(7.4, 11.6, 2.7);
          end;
      end;
    16: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Line(2.2, 5.4, 13.8, 5.4);
        S.Line(2.2, 10.6, 13.8, 10.6);
        S.Dot(5.6, 5.4, 2);
        S.Dot(10.4, 10.6, 2);
      end);
    17: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Circle(8, 8, 5.9);
        S.Circle(8, 8, 3);
        S.Dot(8, 8, 1.3);
      end);
    18: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Poly([2.4, 8.6, 8.4, 2.6, 13.6, 2.6, 13.6, 7.8, 7.6, 13.8, 2.4, 8.6]);
        S.Dot(11.1, 5.1, 1.1);
      end);
    19: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        S.Poly([3.33, 12, 8, 3.33, 12.67, 12]);
        S.Line(5.33, 8.67, 10.67, 8.67);
      end);
    20: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        DrawPanelLeft(S);
        S.Poly([9.1, 5.9, 11.5, 8, 9.1, 10.1]);
      end);
    21: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        DrawPanelLeft(S);
        S.Poly([11.5, 5.9, 9.1, 8, 11.5, 10.1]);
      end);
    22: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        DrawPanelBottom(S);
        S.Poly([5.9, 5.8, 8, 3.7, 10.1, 5.8]);
      end);
    23: Result := One(Colors.Icon,
      procedure(const S: TSketch)
      begin
        DrawPanelBottom(S);
        S.Poly([5.9, 3.7, 8, 5.8, 10.1, 3.7]);
      end);
  else
    Result := nil;
  end;
end;

function LayerMask(const Draw: TDraw; const Side: Integer): TBitmap;
var
  Sketch: TSketch;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(Side, Side);
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.Brush.Style := bsSolid;
  Result.Canvas.FillRect(Rect(0, 0, Side, Side));
  FillChar(Sketch, SizeOf(Sketch), 0);
  Sketch.FDC := Result.Canvas.Handle;
  Sketch.FScale := Side / Field;
  Sketch.FOldPen := GetCurrentObject(Sketch.FDC, OBJ_PEN);
  Sketch.FOldBrush := GetCurrentObject(Sketch.FDC, OBJ_BRUSH);
  try
    Draw(Sketch);
  finally
    SelectObject(Sketch.FDC, Sketch.FOldPen);
    SelectObject(Sketch.FDC, Sketch.FOldBrush);
    if Sketch.FPen <> 0 then DeleteObject(Sketch.FPen);
  end;
end;

procedure Compose(const Bits: PQuad; const Cover: PByte; const Size: Integer; const Mask: TBitmap;
  const Color: TColor);
var
  X, Y, I, J, Sum, Ink, Back: Integer;
  Source: PByte;
  Point: PQuad;
  Total: PByte;
  Value: TColor;
begin
  Value := ColorToRGB(Color);
  for Y := 0 to Size - 1 do
  begin
    Point := Bits;
    Inc(Point, (Size - 1 - Y) * Size);
    Total := Cover;
    Inc(Total, Y * Size);
    for X := 0 to Size - 1 do
    begin
      Sum := 0;
      for J := 0 to Supersample - 1 do
      begin
        Source := Mask.ScanLine[Y * Supersample + J];
        Inc(Source, X * Supersample * 3);
        for I := 0 to Supersample - 1 do
        begin
          Inc(Sum, Source^);
          Inc(Source, 3);
        end;
      end;
      Ink := 255 - Sum div (Supersample * Supersample);
      if Ink > 0 then
      begin
        Back := 255 - Ink;
        Point.B := (GetBValue(Value) * Ink + Point.B * Back) div 255;
        Point.G := (GetGValue(Value) * Ink + Point.G * Back) div 255;
        Point.R := (GetRValue(Value) * Ink + Point.R * Back) div 255;
        if Ink > Total^ then Total^ := Ink;
      end;
      Inc(Point);
      Inc(Total);
    end;
  end;
end;

function CreateSheet(const Size: Integer; out Bits: PQuad): HBITMAP;
var
  Info: TBitmapInfo;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  Info.bmiHeader.biWidth := Size;
  Info.bmiHeader.biHeight := Size;
  Info.bmiHeader.biPlanes := 1;
  Info.bmiHeader.biBitCount := 32;
  Info.bmiHeader.biCompression := BI_RGB;
  Bits := nil;
  Result := CreateDIBSection(0, Info, DIB_RGB_COLORS, Pointer(Bits), 0, 0);
end;

function CreateMask(const Cover: PByte; const Size: Integer): HBITMAP;
var
  Stride, X, Y: Integer;
  Bits: TArray<Byte>;
  Point: PByte;
begin
  Stride := (Size + 15) div 16 * 2;
  SetLength(Bits, Stride * Size);
  for Y := 0 to Size - 1 do
  begin
    Point := Cover;
    Inc(Point, Y * Size);
    for X := 0 to Size - 1 do
    begin
      if Point^ = 0 then
        Bits[Y * Stride + X div 8] := Bits[Y * Stride + X div 8] or (128 shr (X mod 8));
      Inc(Point);
    end;
  end;
  Result := CreateBitmap(Size, Size, 1, 1, Bits);
end;

function RenderGlyph(const Index: Integer; const Kind: TThemeKind; const Size: Integer;
  const Back: TColor): TGlyphImage;
var
  I, J: Integer;
  Layers: TArray<TLayer>;
  Sketch: TBitmap;
  Bits: PQuad;
  Point: PQuad;
  Cover: TArray<Byte>;
  Ground: TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Color := CreateSheet(Size, Bits);
  if Result.Color = 0 then Exit;
  Ground := ColorToRGB(Back);
  Point := Bits;
  for I := 0 to Size * Size - 1 do
  begin
    Point.B := GetBValue(Ground);
    Point.G := GetGValue(Ground);
    Point.R := GetRValue(Ground);
    Point.A := 255;
    Inc(Point);
  end;
  SetLength(Cover, Size * Size);
  Layers := Glyph(Index, ThemeColors(Kind), Kind);
  for J := Low(Layers) to High(Layers) do
  begin
    Sketch := LayerMask(Layers[J].Draw, Size * Supersample);
    try
      Compose(Bits, @Cover[0], Size, Sketch, Layers[J].Color);
    finally
      Sketch.Free;
    end;
  end;
  for I := 0 to Size * Size - 1 do
    if Cover[I] > 0 then Inc(Result.Painted);
  Result.Mask := CreateMask(@Cover[0], Size);
end;

procedure BuildGlyphs(const Images: TCustomImageList; const Kind: TThemeKind; const Size: Integer);
var
  I: Integer;
  Image: TGlyphImage;
  List: HIMAGELIST;
begin
  if not Assigned(Images) or (Size < 8) then Exit;
  List := ImageList_Create(Size, Size, ILC_COLOR32 or ILC_MASK, GlyphCount, 0);
  if List = 0 then Exit;
  for I := 0 to GlyphCount - 1 do
  begin
    Image := RenderGlyph(I, Kind, Size, ThemeColors(Kind).Panel);
    try
      if (Image.Color <> 0) and (Image.Mask <> 0) then
        ImageList_Add(List, Image.Color, Image.Mask);
    finally
      if Image.Color <> 0 then DeleteObject(Image.Color);
      if Image.Mask <> 0 then DeleteObject(Image.Mask);
    end;
  end;
  Images.Handle := List;
end;

end.
