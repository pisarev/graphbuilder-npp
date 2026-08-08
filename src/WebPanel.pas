{ ************************************************************************** }
{                                                                            }
{ WebPanel                                                                   }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit WebPanel;

{$B-}

interface

uses
  Winapi.Windows, Winapi.WebView2, System.Classes, System.SysUtils, System.JSON,
  System.Generics.Collections, System.Types, System.Math, Vcl.Controls, Vcl.Forms,
  Vcl.ExtCtrls, Vcl.Edge, Vcl.Graphics, CrossGraph, CrossGraph.Types, CrossGraph.Engine,
  CrossVision.Geometry.Types, DarkTheme;

type
  TBookmarkEvent = function(const Slot: Integer; const Mode: string): string of object;

  TEditorEvent = procedure(const NewDocument: Boolean) of object;
  TReportEvent = function: string of object;

  TWebPanel = class(TComponent)
  private
    FOnBookmark: TBookmarkEvent;
    FOnReport: TReportEvent;
    FOnToEditor: TEditorEvent;
    FBrowser: TEdgeBrowser;
    FGraph: TGraph;
    FHost: TWinControl;
    FTimer: TTimer;
    FKind: TThemeKind;
    FReady: Boolean;
    FStart: Cardinal;
    FAlign: TAlign;
    FPoints: Integer;
    FRetry: Boolean;
    FNextOverlap: TNotifyEvent;
    FNextExtreme: TNotifyEvent;
    FKeepRatio: Boolean;
    FPenColor: string;
    function Decimals: Integer;
    procedure SetDecimals(const Value: Integer);
    procedure WebCreated(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure WebMessage(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
    procedure Tick(Sender: TObject);
    procedure GraphOverlap(Sender: TObject);
    procedure GraphExtreme(Sender: TObject);
    procedure Apply(const Root: TJSONObject);
    procedure Rebuild;
    function BookmarkSlot(const Slot: Integer; const Mode: string): string;
  protected
    function Curves: string;
    function Overlaps: string;
    function Extremes: string;
    function Trace(const Param: Extended): string;
    function Snapshot: string;
    function ReportPage: string;
    function CountPoints(const Answer: string): Integer;
  public
    constructor Create(const Host: TWinControl; const Graph: TGraph); reintroduce;
    destructor Destroy; override;
    function Start(const Kind: TThemeKind): Boolean;
    procedure Reload(const Kind: TThemeKind);
    function Command(const Text: string): string;
    procedure Post(const Text: string);
    procedure RefreshFromGraph;
    function Bookmarks: string;
    property Browser: TEdgeBrowser read FBrowser;
    property Ready: Boolean read FReady;
    property KeepRatio: Boolean read FKeepRatio write FKeepRatio;
    property PenColor: string read FPenColor write FPenColor;
    property OnBookmark: TBookmarkEvent read FOnBookmark write FOnBookmark;
    property OnReport: TReportEvent read FOnReport write FOnReport;
    procedure Suggest(const Text: string);
    property OnToEditor: TEditorEvent read FOnToEditor write FOnToEditor;
  end;

function UiFile: string;

implementation

uses Vcl.ActnList, ReportFacts;

const
  DoneCheck = 40;
  Digits = 5;
  DefaultKeepRatio = True;
  DefaultPenColor = '--c1';
  BookmarkCount = 10;

function FindAction(const Host: TWinControl; const Name: string): TCustomAction;
var
  Component: TComponent;
begin
  Result := nil;
  if not Assigned(Host) then Exit;
  Component := Host.FindComponent(Name);
  if Component is TCustomAction then Result := TCustomAction(Component);
end;

function UiFile: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  GetModuleFileName(HInstance, Buffer, Length(Buffer));
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Buffer)) + 'ui\index.html';
end;

function Number(const Value: Extended): string;
begin
  Result := FloatToStrF(Value, ffGeneral, 15, Digits, TFormatSettings.Invariant);
end;

function Web(const Color: TColor): string;
var
  Value: TColor;
begin
  Value := ColorToRGB(Color);
  Result := Format('#%.2x%.2x%.2x', [GetRValue(Value), GetGValue(Value), GetBValue(Value)]);
end;

function Escape(const Text: string): string;
begin
  Result := StringReplace(Text, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

constructor TWebPanel.Create(const Host: TWinControl; const Graph: TGraph);
begin
  inherited Create(Host);
  FHost := Host;
  FGraph := Graph;
  FKind := tkLight;
  FKeepRatio := DefaultKeepRatio;
  FPenColor := DefaultPenColor;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := DoneCheck;
  FTimer.OnTimer := Tick;
end;

destructor TWebPanel.Destroy;
begin
  if Assigned(FGraph) then
  begin
    FGraph.OnOverlap := FNextOverlap;
    FGraph.OnExtreme := FNextExtreme;
  end;
  inherited;
end;

function TWebPanel.Start(const Kind: TThemeKind): Boolean;
begin
  FKind := Kind;
  if not FileExists(UiFile) then Exit(False);
  if not Assigned(FBrowser) then
  begin
    FBrowser := TEdgeBrowser.Create(Self);
    FBrowser.Parent := FHost;
    FBrowser.Align := alClient;
    FBrowser.UserDataFolder := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
      'GraphBuilder\WebView';
    FBrowser.OnCreateWebViewCompleted := WebCreated;
    FBrowser.OnWebMessageReceived := WebMessage;
  end;
  FAlign := FGraph.Align;
  FGraph.Align := alNone;
  FBrowser.BringToFront;
  try
    FBrowser.CreateWebView;
  except
    Exit(False);
  end;
  Result := True;
end;

procedure TWebPanel.WebCreated(Sender: TCustomEdgeBrowser; AResult: HRESULT);
begin
  if AResult <> S_OK then
  begin
    FBrowser.Visible := False;
    FGraph.Silent := False;
    FGraph.Align := FAlign;
    Exit;
  end;
  FReady := True;
  FGraph.Silent := True;
  FNextOverlap := FGraph.OnOverlap;
  FNextExtreme := FGraph.OnExtreme;
  FGraph.OnOverlap := GraphOverlap;
  FGraph.OnExtreme := GraphExtreme;
  Reload(FKind);
end;

procedure TWebPanel.Reload(const Kind: TThemeKind);
const
  Suffix: array[TThemeKind] of string = ('light', 'dark');
var
  Stamp: TDateTime;
begin
  FKind := Kind;
  if not FReady then Exit;
  if not FileAge(UiFile, Stamp) then Stamp := 0;
  FBrowser.Navigate('file:///' + StringReplace(UiFile, '\', '/',
    [rfReplaceAll]) + '?theme=' + Suffix[Kind] + '&v=' + IntToStr(Round(Stamp * SecsPerDay)));
end;

procedure TWebPanel.Post(const Text: string);
begin
  if FReady and Assigned(FBrowser.DefaultInterface) then
    FBrowser.DefaultInterface.PostWebMessageAsString(PWideChar(Text));
end;

procedure TWebPanel.Suggest(const Text: string);
var
  Root: TJSONObject;
begin
  if Trim(Text) = '' then Exit;
  Root := TJSONObject.Create;
  try
    Root.AddPair('type', 'suggest');
    Root.AddPair('text', Text);
    Post(Root.ToJSON);
  finally
    Root.Free;
  end;
end;

procedure TWebPanel.WebMessage(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
var
  Value: PWideChar;
  Answer: string;
begin
  Value := nil;
  if Args.ArgsInterface.TryGetWebMessageAsString(Value) <> S_OK then Exit;
  try
    Answer := Command(Value);
  except
    Answer := '';
  end;
  if Answer <> '' then Post(Answer);
end;

procedure TWebPanel.Tick(Sender: TObject);
var
  Ready: string;
begin
  if FGraph.Busy then Exit;
  FTimer.Enabled := False;
  Ready := Curves;
  if (FPoints = 0) and (FGraph.Formula.ActiveCount > 0) and not FRetry then
  begin
    FRetry := True;
    Rebuild;
    Exit;
  end;
  Post(Ready);
end;

procedure TWebPanel.GraphOverlap(Sender: TObject);
begin
  if Assigned(FNextOverlap) then FNextOverlap(Sender);
  Post(Overlaps);
end;

procedure TWebPanel.GraphExtreme(Sender: TObject);
begin
  if Assigned(FNextExtreme) then FNextExtreme(Sender);
  Post(Extremes);
end;

function TWebPanel.Curves: string;
const
  MaxSegmentPoints = 6000;
var
  Text: TStringBuilder;
  Entire: TCurveDArray;
  I, J, K, L, M, Count, Seg, Stride: Integer;
  Data: PFormulaData;
  First, FirstPart, HasPix, Emit: Boolean;
  Pix, Prev: TPoint;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"curves","ms":').Append(GetTickCount - FStart);
    Text.Append(',"error":"').Append(Escape(FGraph.ErrorMessage)).Append('"');
    Text.Append(',"list":[');
    Count := 0;
    Entire := FGraph.EntireArray;
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      Data := FGraph.Formula.Data[I];
      if not Assigned(Data) then Continue;
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"i":').Append(I);
      Text.Append(',"color":"').Append(Web(TColor(Data.Color))).Append('"');
      Text.Append(',"on":').Append(LowerCase(BoolToStr(FGraph.Formula.Active[I], True)));
      Text.Append(',"seg":[');
      FirstPart := True;
      if Check(Entire, Data.EntireBack) and Check(Entire, Data.EntireFace) then
        for J := Data.EntireBack.ArrayIndex to Data.EntireFace.ArrayIndex do
          if GetRange(Entire, Data.EntireBack, Data.EntireFace, J, L, M) then
          begin
            if not FirstPart then Text.Append(',');
            FirstPart := False;
            Text.Append('[');
            Seg := M - L + 1;
            Stride := (Seg + MaxSegmentPoints - 1) div MaxSegmentPoints;
            if Stride < 1 then Stride := 1;
            Prev := Default(TPoint);
            HasPix := False;
            Emit := False;
            K := L;
            while K <= M do
            begin
              Pix := PointI(FGraph.PointToCursor(Entire[J][K]));
              if not (HasPix and (Pix.X = Prev.X) and (Pix.Y = Prev.Y)) then
              begin
                Prev := Pix;
                HasPix := True;
                if Emit then Text.Append(',');
                Emit := True;
                Text.Append(Number(Entire[J][K].X)).Append(',').Append(Number(Entire[J][K].Y));
                Inc(Count);
              end;
              if K >= M then Break;
              Inc(K, Stride);
              if K > M then K := M;
            end;
            Text.Append(']');
          end;
      Text.Append(']}');
    end;
    Text.Append('],"points":').Append(Count).Append('}');
    FPoints := Count;
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.CountPoints(const Answer: string): Integer;
var
  Root: TJSONObject;
begin
  Result := 0;
  Root := TJSONObject.ParseJSONValue(Answer) as TJSONObject;
  if not Assigned(Root) then Exit;
  try
    Result := Root.GetValue<Integer>('points', 0);
  finally
    Root.Free;
  end;
end;

function TWebPanel.Overlaps: string;
var
  Text: TStringBuilder;
  List: TOverlapArray;
  I: Integer;
begin
  List := FGraph.OverlapArray;
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"overlaps","list":[');
    for I := Low(List) to High(List) do
    begin
      if I > Low(List) then Text.Append(',');
      Text.Append('{"x":').Append(Number(List[I].Point.X));
      Text.Append(',"y":').Append(Number(List[I].Point.Y));
      Text.Append(',"name":"').Append(Escape(FGraph.OverlapName[I])).Append('"}');
    end;
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.Extremes: string;

  procedure Add(const Text: TStringBuilder; const List: TCurveDArray);
  var
    I, J: Integer;
    First: Boolean;
  begin
    First := True;
    for I := Low(List) to High(List) do
      for J := Low(List[I]) to High(List[I]) do
      begin
        if not First then Text.Append(',');
        First := False;
        Text.Append('[').Append(Number(List[I][J].X)).Append(',');
        Text.Append(Number(List[I][J].Y)).Append(']');
      end;
  end;

var
  Text: TStringBuilder;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"extremes","max":[');
    Add(Text, FGraph.MaxArray);
    Text.Append('],"min":[');
    Add(Text, FGraph.MinArray);
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.Trace(const Param: Extended): string;
var
  Text: TStringBuilder;
  I: Integer;
  Data: PFormulaData;
  Point: TPointD;
  Polar: Boolean;
  First: Boolean;
begin
  Polar := FGraph.CS = csPolar;
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"trace","polar":').Append(LowerCase(BoolToStr(Polar, True)));
    Text.Append(',"param":').Append(Number(Param)).Append(',"list":[');
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      Data := FGraph.Formula.Data[I];
      if not Assigned(Data) or not FGraph.Formula.Active[I] then Continue;
      if not FGraph.Formula.Tracing[I] then Continue;
      if not CrossGraph.Engine.Check(FGraph.SA, Data.ScriptIndex) then Continue;
      if Polar then
        Point := FGraph.ComputePolar(Param, FGraph.SA[Data.ScriptIndex])
      else
        Point := FGraph.ComputeRectangular(Param, FGraph.SA[Data.ScriptIndex]);
      if IsNan(Point.X) or IsNan(Point.Y) or IsInfinite(Point.Y) then Continue;
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"i":').Append(I);
      Text.Append(',"x":').Append(Number(Point.X));
      Text.Append(',"y":').Append(Number(Point.Y)).Append('}');
    end;
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.Decimals: Integer;
begin
  Result := Pos('.', FGraph.PrecisionFormat);
  if Result > 0 then Result := Length(FGraph.PrecisionFormat) - Result;
end;

procedure TWebPanel.SetDecimals(const Value: Integer);
begin
  if Value > 0 then
    FGraph.PrecisionFormat := '0.' + StringOfChar('#', Value)
  else
    FGraph.PrecisionFormat := '0';
end;

procedure TWebPanel.Apply(const Root: TJSONObject);

  function Num(const Name: string; const Default: Extended): Extended;
  var
    Value: TJSONValue;
  begin
    Value := Root.Values[Name];
    if Assigned(Value) then
      Result := Value.AsType<Double>
        else
      Result := Default;
  end;

  function Flag(const Name: string; const Default: Boolean): Boolean;
  var
    Value: TJSONValue;
  begin
    Value := Root.Values[Name];
    if Assigned(Value) then
      Result := Value.AsType<Boolean>
        else
      Result := Default;
  end;

  function Str(const Name, Default: string): string;
  var
    Value: TJSONValue;
  begin
    Value := Root.Values[Name];
    if Assigned(Value) then
      Result := Value.Value
    else
      Result := Default;
  end;

begin
  FGraph.MaxX := Num('maxX', FGraph.MaxX);
  FGraph.MaxY := Num('maxY', FGraph.MaxY);
  FGraph.Offset := PointD(-Num('centerX', -FGraph.Offset.X), -Num('centerY', -FGraph.Offset.Y));
  FGraph.ShowGrid := Flag('grid', FGraph.ShowGrid);
  FGraph.ShowAxis := Flag('axis', FGraph.ShowAxis);
  FGraph.Tracing := Flag('trace', FGraph.Tracing);
  FGraph.Overlap := Flag('cross', FGraph.Overlap);
  FGraph.Extreme := Flag('peak', FGraph.Extreme);
  FGraph.Sign := Flag('sign', FGraph.Sign);
  FGraph.Antialias := Flag('smooth', FGraph.Antialias);
  FGraph.MultiColor := Flag('multicolor', FGraph.MultiColor);
  FGraph.Autoquality := Flag('autoquality', FGraph.Autoquality);
  FGraph.HighPrecision := Flag('precise', FGraph.HighPrecision);
  FGraph.Quality := Round(Num('quality', FGraph.Quality));
  FGraph.Accuracy := Round(Num('accuracy', FGraph.Accuracy));
  FGraph.GraphPen.Width := Round(Num('penWidth', FGraph.GraphPen.Width));
  FGraph.HSpacing := Num('hSpacing', FGraph.HSpacing);
  FGraph.VSpacing := Num('vSpacing', FGraph.VSpacing);
  FGraph.PolarMaxAngle := DegToRad(Num('polarAngle', RadToDeg(FGraph.PolarMaxAngle)));
  FGraph.OverlapMaxTime := Round(Num('overlapTime', FGraph.OverlapMaxTime));
  FGraph.OverlapMaxDepth := Round(Num('overlapDepth', FGraph.OverlapMaxDepth));
  FGraph.ThreadWorkTime := Round(Num('calcTime', FGraph.ThreadWorkTime));
  FGraph.ZoomInFactor := Num('zoomIn', FGraph.ZoomInFactor);
  FGraph.ZoomOutFactor := Num('zoomOut', FGraph.ZoomOutFactor);
  FGraph.MarkSpacing := Round(Num('markSpacing', FGraph.MarkSpacing));
  SetDecimals(Round(Num('decimals', Decimals)));
  FKeepRatio := Flag('keepRatio', FKeepRatio);
  FPenColor := Str('penColor', FPenColor);
  FGraph.SignLayout := TLayoutType(EnsureRange(Round(Num('signLayout', Ord(FGraph.SignLayout))), 0, 3));
  FGraph.SignMargin := Round(Num('signMargin', FGraph.SignMargin));
  FGraph.SignBlendValue := EnsureRange(Round(Num('signBlend', FGraph.SignBlendValue)), 0, 255);
end;

procedure TWebPanel.Rebuild;
begin
  FStart := GetTickCount;
  FGraph.Build;
  Post(Curves);
  FTimer.Enabled := True;
end;

function TWebPanel.Snapshot: string;
var
  Text: TStringBuilder;
  I: Integer;
  First: Boolean;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"snapshot"');
    if FGraph.CS = csPolar then
      Text.Append(',"cs":"polar"')
    else
      Text.Append(',"cs":"rect"');
    Text.Append(',"formulas":[');
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"text":"').Append(Escape(FGraph.Formula[I])).Append('"');
      Text.Append(',"on":').Append(LowerCase(BoolToStr(FGraph.Formula.Active[I], True)));
      Text.Append(',"trace":').Append(LowerCase(BoolToStr(FGraph.Formula.Tracing[I], True)));
      Text.Append('}');
    end;
    Text.Append('],"options":{');
    Text.Append('"maxX":').Append(Number(FGraph.MaxX));
    Text.Append(',"maxY":').Append(Number(FGraph.MaxY));
    Text.Append(',"centerX":').Append(Number(-FGraph.Offset.X));
    Text.Append(',"centerY":').Append(Number(-FGraph.Offset.Y));
    Text.Append(',"grid":').Append(LowerCase(BoolToStr(FGraph.ShowGrid, True)));
    Text.Append(',"axis":').Append(LowerCase(BoolToStr(FGraph.ShowAxis, True)));
    Text.Append(',"trace":').Append(LowerCase(BoolToStr(FGraph.Tracing, True)));
    Text.Append(',"cross":').Append(LowerCase(BoolToStr(FGraph.Overlap, True)));
    Text.Append(',"peak":').Append(LowerCase(BoolToStr(FGraph.Extreme, True)));
    Text.Append(',"sign":').Append(LowerCase(BoolToStr(FGraph.Sign, True)));
    Text.Append(',"smooth":').Append(LowerCase(BoolToStr(FGraph.Antialias, True)));
    Text.Append(',"multicolor":').Append(LowerCase(BoolToStr(FGraph.MultiColor, True)));
    Text.Append(',"autoquality":').Append(LowerCase(BoolToStr(FGraph.Autoquality, True)));
    Text.Append(',"precise":').Append(LowerCase(BoolToStr(FGraph.HighPrecision, True)));
    Text.Append(',"quality":').Append(FGraph.Quality);
    Text.Append(',"accuracy":').Append(FGraph.Accuracy);
    Text.Append(',"penWidth":').Append(FGraph.GraphPen.Width);
    Text.Append(',"hSpacing":').Append(Number(FGraph.HSpacing));
    Text.Append(',"vSpacing":').Append(Number(FGraph.VSpacing));
    Text.Append(',"polarAngle":').Append(Number(RadToDeg(FGraph.PolarMaxAngle)));
    Text.Append(',"calcTime":').Append(FGraph.ThreadWorkTime);
    Text.Append(',"overlapTime":').Append(FGraph.OverlapMaxTime);
    Text.Append(',"overlapDepth":').Append(FGraph.OverlapMaxDepth);
    Text.Append(',"zoomIn":').Append(Number(FGraph.ZoomInFactor));
    Text.Append(',"zoomOut":').Append(Number(FGraph.ZoomOutFactor));
    Text.Append(',"markSpacing":').Append(FGraph.MarkSpacing);
    Text.Append(',"decimals":').Append(Decimals);
    Text.Append(',"keepRatio":').Append(LowerCase(BoolToStr(FKeepRatio, True)));
    Text.Append(',"penColor":"').Append(FPenColor).Append('"');
    Text.Append(',"signLayout":').Append(Ord(FGraph.SignLayout));
    Text.Append(',"signMargin":').Append(FGraph.SignMargin);
    Text.Append(',"signBlend":').Append(FGraph.SignBlendValue);
    Text.Append('}}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.BookmarkSlot(const Slot: Integer; const Mode: string): string;
begin
  if Assigned(FOnBookmark) then
    Result := FOnBookmark(Slot, Mode)
  else
    Result := Bookmarks;
end;

procedure TWebPanel.RefreshFromGraph;
begin
  Post(Snapshot);
end;

function TWebPanel.Bookmarks: string;
var
  Text: TStringBuilder;
  I: Integer;
  Slot: TCustomAction;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"bookmarks","slots":[');
    for I := 0 to BookmarkCount - 1 do
    begin
      if I > 0 then Text.Append(',');
      Slot := FindAction(FHost, 'B' + IntToStr(I));
      Text.Append(LowerCase(BoolToStr(Assigned(Slot) and Slot.Checked, True)));
    end;
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TWebPanel.ReportPage: string;
var
  Html: string;
  Root: TJSONObject;
begin
  if Assigned(FOnReport) then
    Html := FOnReport
  else
    Html := ReportFacts.Extend('<html><head></head><body></body></html>', FGraph, FKind = tkDark);
  Root := TJSONObject.Create;
  try
    Root.AddPair('type', 'report');
    Root.AddPair('html', Html);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function TWebPanel.Command(const Text: string): string;
var
  Root: TJSONObject;
  Value: TJSONValue;
  List: TJSONArray;
  Item: TJSONObject;
  I, Width, Height: Integer;
  Formula: string;
begin
  Result := '';
  Root := TJSONObject.ParseJSONValue(Text) as TJSONObject;
  if not Assigned(Root) then Exit;
  try
    Value := Root.Values['cmd'];
    if not Assigned(Value) then Exit;
    if Value.Value = 'size' then
    begin
      Width := Root.GetValue<Integer>('w', FGraph.Width);
      Height := Root.GetValue<Integer>('h', FGraph.Height);
      FGraph.Align := alNone;
      if (Width > 0) and (Height > 0) then FGraph.SetBounds(0, 0, Width, Height);
      Exit;
    end;
    if Value.Value = 'build' then
    begin
      FRetry := False;
      FGraph.CS := TCoordinateSystem(Ord(Root.GetValue<string>('cs', 'rect') = 'polar'));
      List := Root.Values['formulas'] as TJSONArray;
      if Assigned(List) then
      begin
        FGraph.Formula.Clear;
        for I := 0 to List.Count - 1 do
        begin
          Item := List.Items[I] as TJSONObject;
          Formula := Item.GetValue<string>('text', '');
          if Trim(Formula) = '' then Continue;
          FGraph.Formula.Add(Formula, Item.GetValue<Boolean>('on', True), True, Item.GetValue<Boolean>('trace', True));
        end;
      end;
      Item := Root.Values['options'] as TJSONObject;
      if Assigned(Item) then Apply(Item);
      Rebuild;
      Exit('{"type":"busy"}');
    end;
    if Value.Value = 'options' then
    begin
      FRetry := False;
      Item := Root.Values['options'] as TJSONObject;
      if Assigned(Item) then Apply(Item);
      Rebuild;
      Exit('{"type":"busy"}');
    end;
    if Value.Value = 'trace' then
      Exit(Trace(Root.GetValue<Double>('param', 0)));
    if Value.Value = 'bookmark' then
    begin
      Result := BookmarkSlot(Root.GetValue<Integer>('slot', 0), Root.GetValue<string>('mode', 'status'));
      Exit;
    end;
    if Value.Value = 'copy' then
    begin
      if Assigned(FindAction(FHost, 'GCopy')) then FindAction(FHost, 'GCopy').Execute;
      Exit;
    end;
    if Value.Value = 'paste' then
    begin
      if Assigned(FindAction(FHost, 'GPaste')) then FindAction(FHost, 'GPaste').Execute;
      Post(Snapshot);
      Exit;
    end;
    if Value.Value = 'signfont' then
    begin
      if Assigned(FindAction(FHost, 'GSignFont')) then FindAction(FHost, 'GSignFont').Execute;
      Rebuild;
      Exit('{"type":"busy"}');
    end;
    if Value.Value = 'report' then
      Exit(ReportPage);
    if Value.Value = 'toeditor' then
    begin
      if Assigned(FOnToEditor) then
        FOnToEditor(Root.GetValue<string>('where', 'new') <> 'here');
      Exit;
    end;
    if Value.Value = 'ready' then
      Exit('{"type":"hello","engine":"crossgraph","editor":true,"budgets":true}');
  finally
    Root.Free;
  end;
end;

end.
