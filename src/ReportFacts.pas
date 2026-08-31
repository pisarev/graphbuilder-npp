{ ************************************************************************** }
{                                                                            }
{ ReportFacts                                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit ReportFacts;

{$B-}

interface

uses
  {$IFDEF FPC}
  SysUtils, Math, Classes, Graphics,
  {$ELSE}
  System.SysUtils, System.Math, System.Classes, Vcl.Graphics,
  {$ENDIF}
  CrossGraph, CrossGraph.Types, CrossGraph.Engine, CrossGraph.Geometry, ParseTypes;

function Extend(const Report: string; const Graph: TGraph; const Dark: Boolean;
  const PointsFile: string = ''): string;

procedure SavePoints(const Graph: TGraph; const FileName: string);

function AsMarkdown(const Graph: TGraph): string;

implementation

const
  Digits = '0.######';
  MinPart = 0.001;

type
  TDirection = (drNone, drUp, drDown);

function Pick(const Flag: Boolean; const Yes, No: string): string;
begin
  if Flag then
    Result := Yes
  else
    Result := No;
end;

function Web(const Value: TColor): string;
var
  RGB: LongInt;
begin
  RGB := ColorToRGB(Value);
  Result := Format('#%.2x%.2x%.2x', [Byte(RGB), Byte(RGB shr 8), Byte(RGB shr 16)]);
end;

function DrawnColour(const Graph: TGraph; const Index: Integer): TColor;
var
  Data: PFormulaData;
begin
  Result := Graph.GraphPen.Color;
  if not Graph.MultiColor then Exit;
  Data := Graph.Formula.Data[Index];
  if Assigned(Data) then Result := TColor(Data.Color);
end;

function Readable(const Value: TColor; const Dark: Boolean): string;
const
  Target = 5.0;
  Step = 0.02;
  Limit = 48;
  DarkSat = 0.55;
  DarkBack = 0.0176;
  LightBack = 0.9247;
var
  RGB: LongInt;
  R, G, B, Top, Low, H, S, L, C, P, Q, Back, Bright: Double;
  Steps, Rv, Gv, Bv: Integer;

  function Linear(const Part: Double): Double;
  begin
    if Part <= 0.03928 then
      Result := Part / 12.92
    else
      Result := Power((Part + 0.055) / 1.055, 2.4);
  end;

  function Shine(const Rr, Gg, Bb: Integer): Double;
  begin
    Result := 0.2126 * Linear(Rr / 255) + 0.7152 * Linear(Gg / 255) + 0.0722 * Linear(Bb / 255);
  end;

  function Ratio(const A, B: Double): Double;
  begin
    if A > B then
      Result := (A + 0.05) / (B + 0.05)
    else
      Result := (B + 0.05) / (A + 0.05);
  end;

  function Channel(T: Double): Double;
  begin
    if T < 0 then T := T + 1;
    if T > 1 then T := T - 1;
    if T < 1 / 6 then Exit(P + (Q - P) * 6 * T);
    if T < 1 / 2 then Exit(Q);
    if T < 2 / 3 then Exit(P + (Q - P) * (2 / 3 - T) * 6);
    Result := P;
  end;

  function Byte255(const Part: Double): Integer;
  begin
    Result := Round(Part * 255);
    if Result < 0 then Result := 0;
    if Result > 255 then Result := 255;
  end;

begin
  RGB := ColorToRGB(Value);
  R := Byte(RGB) / 255;
  G := Byte(RGB shr 8) / 255;
  B := Byte(RGB shr 16) / 255;
  Top := R;
  if G > Top then Top := G;
  if B > Top then Top := B;
  Low := R;
  if G < Low then Low := G;
  if B < Low then Low := B;
  L := (Top + Low) / 2;
  C := Top - Low;
  if C = 0 then
  begin
    H := 0;
    S := 0;
  end
  else begin
    if L > 0.5 then
      S := C / (2 - Top - Low)
    else
      S := C / (Top + Low);
    if Top = R then
    begin
      H := (G - B) / C;
      if G < B then H := H + 6;
    end
    else if Top = G then
      H := (B - R) / C + 2
    else
      H := (R - G) / C + 4;
    H := H / 6;
  end;
  if Dark and (S < DarkSat) and (C > 0) then S := DarkSat;
  if Dark then
    Back := DarkBack
  else
    Back := LightBack;
  Steps := 0;
  repeat
    if S = 0 then
    begin
      Rv := Byte255(L);
      Gv := Rv;
      Bv := Rv;
    end
    else begin
      if L < 0.5 then
        Q := L * (1 + S)
      else
        Q := L + S - L * S;
      P := 2 * L - Q;
      Rv := Byte255(Channel(H + 1 / 3));
      Gv := Byte255(Channel(H));
      Bv := Byte255(Channel(H - 1 / 3));
    end;
    Bright := Shine(Rv, Gv, Bv);
    if Ratio(Bright, Back) >= Target then Break;
    if Dark then
      L := L + Step
    else
      L := L - Step;
    Inc(Steps);
    if (L >= 1) or (L <= 0) then
    begin
      if L > 1 then L := 1;
      if L < 0 then L := 0;
    end;
  until (Steps >= Limit) or (L >= 1) or (L <= 0);
  Result := Format('#%.2x%.2x%.2x', [Rv, Gv, Bv]);
end;

const
  ChipSeparator = #9;

function Chips(const List: string): string;
var
  I: Integer;
  Part: string;
begin
  Result := '';
  if Trim(List) = '' then Exit;
  I := 1;
  Part := '';
  while I <= Length(List) do
  begin
    if List[I] = ChipSeparator then
    begin
      if Trim(Part) <> '' then
        Result := Result + '<span class="chip">' + Trim(Part) + '</span>';
      Part := '';
    end
    else
      Part := Part + List[I];
    Inc(I);
  end;
  if Trim(Part) <> '' then Result := Result + '<span class="chip">' + Trim(Part) + '</span>';
  if Result <> '' then Result := '<div class="chips">' + Result + '</div>';
end;

function Num(const Value: Extended): string;
begin
  Result := FormatFloat(Digits, Value);
end;

function ValueAt(const Graph: TGraph; const Script: TScript; const X: Extended): Extended;
begin
  Result := Graph.ComputeRectangular(X, Script).Y;
end;

function RefineRoot(const Graph: TGraph; const Script: TScript; ALeft, ARight: Extended): Extended;
const
  Steps = 64;
var
  I: Integer;
  Middle, Left, Value: Extended;
begin
  Left := ValueAt(Graph, Script, ALeft);
  for I := 1 to Steps do
  begin
    Middle := (ALeft + ARight) / 2;
    Value := ValueAt(Graph, Script, Middle);
    if Value = 0 then Exit(Middle);
    if (Left < 0) = (Value < 0) then
    begin
      ALeft := Middle;
      Left := Value;
    end
    else
      ARight := Middle;
  end;
  Result := (ALeft + ARight) / 2;
end;

function Escape(const Text: string): string;
begin
  Result := StringReplace(Text, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function CurveRange(const Graph: TGraph; const Index: Integer; out Back, Face: Integer): Boolean;
var
  Data: PFormulaData;
begin
  Result := False;
  Data := Graph.Formula.Data[Index];
  if not Assigned(Data) then Exit;
  Back := Data.EntireBack.ArrayIndex;
  Face := Data.EntireFace.ArrayIndex;
  Result := (Back >= 0) and (Face >= Back) and (Face <= High(Graph.EntireArray));
end;

function Roots(const Graph: TGraph; const Index, Back, Face: Integer): string;
var
  I, J, Count: Integer;
  Points: TPointDArray;
  Data: PFormulaData;
  Root: Extended;
begin
  Result := '';
  Count := 0;
  Data := Graph.Formula.Data[Index];
  if not Check(Graph.SA, Data.ScriptIndex) then Exit;
  for I := Back to Face do
  begin
    Points := Graph.EntireArray[I];
    for J := Low(Points) to High(Points) - 1 do
      if (Points[J].Y = 0) or ((Points[J].Y < 0) <> (Points[J + 1].Y < 0)) then
      begin
        if Points[J].Y = 0 then
          Root := Points[J].X
        else
          Root := RefineRoot(Graph, Graph.SA[Data.ScriptIndex], Points[J].X, Points[J + 1].X);
        if Result <> '' then Result := Result + ChipSeparator;
        Result := Result + Num(Root);
        Inc(Count);
        if Count >= 50 then Exit(Result + ChipSeparator + '...');
      end;
  end;
end;

function Breaks(const Graph: TGraph; const Back, Face: Integer): string;
var
  I: Integer;
  Left, Right: TPointDArray;
begin
  Result := '';
  for I := Back to Face - 1 do
  begin
    Left := Graph.EntireArray[I];
    Right := Graph.EntireArray[I + 1];
    if (Length(Left) = 0) or (Length(Right) = 0) then Continue;
    if Result <> '' then Result := Result + ChipSeparator;
    Result := Result + Num((Left[High(Left)].X + Right[0].X) / 2);
  end;
end;

function VertexOfThree(const X0, Y0, X1, Y1, X2, Y2: Extended): Extended;
var
  D1, D2, A, B: Extended;
begin
  Result := X1;
  D1 := X1 - X0;
  D2 := X2 - X1;
  if (D1 <= 0) or (D2 <= 0) then Exit;
  A := (D2 * (Y0 - Y1) + D1 * (Y2 - Y1)) / (D1 * D2 * (D1 + D2));
  if A = 0 then Exit;
  B := ((Y2 - Y1) - A * D2 * D2) / D2;
  Result := X1 - B / (2 * A);
  if Result < X0 then Result := X0;
  if Result > X2 then Result := X2;
end;

function RefineTurn(const Graph: TGraph; const Script: TScript; ALeft, ARight: Extended;
  const Top: Boolean): Extended;
const
  Steps = 40;
var
  I: Integer;
  M1, M2, V1, V2: Extended;
begin
  for I := 1 to Steps do
  begin
    M1 := ALeft + (ARight - ALeft) / 3;
    M2 := ARight - (ARight - ALeft) / 3;
    V1 := ValueAt(Graph, Script, M1);
    V2 := ValueAt(Graph, Script, M2);
    if Top then
    begin
      if V1 < V2 then
        ALeft := M1
      else
        ARight := M2;
    end
    else begin
      if V1 > V2 then
        ALeft := M1
      else
        ARight := M2;
    end;
  end;
  Result := (ALeft + ARight) / 2;
end;

function MonotoneParts(const Graph: TGraph; const Index, Back, Face: Integer): string;
var
  I, J: Integer;
  Points: TPointDArray;
  Direction, Next: TDirection;
  Start, Width, Turn: Extended;
  Data: PFormulaData;
  Exact: Boolean;

  procedure Flush(const Till: Extended);
  const
    Names: array[TDirection] of string = ('', 'up', 'down');
  begin
    if (Direction = drNone) or (Abs(Till - Start) < Width * MinPart) then Exit;
    Result := Result + Format('%s|%s|%s'#9, [Num(Start), Num(Till), Names[Direction]]);
  end;

begin
  Result := '';
  Width := Graph.MaxX * 2;
  if Width <= 0 then Exit;
  Data := Graph.Formula.Data[Index];
  Exact := Check(Graph.SA, Data.ScriptIndex);
  for I := Back to Face do
  begin
    Points := Graph.EntireArray[I];
    if Length(Points) < 2 then Continue;
    Direction := drNone;
    Start := Points[0].X;
    for J := Low(Points) to High(Points) - 1 do
    begin
      if Points[J + 1].Y > Points[J].Y then
        Next := drUp
      else if Points[J + 1].Y < Points[J].Y then
        Next := drDown
      else
        Next := Direction;
      if (Next <> Direction) and (Next <> drNone) then
      begin
        Turn := Points[J].X;
        if (J > Low(Points)) and (Direction <> drNone) then
        begin
          if Exact then
            Turn := RefineTurn(Graph, Graph.SA[Data.ScriptIndex],
                               Points[J - 1].X, Points[J + 1].X,
                               Direction = drUp)
          else
            Turn := VertexOfThree(Points[J - 1].X, Points[J - 1].Y,
                                  Points[J].X, Points[J].Y,
                                  Points[J + 1].X, Points[J + 1].Y);
        end;
        Flush(Turn);
        Direction := Next;
        Start := Turn;
      end;
    end;
    Flush(Points[High(Points)].X);
  end;
end;

function Monotone(const Graph: TGraph; const Index, Back, Face: Integer): string;
const
  Arrows: array[Boolean] of string = ('&#8600;', '&#8599;');
var
  Parts, Item: string;
  Bar: Integer;
  Up: Boolean;
begin
  Result := '';
  Parts := MonotoneParts(Graph, Index, Back, Face);
  while Parts <> '' do
  begin
    Bar := Pos(#9, Parts);
    if Bar = 0 then Break;
    Item := Copy(Parts, 1, Bar - 1);
    Parts := Copy(Parts, Bar + 1, MaxInt);
    Up := Copy(Item, Length(Item) - 1, 2) = 'up';
    Item := Copy(Item, 1, LastDelimiter('|', Item) - 1);
    Result := Result + Format('<span class="chip">%s <span class="arr %s">%s</span></span>',
      [StringReplace(Item, '|', ' .. ', []), Pick(Up, 'up', 'down'), Arrows[Up]]);
  end;
  if Result <> '' then Result := '<div class="chips">' + Result + '</div>';
end;

procedure AreaAndMean(const Graph: TGraph; const Back, Face: Integer; out Area, Mean: Extended);
var
  I, J: Integer;
  Points: TPointDArray;
  Width: Extended;
begin
  Area := 0;
  Mean := 0;
  Width := 0;
  for I := Back to Face do
  begin
    Points := Graph.EntireArray[I];
    for J := Low(Points) to High(Points) - 1 do
    begin
      Area := Area + (Points[J].Y + Points[J + 1].Y) / 2 * (Points[J + 1].X - Points[J].X);
      Width := Width + (Points[J + 1].X - Points[J].X);
    end;
  end;
  if Width > 0 then Mean := Area / Width;
end;

function Row(const Name, Value: string): string;
begin
  if Trim(Value) = '' then Exit('');
  Result := Format('<div class="k">%s</div><div class="v">%s</div>', [Escape(Name), Value]);
end;

function TextRow(const Name, Value: string): string;
begin
  if Trim(Value) = '' then Exit('');
  Result := Row(Name, Escape(Value));
end;

function Facts(const Graph: TGraph; const Dark: Boolean): string;
var
  I, Back, Face, Count: Integer;
  Area, Mean: Extended;
  Table, Colour, Ink: string;
  Data: PFormulaData;
begin
  Result := '';
  if not Assigned(Graph) or (Graph.CS <> csRectangular) then Exit;
  for I := 0 to Graph.Formula.Count - 1 do
  begin
    if not Graph.Formula.Active[I] or not Graph.Formula.Correct[I] then Continue;
    if not CurveRange(Graph, I, Back, Face) then Continue;
    AreaAndMean(Graph, Back, Face, Area, Mean);
    Count := Face - Back;
    Table := Row('Roots', Chips(Roots(Graph, I, Back, Face))) +
      Row('Domain breaks *', Chips(Breaks(Graph, Back, Face))) +
      TextRow('Curve pieces *', IntToStr(Count + 1)) +
      Row('Monotonicity', Monotone(Graph, I, Back, Face)) +
      TextRow('Area under the curve *', Num(Area)) + TextRow('Mean value *', Num(Mean));
    if Table = '' then Continue;
    Data := Graph.Formula.Data[I];
    Colour := '#888888';
    Ink := '#888888';
    if Assigned(Data) then
    begin
      Colour := Web(DrawnColour(Graph, I));
      Ink := Readable(DrawnColour(Graph, I), Dark);
    end;
    Result := Result + Format(
      '<div class="fn"><div class="fn-head">' +
      '<span class="fn-dot" style="background:%s"></span>' +
      '<span class="fn-name" style="color:%s">%s</span></div>' +
      '<div class="kv">%s</div></div>',
      [
        Colour,
        Ink,
        Escape(Graph.Formula[I]),
        Table
      ]
    );
  end;
  if Result = '' then Exit;
  Result := '<section class="factbox"><h2>Facts about the functions</h2>' +
    '<p class="note">A star marks what is computed FROM SAMPLES - on ' +
    'the same grid the curve is drawn on, and that grid thickens where ' +
    'the function runs steep. The rest is taken to its true value: roots ' +
    'by halving the interval, the bounds of monotonicity by looking for the vertex between grid nodes.</p>' +
    Result + '</section>';
end;

procedure SavePoints(const Graph: TGraph; const FileName: string);
var
  List: TStringList;
  I, J, K, Back, Face: Integer;
  Points: TPointDArray;
begin
  if not Assigned(Graph) then Exit;
  List := TStringList.Create;
  try
    List.Add('formula;curve;x;y');
    for I := 0 to Graph.Formula.Count - 1 do
    begin
      if not Graph.Formula.Active[I] then Continue;
      if not CurveRange(Graph, I, Back, Face) then Continue;
      for J := Back to Face do
      begin
        Points := Graph.EntireArray[J];
        for K := Low(Points) to High(Points) do
          List.Add(Format('%s;%d;%s;%s', [Graph.Formula[I], J - Back, Num(Points[K].X), Num(Points[K].Y)]));
      end;
    end;
    List.SaveToFile(FileName, TEncoding.UTF8);
  finally
    List.Free;
  end;
end;

function Body(const Graph: TGraph; const Dark: Boolean): string;
var
  Text: TStringBuilder;

  function XY(const Value: Extended; const Y: Boolean): string;
  begin
    if Y then
      Result := FormatFloat(Graph.FloatFormat(Graph.YFormat), Value)
    else
      Result := FormatFloat(Graph.FloatFormat(Graph.XFormat), Value);
  end;

  function Away(const Point: TPointD): string;
  begin
    Result := FormatFloat(Graph.FloatFormat(Graph.XYFormat), DistanceOf(ZeroPoint, Point));
  end;

  function Turn(const Angle: Extended): string;
  begin
    Result := FormatFloat(Graph.FloatFormat(Graph.AngleFormat), RadToDeg(Angle)) +
      '&deg; <span class="k">(' + FormatFloat(Graph.FloatFormat(Graph.AngleFormat), Angle) +
      ' rad)</span>';
  end;

  function Tint(const Index: Integer; const ForText: Boolean): string;
  var
    Data: PFormulaData;
  begin
    Result := '#888888';
    Data := Graph.Formula.Data[Index];
    if not Assigned(Data) then Exit;
    if ForText then
      Result := Readable(DrawnColour(Graph, Index), Dark)
    else
      Result := Web(DrawnColour(Graph, Index));
  end;

  function Named(const Index: Integer): string;
  begin
    Result := Format(
      '<span class="pair"><span class="fn-dot" style="background:%s">' +
      '</span><span class="mono" style="color:%s">%s</span></span>',
      [
        Tint(
          Index,
          False
        ),
        Tint(
          Index,
          True
        ),
        Escape(Graph.Formula[Index])
      ]
    );
  end;

  procedure Tile(const Name, Value: string);
  begin
    Text.Append('<div class="tile"><div class="t">').Append(Name)
      .Append('</div><div class="d">').Append(Value).Append('</div></div>');
  end;

  procedure Head(const Name: string);
  begin
    Text.Append('<h3>').Append(Name).Append('</h3>');
  end;

  function Whole(const Same: TSame): Boolean;
  var
    Span: Extended;
  begin
    if Graph.CS = csPolar then
      Span := Graph.PolarMaxAngle
    else
      Span := 2 * Graph.MaxX;
    if Span <= 0 then Exit(False);
    Result := Same.Range.Max - Same.Range.Min >= Span * 0.9;
  end;

var
  I, J, K: Integer;
  Overlap: TOverlap;
  Same: TSame;
  Point: TPointD;
  Curve: TCurveDArray;
  Had: Boolean;
  Kind: string;
begin
  Result := '';
  if not Assigned(Graph) then Exit;
  Text := TStringBuilder.Create;
  try
    Text.Append('<section><h2>The plot report</h2>');
    Text.Append('<div class="tiles">');
    Tile('Coordinate system', Pick(Graph.CS = csRectangular, 'Cartesian', 'Polar'));
    if Graph.CS = csRectangular then
      Tile('X range', XY(-Graph.MaxX - Graph.Offset.X, False) + ' .. ' +
        XY(Graph.MaxX - Graph.Offset.X, False))
    else
      Tile('Angle limit', Turn(Graph.PolarMaxAngle));
    Tile('Quality', IntToStr(Graph.Quality));
    Tile('High precision', Pick(Graph.HighPrecision, 'on', 'off'));
    Text.Append('</div>');
    Head('The window');
    Text.Append('<div class="kv">');
    Text.Append(TextRow('Centre', 'X: ' + XY(-Graph.Offset.X, False) + ', Y: ' + XY(-Graph.Offset.Y, True)));
    Text.Append(TextRow('Size',
      'across ' + XY(Graph.MaxX * 2, False) + ', down ' + XY(Graph.MaxY * 2, True)));
    Text.Append('</div>');
    Head('Formulas');
    Text.Append('<div class="chips">');
    for I := 0 to Graph.Formula.Count - 1 do
      if Graph.Formula.Active[I] then
        Text.Append('<span class="chip">').Append(Named(I)).Append('</span>');
    Text.Append('</div>');
    if Graph.Overlap and not Graph.Busy and (Graph.Formula.ActiveCount > 0) then
    begin
      Head('Intersections');
      Had := False;
      Text.Append('<table class="pts"><tr><th>Point</th><th>X</th><th>Y</th>' +
        '<th>From the centre</th><th>Curves</th></tr>');
      for J := Low(Graph.OverlapArray) to High(Graph.OverlapArray) do
      begin
        Overlap := Graph.OverlapArray[J];
        if not Graph.Formula.Active[Overlap.AFormula] then Continue;
        if not Graph.Formula.Active[Overlap.BFormula] then Continue;
        Had := True;
        Text.Append('<tr><td><span class="nm">').Append(Escape(Graph.OverlapName[J]))
          .Append('</span></td><td>').Append(XY(Overlap.Point.X, False))
          .Append('</td><td>').Append(XY(Overlap.Point.Y, True))
          .Append('</td><td>').Append(Away(Overlap.Point)).Append('</td><td>');
        if Graph.CS = csRectangular then
          Text.Append(Named(Overlap.AFormula)).Append(Named(Overlap.BFormula))
        else
          Text.Append(Named(Overlap.AFormula)).Append('<span class="k"> at ')
            .Append(Turn(Overlap.AAngle)).Append('</span>')
            .Append(Named(Overlap.BFormula)).Append('<span class="k"> at ')
            .Append(Turn(Overlap.BAngle)).Append('</span>');
        Text.Append('</td></tr>');
      end;
      Text.Append('</table>');
      if not Had then Text.Append('<p class="note">No intersections were found.</p>');
      if Graph.OverlapTotal > Length(Graph.OverlapArray) then
        Text.Append('<p class="note">Intersections found: ')
          .Append(IntToStr(Graph.OverlapTotal)).Append(', marked: ')
          .Append(IntToStr(Length(Graph.OverlapArray)))
          .Append('. The rest are closer than ').Append(IntToStr(Graph.MarkSpacing))
          .Append(' pixels to each other.</p>');
      for J := Low(Graph.SameArray) to High(Graph.SameArray) do
      begin
        Same := Graph.SameArray[J];
        if not Graph.Formula.Active[Same.AFormula] then Continue;
        if not Graph.Formula.Active[Same.BFormula] then Continue;
        Text.Append('<p class="note">Curves ').Append(Named(Same.AFormula))
          .Append(' and ').Append(Named(Same.BFormula));
        if Whole(Same) then
          Text.Append(' coincide completely: this is one and the same line.</p>')
        else
          Text.Append(' are indistinguishable on the span from (')
            .Append(XY(Same.Back.X, False)).Append(', ')
            .Append(XY(Same.Back.Y, True)).Append(') to (')
            .Append(XY(Same.Face.X, False)).Append(', ')
            .Append(XY(Same.Face.Y, True))
            .Append('): there are no separate intersection points there.</p>');
      end;
    end;
    if Graph.Extreme and not Graph.Busy and (Graph.Formula.ActiveCount > 0) then
    begin
      Head('Extrema');
      Had := False;
      Text.Append('<table class="pts"><tr><th>Kind</th><th>X</th><th>Y</th>' +
        '<th>From the centre</th>' + Pick(Graph.CS = csRectangular,
        '', '<th>Angle</th>') + '</tr>');
      for I := 0 to 1 do
      begin
        if I = 0 then
        begin
          Curve := Graph.MaxArray;
          Kind := 'maximum';
        end
        else begin
          Curve := Graph.MinArray;
          Kind := 'minimum';
        end;
        for J := Low(Curve) to High(Curve) do
          if Assigned(Curve[J]) then
            for K := Low(Curve[J]) to High(Curve[J]) do
            begin
              Point := Curve[J, K];
              Had := True;
              Text.Append('<tr><td><span class="arr ').Append(Pick(I = 0, 'up', 'down'))
                .Append('">').Append(Pick(I = 0, '&#8599;', '&#8600;'))
                .Append('</span> ').Append(Kind).Append('</td><td>')
                .Append(XY(Point.X, False)).Append('</td><td>')
                .Append(XY(Point.Y, True)).Append('</td><td>')
                .Append(Away(Point)).Append('</td>');
              if Graph.CS <> csRectangular then
                Text.Append('<td>')
                  .Append(Turn(CounterClockwise(Point, LineAngle(Point, ZeroPoint))))
                  .Append('</td>');
              Text.Append('</tr>');
            end;
      end;
      Text.Append('</table>');
      if not Had then Text.Append('<p class="note">No extrema were found.</p>');
    end;
    Text.Append('</section>');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function Style(const Dark: Boolean): string;
const
  Light = '--r-ink:#1e242c;--r-dim:#5c6570;--r-faint:#98a0ac;--r-line:#e6e9ee;' +
    '--r-soft:#f4f6f9;--r-card:#ffffff;--r-up:#12855f;--r-down:#c0392b;';
  Dim = '--r-ink:#e6e9ee;--r-dim:#a7b0bb;--r-faint:#7d8792;--r-line:#333941;' +
    '--r-soft:#23272d;--r-card:#1c2024;--r-up:#4fd1a5;--r-down:#ff8a80;';
begin
  Result := '<style>' +
    '.rep{' +
    'color:var(--ink,var(--r-ink));' +
    'font:13px/1.55 "Segoe UI",system-ui,sans-serif;' +
    Pick(Dark, Dim, Light) +
    '}' +
    '.rep h2{font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:.8px;' +
    'color:var(--ink-faint,var(--r-faint));margin:0 0 14px;padding-bottom:8px;' +
    'border-bottom:1px solid var(--line,var(--r-line))}' +
    '.rep h3{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.7px;' +
    'color:var(--ink-faint,var(--r-faint));margin:22px 0 9px}' +
    '.rep section{margin:0 0 26px}' +
    '.rep .fn{border:1px solid var(--line,var(--r-line));border-radius:10px;' +
    'background:var(--panel,var(--r-card));margin:0 0 12px;overflow:hidden}' +
    '.rep .fn-head{display:flex;align-items:center;gap:9px;padding:10px 14px;' +
    'border-bottom:1px solid var(--line,var(--r-line));' +
    'background:var(--line-soft,var(--r-soft))}' +
    '.rep .fn-dot{width:10px;height:10px;border-radius:50%;flex:none;' +
    'box-shadow:0 0 0 1px rgba(128,128,128,.5)}' +
    '.rep .fn-name{font-family:"Cascadia Mono",Consolas,ui-monospace,monospace;' +
    'font-size:13px;font-weight:600}' +
    '.rep .kv{display:grid;grid-template-columns:minmax(120px,168px) 1fr;gap:1px;' +
    'background:var(--line,var(--r-line))}' +
    '.rep .kv>div{background:var(--panel,var(--r-card));padding:9px 14px}' +
    '.rep .kv .k{color:var(--ink-dim,var(--r-dim));font-size:12px}' +
    '.rep .kv .v{font-variant-numeric:tabular-nums}' +
    '.rep .chips{display:flex;flex-wrap:wrap;gap:5px}' +
    '.rep .chip{display:inline-flex;align-items:center;gap:5px;' +
    'padding:2px 8px;border-radius:6px;background:var(--line-soft,var(--r-soft));' +
    'border:1px solid var(--line,var(--r-line));' +
    'font-family:"Cascadia Mono",Consolas,ui-monospace,monospace;font-size:11.5px;' +
    'font-variant-numeric:tabular-nums;white-space:nowrap}' +
    '.rep .up{color:var(--r-up)}.rep .down{color:var(--r-down)}' +
    '.rep .arr{font-size:12px;line-height:1}' +
    '.rep .tiles{display:flex;flex-wrap:wrap;gap:8px}' +
    '.rep .tile{flex:1 1 132px;border:1px solid var(--line,var(--r-line));border-radius:9px;' +
    'background:var(--panel,var(--r-card));padding:10px 13px}' +
    '.rep .tile .t{color:var(--ink-faint,var(--r-faint));font-size:10.5px;' +
    'text-transform:uppercase;letter-spacing:.6px}' +
    '.rep .tile .d{margin-top:3px;font-size:14px;font-variant-numeric:tabular-nums}' +
    '.rep table.pts{width:100%;border-collapse:collapse;font-size:12px}' +
    '.rep table.pts th{text-align:left;font-weight:600;font-size:10.5px;' +
    'text-transform:uppercase;letter-spacing:.6px;color:var(--ink-faint,var(--r-faint));' +
    'padding:0 12px 7px 0;border-bottom:1px solid var(--line,var(--r-line))}' +
    '.rep table.pts td{padding:8px 12px 8px 0;border-bottom:1px solid var(--line,var(--r-line));' +
    'font-variant-numeric:tabular-nums;vertical-align:top}' +
    '.rep table.pts tr:last-child td{border-bottom:0}' +
    '.rep .nm{display:inline-flex;align-items:center;justify-content:center;' +
    'min-width:20px;height:20px;padding:0 5px;border-radius:5px;' +
    'background:var(--accent-soft,rgba(47,111,235,.10));color:var(--accent,#2f6feb);' +
    'font-size:11px;font-weight:600}' +
    '.rep .pair{display:flex;align-items:center;gap:6px;margin:2px 0}' +
    '.rep .note{color:var(--ink-faint,var(--r-faint));font-size:11.5px;margin:10px 0 0}' +
    '.rep .mono{font-family:"Cascadia Mono",Consolas,ui-monospace,monospace}' +
    '</style>';
end;

function Cell(const Text: string): string;
begin
  Result := StringReplace(Trim(Text), '|', '/', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '; ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  if Result = '' then Result := 'none';
end;

function MonotoneText(const Graph: TGraph; const Index, Back, Face: Integer): string;
var
  Parts, Item, Bounds: string;
  Bar: Integer;
begin
  Result := '';
  Parts := MonotoneParts(Graph, Index, Back, Face);
  while Parts <> '' do
  begin
    Bar := Pos(#9, Parts);
    if Bar = 0 then Break;
    Item := Copy(Parts, 1, Bar - 1);
    Parts := Copy(Parts, Bar + 1, MaxInt);
    Bounds := Copy(Item, 1, LastDelimiter('|', Item) - 1);
    if Result <> '' then Result := Result + '; ';
    Result := Result + StringReplace(Bounds, '|', ' .. ', []) +
      Pick(Copy(Item, Length(Item) - 1, 2) = 'up', ' up', ' down');
  end;
end;

function Sketch(const Graph: TGraph): string;
const
  Width = 640;
  Height = 360;
  Pad = 12;
  Limit = 1200;
var
  I, J, K, Back, Face, Total, Stride, Emitted: Integer;
  Points: TPointDArray;
  MinX, MaxX, MinY, MaxY, SpanX, SpanY, ScaleX, ScaleY: Extended;
  Path, Colour: string;
  Data: PFormulaData;
  Started: Boolean;
  Plain: TFormatSettings;

  function MapX(const Value: Extended): string;
  begin
    Result := FormatFloat('0.##', Pad + (Value - MinX) * ScaleX, Plain);
  end;

  function MapY(const Value: Extended): string;
  begin
    Result := FormatFloat('0.##', Height - Pad - (Value - MinY) * ScaleY, Plain);
  end;

begin
  Result := '';
  if not Assigned(Graph) then Exit;
  {$IFDEF FPC}
  Plain := DefaultFormatSettings;
  {$ELSE}
  Plain := TFormatSettings.Invariant;
  {$ENDIF}
  Plain.DecimalSeparator := '.';
  MinX := 0;
  MaxX := 0;
  MinY := 0;
  MaxY := 0;
  Total := 0;
  for I := 0 to Graph.Formula.Count - 1 do
  begin
    if not Graph.Formula.Active[I] or not CurveRange(Graph, I, Back, Face) then Continue;
    for J := Back to Face do
    begin
      Points := Graph.EntireArray[J];
      for K := Low(Points) to High(Points) do
      begin
        if Total = 0 then
        begin
          MinX := Points[K].X;
          MaxX := MinX;
          MinY := Points[K].Y;
          MaxY := MinY;
        end
        else begin
          if Points[K].X < MinX then MinX := Points[K].X;
          if Points[K].X > MaxX then MaxX := Points[K].X;
          if Points[K].Y < MinY then MinY := Points[K].Y;
          if Points[K].Y > MaxY then MaxY := Points[K].Y;
        end;
        Inc(Total);
      end;
    end;
  end;
  if Total = 0 then Exit;
  SpanX := MaxX - MinX;
  SpanY := MaxY - MinY;
  if SpanX <= 0 then SpanX := 1;
  if SpanY <= 0 then SpanY := 1;
  ScaleX := (Width - 2 * Pad) / SpanX;
  ScaleY := (Height - 2 * Pad) / SpanY;
  Stride := 1;
  if Total > Limit then Stride := (Total div Limit) + 1;
  Result := Format('<svg viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg" ' +
    'width="%d" height="%d">', [Width, Height, Width, Height]);
  for I := 0 to Graph.Formula.Count - 1 do
  begin
    if not Graph.Formula.Active[I] or not CurveRange(Graph, I, Back, Face) then Continue;
    Data := Graph.Formula.Data[I];
    if Assigned(Data) then
      Colour := Web(TColor(Data.Color))
    else
      Colour := '#888888';
    Path := '';
    for J := Back to Face do
    begin
      Points := Graph.EntireArray[J];
      if Length(Points) < 2 then Continue;
      Started := False;
      Emitted := 0;
      K := Low(Points);
      while K <= High(Points) do
      begin
        if Started then
          Path := Path + 'L' + MapX(Points[K].X) + ' ' + MapY(Points[K].Y)
        else begin
          Path := Path + 'M' + MapX(Points[K].X) + ' ' + MapY(Points[K].Y);
          Started := True;
        end;
        Inc(Emitted);
        Inc(K, Stride);
      end;
      if Started and (Emitted > 0) then
        Path := Path + 'L' + MapX(Points[High(Points)].X) + ' ' + MapY(Points[High(Points)].Y);
    end;
    if Path = '' then Continue;
    Result := Result + Format('<path d="%s" fill="none" stroke="%s" stroke-width="1.6" ' +
      'stroke-linejoin="round" stroke-linecap="round"/>', [Path, Colour]);
  end;
  Result := Result + '</svg>';
end;

function AsMarkdown(const Graph: TGraph): string;
var
  Text: TStringBuilder;
  I, J, Back, Face: Integer;
  Area, Mean: Extended;
  Overlap: TOverlap;
  Had: Boolean;
  Curve: TCurveDArray;
  Kind: string;
  K: Integer;

  procedure Fact(const Name, Value: string);
  begin
    Text.Append('| ').Append(Name).Append(' | ').Append(Cell(Value)).Append(' |').AppendLine;
  end;

begin
  Result := '';
  if not Assigned(Graph) then Exit;
  Text := TStringBuilder.Create;
  try
    Text.Append('# Graph').AppendLine.AppendLine;
    Text.Append(Pick(Graph.CS = csPolar, 'Polar coordinates', 'Cartesian coordinates'));
    Text.Append(', X from ').Append(Num(-Graph.MaxX)).Append(' to ').Append(Num(Graph.MaxX));
    Text.Append(', Y from ').Append(Num(-Graph.MaxY)).Append(' to ').Append(Num(Graph.MaxY));
    Text.Append('.').AppendLine.AppendLine;
    for I := 0 to Graph.Formula.Count - 1 do
    begin
      if not Graph.Formula.Active[I] or not Graph.Formula.Correct[I] then Continue;
      Text.Append('## ').Append(Graph.Formula[I]).AppendLine.AppendLine;
      if not CurveRange(Graph, I, Back, Face) then
      begin
        Text.Append('No curve was plotted.').AppendLine.AppendLine;
        Continue;
      end;
      if Graph.CS <> csRectangular then
      begin
        Text.Append('A polar curve: roots, monotonic intervals and the area under ');
        Text.Append('the curve are not computed for it.').AppendLine.AppendLine;
        Continue;
      end;
      AreaAndMean(Graph, Back, Face, Area, Mean);
      Text.Append('| fact | value |').AppendLine;
      Text.Append('| --- | --- |').AppendLine;
      Fact('Roots', Roots(Graph, I, Back, Face));
      Fact('Domain breaks', Breaks(Graph, Back, Face));
      Fact('Curve pieces', IntToStr(Face - Back + 1));
      Fact('Monotonicity', MonotoneText(Graph, I, Back, Face));
      Fact('Area under the curve', Num(Area));
      Fact('Mean value', Num(Mean));
      Text.AppendLine;
    end;
    Had := False;
    for J := Low(Graph.OverlapArray) to High(Graph.OverlapArray) do
    begin
      Overlap := Graph.OverlapArray[J];
      if not Graph.Formula.Active[Overlap.AFormula] then Continue;
      if not Graph.Formula.Active[Overlap.BFormula] then Continue;
      if not Had then
      begin
        Text.Append('## Intersections').AppendLine.AppendLine;
        Text.Append('| point | X | Y | curves |').AppendLine;
        Text.Append('| --- | --- | --- | --- |').AppendLine;
        Had := True;
      end;
      Text.Append('| ').Append(Cell(Graph.OverlapName[J]));
      Text.Append(' | ').Append(Num(Overlap.Point.X));
      Text.Append(' | ').Append(Num(Overlap.Point.Y));
      Text.Append(' | ').Append(Cell(Graph.Formula[Overlap.AFormula]));
      Text.Append(' and ').Append(Cell(Graph.Formula[Overlap.BFormula]));
      Text.Append(' |').AppendLine;
    end;
    if Had then
    begin
      if Graph.OverlapTotal > Length(Graph.OverlapArray) then
      begin
        Text.AppendLine;
        Text.Append(Format('Found %d, listed %d: the rest are closer than %d pixels to one another.',
          [Graph.OverlapTotal, Length(Graph.OverlapArray), Graph.MarkSpacing])).AppendLine;
      end;
      Text.AppendLine;
    end;
    Had := False;
    for I := 0 to 1 do
    begin
      if I = 0 then
      begin
        Curve := Graph.MaxArray;
        Kind := 'maximum';
      end
      else begin
        Curve := Graph.MinArray;
        Kind := 'minimum';
      end;
      for J := Low(Curve) to High(Curve) do
      begin
        if not Assigned(Curve[J]) then Continue;
        for K := Low(Curve[J]) to High(Curve[J]) do
        begin
          if not Had then
          begin
            Text.Append('## Extrema').AppendLine.AppendLine;
            Text.Append('| kind | X | Y |').AppendLine;
            Text.Append('| --- | --- | --- |').AppendLine;
            Had := True;
          end;
          Text.Append('| ').Append(Kind);
          Text.Append(' | ').Append(Num(Curve[J, K].X));
          Text.Append(' | ').Append(Num(Curve[J, K].Y));
          Text.Append(' |').AppendLine;
        end;
      end;
    end;
    if Had then Text.AppendLine;
    Kind := Sketch(Graph);
    if Kind <> '' then
    begin
      Text.Append('## The curve').AppendLine.AppendLine;
      Text.Append(Kind).AppendLine.AppendLine;
      Text.Append('The drawing is embedded as SVG: text in the editor, ');
      Text.Append('a real curve wherever it is rendered.').AppendLine;
    end;
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function Extend(const Report: string; const Graph: TGraph; const Dark: Boolean;
  const PointsFile: string): string;
const
  Charset = '<meta charset="utf-8">';
var
  Block, Link: string;
  Place: Integer;
begin
  Result := Report;
  if Pos('charset', LowerCase(Result)) = 0 then
    Result := StringReplace(Result, '<head>', '<head>' + Charset, [rfIgnoreCase]);
  Result := StringReplace(Result, '</head>', Style(Dark) + '</head>', [rfIgnoreCase]);
  if Pos('<body></body>', StringReplace(LowerCase(Result), ' ', '', [rfReplaceAll])) > 0 then
    Result := StringReplace(Result, '</body>',
      '<div class="rep">' + Body(Graph, Dark) + '</div></body>', [rfIgnoreCase]);
  Block := Facts(Graph, Dark);
  if (Block = '') and Assigned(Graph) and (Graph.CS <> csRectangular) then
    Block := '<section class="factbox"><h2>Facts about the functions</h2><p class="note">' +
      'Roots, monotonicity, area and mean are defined for a function of X, ' +
      'so they are not computed in polar coordinates.</p></section>';
  if PointsFile <> '' then
  begin
    Link := Format('<p class="note">Curve points: <a href="%s">%s</a></p>',
      [ExtractFileName(PointsFile), ExtractFileName(PointsFile)]);
    Block := StringReplace(Block, '</section>', Link + '</section>', []);
  end;
  if Block <> '' then Block := '<div class="rep">' + Block + '</div>';
  Place := Pos('</body>', LowerCase(Result));
  if Place = 0 then
    Result := Result + Block
  else
    Result := Copy(Result, 1, Place - 1) + Block + Copy(Result, Place, MaxInt);
end;

end.
