{ ************************************************************************** }
{                                                                            }
{ DarkTheme                                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit DarkTheme;

{$B-}

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils, System.TypInfo,
  System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Grids, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.ImgList, CrossGraph, CrossGraph.Types;

const
  ThemeFont = 'Segoe UI';
  ThemeFontSize = 9;
  MinimumFontSize = 7;

type
  TThemeKind = (tkLight, tkDark);

  TThemeColors = record
    Window: TColor;
    Panel: TColor;
    Surface: TColor;
    Border: TColor;
    Text: TColor;
    Muted: TColor;
    Icon: TColor;
    Accent: TColor;
    Grid: TColor;
    Axis: TColor;
    Marker: TColor;
    Trace: TColor;
  end;

procedure ApplyTheme(const Form: TCustomForm; const Graph: TGraph; const Kind: TThemeKind);

function ThemeColors(const Kind: TThemeKind): TThemeColors;

function ThemePalette(const Kind: TThemeKind): TColorArray;

function CurrentColors: TThemeColors;

function Mix(const A, B: TColor; const Factor: Byte): TColor;

procedure SkinButton(const Button: TControl);

implementation

uses
  Glyphs;

type
  TTone = Cardinal;

  TThemeTones = record
    Window, Panel, Surface, Border, Text, Muted, Icon, Accent, Grid, Axis: TTone;
  end;

const
  LightTones: TThemeTones = (
    Window: $F1F2F5; Panel: $F8F9FB; Surface: $FFFFFF; Border: $DCE0E6;
    Text: $23282E; Muted: $69707C; Icon: $424A55; Accent: $2F6FEB;
    Grid: $E8EBF0; Axis: $8C949F);

  DarkTones: TThemeTones = (
    Window: $181A1D; Panel: $202327; Surface: $141618; Border: $32363C;
    Text: $E0E4EA; Muted: $858D99; Icon: $C0C6CE; Accent: $4F93F0;
    Grid: $282C31; Axis: $747C87);

  LightCurves: array[0..9] of TTone = ($2F6FEB, $D6453C, $12A594, $C2701C,
    $8E4EC6, $D6409F, $3A8C3A, $0891B2, $9A6B00, $475569);

  DarkCurves: array[0..9] of TTone = ($6BA6FF, $FF8A80, $4FD1C5, $F0A868,
    $C79BF0, $F587C8, $86D986, $5FD0E8, $E8C46B, $A8B4C4);

var
  Current: TThemeColors;
  Started: Boolean = False;

function Mix(const A, B: TColor; const Factor: Byte): TColor;

  function Part(const X, Y: Byte): Byte;
  begin
    Result := (X * (255 - Factor) + Y * Factor) div 255;
  end;

var
  First, Second: TColor;
begin
  First := ColorToRGB(A);
  Second := ColorToRGB(B);
  Result := TColor(RGB(Part(GetRValue(First), GetRValue(Second)), Part(GetGValue(First), GetGValue(Second)),
    Part(GetBValue(First), GetBValue(Second))));
end;

function Tone(const Value: TTone): TColor;
begin
  Result := TColor(((Value and $FF) shl 16) or (Value and $00FF00) or ((Value shr 16) and $FF));
end;

function ThemeColors(const Kind: TThemeKind): TThemeColors;
var
  Tones: TThemeTones;
begin
  if Kind = tkDark then Tones := DarkTones
  else
    Tones := LightTones;
  Result.Window := Tone(Tones.Window);
  Result.Panel := Tone(Tones.Panel);
  Result.Surface := Tone(Tones.Surface);
  Result.Border := Tone(Tones.Border);
  Result.Text := Tone(Tones.Text);
  Result.Muted := Tone(Tones.Muted);
  Result.Icon := Tone(Tones.Icon);
  Result.Accent := Tone(Tones.Accent);
  Result.Grid := Tone(Tones.Grid);
  Result.Axis := Tone(Tones.Axis);
  Result.Marker := Result.Accent;
  Result.Trace := Result.Accent;
end;

function CurrentColors: TThemeColors;
begin
  if not Started then Current := ThemeColors(tkLight);
  Result := Current;
end;

function ThemePalette(const Kind: TThemeKind): TColorArray;
var
  I: Integer;
begin
  SetLength(Result, Length(LightCurves));
  for I := Low(Result) to High(Result) do
    if Kind = tkDark then Result[I] := Tone(DarkCurves[I])
    else
      Result[I] := Tone(LightCurves[I]);
end;

type
  TGroupAccess = class(TWinControl);

  TBarRow = record
    Bar: TToolBar;
    Rows: Integer;
    Left: Integer;
    Width: Integer;
  end;

  TGroupPainter = class(TComponent)
  private
    FBox: TWinControl;
    FNext: TWndMethod;
    FColors: TThemeColors;
    procedure Paint(const DC: HDC);
    procedure Handle(var Message: TMessage);
  public
    constructor Create(const Box: TWinControl); reintroduce;
    destructor Destroy; override;
    property Colors: TThemeColors read FColors write FColors;
  end;

constructor TGroupPainter.Create(const Box: TWinControl);
begin
  inherited Create(Box);
  FBox := Box;
  FNext := Box.WindowProc;
  Box.WindowProc := Handle;
end;

destructor TGroupPainter.Destroy;
begin
  if Assigned(FBox) then FBox.WindowProc := FNext;
  inherited;
end;

procedure TGroupPainter.Paint(const DC: HDC);
const
  Radius = 7;
  Inset = 10;
var
  Canvas: TCanvas;
  Place, Label_: TRect;
  Text: string;
  Height, Width: Integer;
begin
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := DC;
    Place := FBox.ClientRect;
    Canvas.Brush.Color := FColors.Panel;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(Place);
    Canvas.Font.Assign(TGroupBox(FBox).Font);
    Text := Trim(TGroupBox(FBox).Caption);
    while (Text <> '') and (Text[Length(Text)] = ':') do
      SetLength(Text, Length(Text) - 1);
    Height := Canvas.TextHeight('A');
    Canvas.Pen.Color := FColors.Border;
    Canvas.Pen.Width := 1;
    Canvas.Brush.Style := bsClear;
    Canvas.RoundRect(Place.Left, Place.Top + Height div 2, Place.Right, Place.Bottom, Radius, Radius);
    if Text <> '' then
    begin
      Width := Canvas.TextWidth(Text);
    Label_ := TRect.Create(Place.Left + Inset - 3, Place.Top, Place.Left + Inset + Width + 3, Place.Top + Height);
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := FColors.Panel;
      Canvas.FillRect(Label_);
      Canvas.Font.Color := FColors.Muted;
      Canvas.TextOut(Place.Left + Inset, Place.Top, Text);
    end;
  finally
    Canvas.Handle := 0;
    Canvas.Free;
  end;
  TGroupAccess(FBox).PaintControls(DC, nil);
end;

procedure TGroupPainter.Handle(var Message: TMessage);
var
  Info: TPaintStruct;
  DC: HDC;
begin
  case Message.Msg of
    WM_ERASEBKGND: Message.Result := 1;
    WM_PRINTCLIENT: Paint(HDC(Message.WParam));
    WM_PAINT:
      if Message.WParam <> 0 then Paint(HDC(Message.WParam))
      else begin
        DC := BeginPaint(FBox.Handle, Info);
        try
          Paint(DC);
        finally
          EndPaint(FBox.Handle, Info);
        end;
      end;
  else
    FNext(Message);
  end;
end;

procedure SetColorProp(const Target: TObject; const Name: string; const Value: TColor);
begin
  if IsPublishedProp(Target, Name) then SetOrdProp(Target, Name, Value);
end;

procedure SetBoolProp(const Target: TObject; const Name: string; const Value: Boolean);
begin
  if IsPublishedProp(Target, Name) then SetOrdProp(Target, Name, Ord(Value));
end;

procedure SetFontLook(const Target: TObject; const Color: TColor; const Bold: Boolean = False);
var
  Font: TObject;
begin
  if not IsPublishedProp(Target, 'Font') then Exit;
  Font := GetObjectProp(Target, 'Font');
  if not (Font is TFont) then Exit;
  TFont(Font).Name := ThemeFont;
  TFont(Font).Size := ThemeFontSize;
  TFont(Font).Color := Color;
  if Bold then TFont(Font).Style := [fsBold]
  else
    TFont(Font).Style := [];
end;

procedure PaintToolBar(const Bar: TToolBar; const Colors: TThemeColors);
begin
  Bar.Flat := True;
  Bar.EdgeBorders := [];
  Bar.DrawingStyle := Vcl.ComCtrls.dsGradient;
  Bar.GradientStartColor := Colors.Panel;
  Bar.GradientEndColor := Colors.Panel;
  Bar.HotTrackColor := Mix(Colors.Panel, Colors.Accent, 44);
  Bar.GradientDrawingOptions := [gdoHotTrack];
  Bar.ParentColor := False;
  Bar.Color := Colors.Panel;
  SetFontLook(Bar, Colors.Text);
  Bar.Font.Size := ThemeFontSize - 1;
end;

procedure CollectBars(const Parent: TWinControl; var List: TArray<TBarRow>);
var
  I: Integer;
  Control: TControl;
begin
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Control := Parent.Controls[I];
    if Control is TToolBar then
    begin
      TGroupAccess(Control).HandleNeeded;
      SetLength(List, Length(List) + 1);
      List[High(List)].Bar := TToolBar(Control);
      List[High(List)].Rows := TToolBar(Control).RowCount;
      List[High(List)].Left := Control.Left;
      List[High(List)].Width := Control.Width;
    end;
    if Control is TWinControl then CollectBars(TWinControl(Control), List);
  end;
end;

procedure FitBars(const List: TArray<TBarRow>);
var
  I: Integer;
begin
  for I := Low(List) to High(List) do
  begin
    if List[I].Rows <= 0 then Continue;
    if List[I].Bar.RowCount <= List[I].Rows then Continue;
    List[I].Bar.AutoSize := False;
    List[I].Bar.Left := List[I].Left;
    List[I].Bar.Width := List[I].Width;
    while (List[I].Bar.RowCount > List[I].Rows) and (List[I].Bar.Font.Size > MinimumFontSize) do
      List[I].Bar.Font.Size := List[I].Bar.Font.Size - 1;
  end;
end;

procedure PaintGrid(const Grid: TCustomGrid; const Colors: TThemeColors);
begin
  SetColorProp(Grid, 'Color', Colors.Surface);
  SetColorProp(Grid, 'FixedColor', Colors.Panel);
  SetColorProp(Grid, 'GradientStartColor', Colors.Panel);
  SetColorProp(Grid, 'GradientEndColor', Colors.Panel);
  SetFontLook(Grid, Colors.Text);
end;

procedure SkinGroup(const Box: TWinControl; const Colors: TThemeColors);
var
  I: Integer;
begin
  for I := 0 to Box.ComponentCount - 1 do
    if Box.Components[I] is TGroupPainter then
    begin
      TGroupPainter(Box.Components[I]).Colors := Colors;
      Box.Invalidate;
      Exit;
    end;
  TGroupPainter.Create(Box).Colors := Colors;
  Box.Invalidate;
end;

procedure PaintControl(const Control: TControl; const Colors: TThemeColors);
begin
  if Control is TToolBar then
  begin
    PaintToolBar(TToolBar(Control), Colors);
    Exit;
  end;
  if Control is TCustomGrid then
  begin
    PaintGrid(TCustomGrid(Control), Colors);
    Exit;
  end;
  if Control is TTrackBar then
  begin
    TTrackBar(Control).TickStyle := tsNone;
    Exit;
  end;
  if (Control is TCustomEdit) or (Control is TCustomComboBox) or (Control is TCustomListBox) then
  begin
    SetColorProp(Control, 'Color', Colors.Surface);
    SetFontLook(Control, Colors.Text);
    Exit;
  end;
  if Control is TCustomGroupBox then
  begin
    SetBoolProp(Control, 'ParentBackground', False);
    SetColorProp(Control, 'Color', Colors.Panel);
    SetFontLook(Control, Colors.Muted);
    SkinGroup(TWinControl(Control), Colors);
    Exit;
  end;
  if Control is TCustomLabel then
  begin
    SetBoolProp(Control, 'Transparent', True);
    SetFontLook(Control, Colors.Muted);
    Exit;
  end;
  if Control is TCustomPanel then
  begin
    SetBoolProp(Control, 'ParentBackground', False);
    SetColorProp(Control, 'Color', Colors.Panel);
    SetFontLook(Control, Colors.Muted);
    Exit;
  end;
  if Control is TCustomTabControl then
  begin
    SetColorProp(Control, 'Color', Colors.Window);
    SetFontLook(Control, Colors.Text);
    Exit;
  end;
  SetColorProp(Control, 'Color', Colors.Window);
  SetFontLook(Control, Colors.Text);
end;

procedure SkinButton(const Button: TControl);
var
  Colors: TThemeColors;
begin
  Colors := CurrentColors;
  SetBoolProp(Button, 'Flat', True);
  SetFontLook(Button, Colors.Text);
end;

procedure PaintTree(const Parent: TWinControl; const Colors: TThemeColors);
var
  I: Integer;
begin
  for I := 0 to Parent.ControlCount - 1 do
  begin
    PaintControl(Parent.Controls[I], Colors);
    if Parent.Controls[I] is TWinControl then
      PaintTree(TWinControl(Parent.Controls[I]), Colors);
  end;
end;

function GlyphSize(const Form: TCustomForm): Integer;
var
  Dpi: Integer;
begin
  Dpi := Form.PixelsPerInch;
  if Dpi < 96 then Dpi := 96;
  Result := MulDiv(16, Dpi, 96);
end;

procedure PaintGraph(const Graph: TGraph; const Colors: TThemeColors; const Kind: TThemeKind);
begin
  Graph.Color := Colors.Surface;
  Graph.GridPen.Color := Colors.Grid;
  Graph.AxisPen.Color := Colors.Axis;
  Graph.PolarAxisPen.Color := Colors.Grid;
  Graph.AxisFont.Name := ThemeFont;
  Graph.AxisFont.Size := ThemeFontSize - 1;
  Graph.AxisFont.Color := Colors.Muted;
  Graph.MarkerPen.Color := Colors.Marker;
  Graph.TracePen.Color := Colors.Trace;
  Graph.TextBackground := Colors.Panel;
  Graph.TextFont.Name := ThemeFont;
  Graph.TextFont.Size := ThemeFontSize;
  Graph.TextFont.Color := Colors.Text;
  Graph.SignFont.Name := ThemeFont;
  Graph.SignFont.Size := ThemeFontSize;
  Graph.SignFont.Color := Colors.Surface;
  Graph.FormulaFont.Name := ThemeFont;
  Graph.FormulaFont.Size := ThemeFontSize;
  Graph.FormulaFont.Color := Colors.Muted;
  Graph.SignBlendValue := 235;
  Graph.ColorArray := ThemePalette(Kind);
  Graph.Invalidate;
end;

procedure ApplyTheme(const Form: TCustomForm; const Graph: TGraph; const Kind: TThemeKind);
var
  I: Integer;
  Colors: TThemeColors;
  Bars: TArray<TBarRow>;
begin
  if not Assigned(Form) then Exit;
  Colors := ThemeColors(Kind);
  Current := Colors;
  Started := True;
  Bars := nil;
  CollectBars(Form, Bars);
  Form.Color := Colors.Window;
  Form.Font.Name := ThemeFont;
  Form.Font.Size := ThemeFontSize;
  Form.Font.Color := Colors.Text;
  PaintTree(Form, Colors);
  for I := 0 to Form.ComponentCount - 1 do
    if Form.Components[I] is TCustomImageList then
      Glyphs.BuildGlyphs(TCustomImageList(Form.Components[I]), Kind, GlyphSize(Form));
  if Assigned(Graph) then PaintGraph(Graph, Colors, Kind);
  FitBars(Bars);
  Form.Invalidate;
end;

end.
