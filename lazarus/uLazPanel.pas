{ ************************************************************************** }
{                                                                            }
{ uLazPanel                                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit uLazPanel;

{$MODE Delphi}

interface

uses
  Windows, Messages, SysUtils, Classes, Math, Controls, Forms, ExtCtrls, Graphics,
  Clipbrd, Dialogs, base64, fpjson, jsonparser,
  uWVBrowser, uWVWinControl, uWVWindowParent, uWVTypes,
  uWVTypeLibrary, uWVBrowserBase, uWVLoader, uWVCoreWebView2Args,
  NotepadPP.Plugin, NotepadPP.Docking, uLazTrace,
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine, CrossGraph,
  ReportFacts;

type
  TLazPanel = class(TNppDockingForm)
  private
    FHost: TWVWindowParent;
    FBrowser: TWVBrowser;
    FWait: TTimer;
    FDone: TTimer;
    FGraph: TGraph;
    FStart: Cardinal;
    FPage: string;
    FStarted: Boolean;
    FDark: Boolean;
    FState: string;
    FPoints: Integer;
    FRetry: Boolean;
    FInside: Boolean;

    FKeepRatio: Boolean;
    FPenColor: string;
    function Decimals: Integer;
    procedure SetDecimals(const Value: Integer);
    procedure Shown(Sender: TObject);
    procedure Poll(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Created(Sender: TObject);
    procedure Failed(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure Incoming(Sender: TObject; const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure GraphOverlap(Sender: TObject);
    procedure GraphExtreme(Sender: TObject);
    procedure Answer(const Text: string);
    procedure Rebuild;
    procedure Apply(const Options: TJSONObject);
    function Command(const Text: string): string;
    function Curves: string;
    function Overlaps: string;
    function Extremes: string;
    function Trace(const Param: Extended): string;
    function Snapshot: string;
    function BookmarkSlot(const Slot: Integer; const Mode: string): string;
    function Bookmarks: string;
    function ReportPage: string;
    function SignFont: string;
    function StateDir: string;
    function SlotFile(const Slot: Integer): string;
    function SessionFile: string;
    function Stored: string;
    procedure ApplyNative(const Root: TJSONObject);
    procedure SaveSession;
    function LoadSession: Boolean;
    procedure LoadState(const Text: string);
    procedure WMMove(var aMessage: TWMMove); message WM_MOVE;
    procedure WMSize(var aMessage: TWMSize); message WM_SIZE;
  public
    constructor Create(NppParent: TNppPlugin; DlgId: Integer); override;

    procedure SetTheme(const Dark: Boolean);
  end;

var
  Panel: TLazPanel = nil;

implementation

const
  ShareMark = '#s=1.';

function ShareState(const Text: string): string;
var
  Code: string;
  At, I: Integer;
begin
  Result := '';
  At := Pos(ShareMark, Text);
  if At = 0 then Exit;
  Code := Trim(Copy(Text, At + Length(ShareMark), MaxInt));
  for I := 1 to Length(Code) do
    case Code[I] of
      '-': Code[I] := '+';
      '_': Code[I] := '/';
    end;

  while Length(Code) mod 4 <> 0 do Code := Code + '=';
  try
    Result := DecodeStringBase64(Code);
  except
    Result := '';
  end;
end;

const
  MaxSegmentPoints = 6000;
  DoneCheck = 40;

  BusyReply = '{"type":"busy"}';

  DefaultKeepRatio = True;
  DefaultPenColor = '--c1';

var
  Dot: TFormatSettings;

function Num(const Value: Extended): string;
begin
  if IsNan(Value) or IsInfinite(Value) then Exit('0');
  Result := FormatFloat('0.##########', Value, Dot);
end;

function Flag(const Value: Boolean): string;
begin
  if Value then Result := 'true' else Result := 'false';
end;

function Escape(const Text: string): string;
begin
  Result := StringReplace(Text, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

function Web(const Value: TColor): string;
var
  RGB: LongInt;
begin
  RGB := ColorToRGB(Value);
  Result := Format('#%.2x%.2x%.2x', [Byte(RGB), Byte(RGB shr 8), Byte(RGB shr 16)]);
end;

function UiFile: string;
var
  Buffer: array[0..MAX_PATH] of WideChar;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  GetModuleFileNameW(HInstance, @Buffer[0], Length(Buffer));
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(string(PWideChar(@Buffer[0])))) + 'ui\index.html';
end;

constructor TLazPanel.Create(NppParent: TNppPlugin; DlgId: Integer);
begin
  inherited Create(NppParent, DlgId);
  Caption := 'Graph Builder';
  Width := 900;
  Height := 600;
  OnShow := Shown;

  FKeepRatio := DefaultKeepRatio;
  FPenColor := DefaultPenColor;

  FGraph := TGraph.Create(Self);
  FGraph.Parent := Self;
  FGraph.SetBounds(0, 0, ClientWidth, ClientHeight);

  FGraph.HandleNeeded;
  FGraph.Silent := True;
  FGraph.OnOverlap := GraphOverlap;
  FGraph.OnExtreme := GraphExtreme;

  FHost := TWVWindowParent.Create(Self);
  FHost.Parent := Self;
  FHost.Align := alClient;

  FBrowser := TWVBrowser.Create(Self);
  FBrowser.OnAfterCreated := Created;
  FBrowser.OnWebMessageReceived := Incoming;
  FBrowser.OnInitializationError := Failed;

  FHost.Browser := FBrowser;

  FWait := TTimer.Create(Self);
  FWait.Enabled := False;
  FWait.Interval := 200;
  FWait.OnTimer := Poll;

  FDone := TTimer.Create(Self);
  FDone.Enabled := False;
  FDone.Interval := DoneCheck;
  FDone.OnTimer := Tick;

  FDark := Assigned(NppParent) and NppParent.DarkMode;
  FPage := UiFile;
end;

procedure TLazPanel.WMMove(var aMessage: TWMMove);
begin
  inherited;
  if Assigned(FBrowser) then FBrowser.NotifyParentWindowPositionChanged;
end;

procedure TLazPanel.WMSize(var aMessage: TWMSize);
begin
  inherited;
  if Assigned(FHost) then
  begin
    FHost.SetBounds(0, 0, ClientWidth, ClientHeight);
    FHost.UpdateSize;
  end;
  if Assigned(FGraph) then FGraph.SetBounds(0, 0, ClientWidth, ClientHeight);
end;

procedure TLazPanel.Shown(Sender: TObject);
begin
  LogStep(Format('show: created=%s, loader=%s', [BoolToStr(FStarted, True), BoolToStr(Assigned(GlobalWebView2Loader), True)]));
  if FStarted or not Assigned(GlobalWebView2Loader) then Exit;
  if GlobalWebView2Loader.InitializationError then
  begin
    UpdateDisplayInfo('WebView2: ' + GlobalWebView2Loader.ErrorMessage);
    Exit;
  end;
  if GlobalWebView2Loader.Initialized then
  begin
    FStarted := True;
    LogStep('show: creating browser, host handle ' + IntToStr(FHost.Handle));
    FBrowser.CreateBrowser(FHost.Handle);
    LogStep('show: CreateBrowser returned');
  end
  else begin
    LogStep('show: loader not ready, waiting');
    FWait.Enabled := True;
  end;
end;

procedure TLazPanel.Poll(Sender: TObject);
begin
  if not Assigned(GlobalWebView2Loader) or not GlobalWebView2Loader.Initialized then Exit;
  FWait.Enabled := False;
  if FStarted then Exit;
  FStarted := True;
  LogStep('waiting: loader ready, creating browser');
  FBrowser.CreateBrowser(FHost.Handle);
  LogStep('waiting: CreateBrowser returned');
end;

procedure TLazPanel.Created(Sender: TObject);
begin
  LogStep('browser created, loading the page');
  FHost.SetBounds(0, 0, ClientWidth, ClientHeight);
  FHost.UpdateSize;
  if not FileExists(FPage) then
  begin
    UpdateDisplayInfo('the page is missing: ' + FPage);
    Exit;
  end;
  SetTheme(FDark);
end;

procedure TLazPanel.SetTheme(const Dark: Boolean);
const
  Suffix: array[Boolean] of string = ('light', 'dark');
begin
  FDark := Dark;
  if not FStarted or not Assigned(FBrowser) then Exit;
  FBrowser.Navigate('file:///' + StringReplace(FPage, '\', '/',
    [rfReplaceAll]) + '?theme=' + Suffix[Dark] + '&v=' + IntToStr(FileAge(FPage)));
end;

procedure TLazPanel.Failed(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  LogStep('WebView2 ERROR: ' + string(aErrorMessage));
  UpdateDisplayInfo('WebView2: ' + string(aErrorMessage));
end;

procedure TLazPanel.Incoming(Sender: TObject; const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  Args: TCoreWebView2WebMessageReceivedEventArgs;
  Reply: string;
begin
  Args := TCoreWebView2WebMessageReceivedEventArgs.Create(aArgs);
  try

    try
      Reply := Command(Args.WebMessageAsString);
    except
      on E: Exception do
      begin
        LogStep(Format('EXCEPTION while parsing a command: %s: %s, address %p, base %p',
          [E.ClassName, E.Message, ExceptAddr, Pointer(HInstance)]));
        Reply := '';
      end;
    end;
  finally
    Args.Free;
  end;
  if Reply <> '' then Answer(Reply);
end;

procedure TLazPanel.Answer(const Text: string);
begin
  if Assigned(FBrowser) then FBrowser.PostWebMessageAsString(Text);
end;

procedure TLazPanel.GraphOverlap(Sender: TObject);
begin
  Answer(Overlaps);
end;

procedure TLazPanel.GraphExtreme(Sender: TObject);
begin
  Answer(Extremes);
end;

procedure TLazPanel.Rebuild;
begin

  if FInside then
  begin
    LogStep('build re-entered, skipping');
    Exit;
  end;
  FInside := True;
  try
  FStart := GetTickCount;
  FGraph.Build;

  Answer(Curves);
  FDone.Enabled := True;
  finally
    FInside := False;
  end;
end;

procedure TLazPanel.Tick(Sender: TObject);
var
  Ready: string;
begin
  if FInside or FGraph.Busy then Exit;
  FDone.Enabled := False;
  Ready := Curves;

  if (FPoints = 0) and (FGraph.Formula.ActiveCount > 0) and not FRetry then
  begin
    FRetry := True;
    LogStep('the curves came out empty, building again');
    Rebuild;
    Exit;
  end;
  Answer(Ready);
end;

procedure TLazPanel.Apply(const Options: TJSONObject);

  function Num_(const Name: string; const Default: Double): Double;
  begin
    Result := Options.Get(Name, Default);
  end;

  function Flag(const Name: string; const Default: Boolean): Boolean;
  begin
    Result := Options.Get(Name, Default);
  end;

  function Str(const Name, Default: string): string;
  begin
    Result := Options.Get(Name, Default);
  end;
begin
  FGraph.MaxX := Num_('maxX', FGraph.MaxX);
  FGraph.MaxY := Num_('maxY', FGraph.MaxY);

  FGraph.Offset := PointD(-Num_('centerX', -FGraph.Offset.X), -Num_('centerY', -FGraph.Offset.Y));
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
  FGraph.Quality := Round(Num_('quality', FGraph.Quality));
  FGraph.Accuracy := Round(Num_('accuracy', FGraph.Accuracy));
  FGraph.HSpacing := Num_('hSpacing', FGraph.HSpacing);
  FGraph.VSpacing := Num_('vSpacing', FGraph.VSpacing);

  FGraph.PolarMaxAngle := DegToRad(Num_('polarAngle', RadToDeg(FGraph.PolarMaxAngle)));
  FGraph.OverlapMaxTime := Round(Num_('overlapTime', FGraph.OverlapMaxTime));
  FGraph.OverlapMaxDepth := Round(Num_('overlapDepth', FGraph.OverlapMaxDepth));
  FGraph.ThreadWorkTime := Round(Num_('calcTime', FGraph.ThreadWorkTime));
  FGraph.GraphPen.Width := Round(Num_('penWidth', FGraph.GraphPen.Width));
  FGraph.ZoomInFactor := Num_('zoomIn', FGraph.ZoomInFactor);
  FGraph.ZoomOutFactor := Num_('zoomOut', FGraph.ZoomOutFactor);

  FGraph.MarkSpacing := Round(Num_('markSpacing', FGraph.MarkSpacing));

  SetDecimals(Round(Num_('decimals', Decimals)));

  FKeepRatio := Flag('keepRatio', FKeepRatio);
  FPenColor := Str('penColor', FPenColor);

  FGraph.SignLayout := TLayoutType(EnsureRange(Round(Num_('signLayout', Ord(FGraph.SignLayout))), 0, 3));
  FGraph.SignMargin := Round(Num_('signMargin', FGraph.SignMargin));
  FGraph.SignBlendValue := EnsureRange(Round(Num_('signBlend', FGraph.SignBlendValue)), 0, 255);
end;

function TLazPanel.Command(const Text: string): string;
var
  Data: TJSONData;
  Root: TJSONObject;
  List: TJSONArray;
  Item: TJSONObject;
  Cmd, Formula: string;
  I, W, H: Integer;
begin
  Result := '';
  Data := nil;
  try
    try
      Data := GetJSON(Text);
    except
      Exit;
    end;
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    Cmd := Root.Get('cmd', '');
    LogStep('command from the page: ' + Cmd);

    if Cmd = 'size' then
    begin

      W := Root.Get('w', FGraph.Width);
      H := Root.Get('h', FGraph.Height);
      LogStep(Format('size from the page: %dx%d (was %dx%d)', [W, H, FGraph.Width, FGraph.Height]));
      if (W > 0) and (H > 0) then FGraph.SetBounds(0, 0, W, H);
      Exit;
    end;

    if Cmd = 'build' then
    begin
      FRetry := False;

      FState := Text;
      SaveSession;

      if Root.Get('cs', '') = 'polar' then FGraph.CS := csPolar
      else
        FGraph.CS := csRectangular;
      if Root.Find('formulas') is TJSONArray then
      begin
        List := TJSONArray(Root.Find('formulas'));
        FGraph.Formula.Clear;
        for I := 0 to List.Count - 1 do
          if List.Items[I] is TJSONObject then
          begin
            Item := TJSONObject(List.Items[I]);
            Formula := Item.Get('text', '');
            if Trim(Formula) = '' then Continue;
            FGraph.Formula.Add(Formula, Item.Get('on', True), True, Item.Get('trace', True));
          end;
      end;
      if Root.Find('options') is TJSONObject then Apply(TJSONObject(Root.Find('options')));
      Rebuild;
      Exit(BusyReply);
    end;

    if Cmd = 'options' then
    begin
      FRetry := False;
      if Root.Find('options') is TJSONObject then Apply(TJSONObject(Root.Find('options')));
      Rebuild;
      Exit(BusyReply);
    end;

    if Cmd = 'signfont' then Exit(SignFont);

    if Cmd = 'trace' then Exit(Trace(Root.Get('param', Double(0))));
    if Cmd = 'bookmark' then
      Exit(BookmarkSlot(Root.Get('slot', 0), Root.Get('mode', 'status')));
    if Cmd = 'copy' then
    begin

      if Root.Get('text', '') <> '' then Clipboard.AsText := Root.Get('text', '')
      else if FState <> '' then Clipboard.AsText := FState;
      Exit;
    end;
    if Cmd = 'paste' then
    begin

      if ShareState(Clipboard.AsText) <> '' then
        LoadState(ShareState(Clipboard.AsText))
      else
        LoadState(Clipboard.AsText);
      Exit;
    end;
    if Cmd = 'report' then Exit(ReportPage);
    if Cmd = 'ready' then
    begin

      if LoadSession then Exit('');
      Exit('{"type":"hello","engine":"crossgraph-fpc"}');
    end;
  finally
    Data.Free;
  end;
end;

function TLazPanel.Curves: string;
var
  Text: TStringBuilder;
  Entire: TCurveDArray;
  Data: PFormulaData;
  I, J, K, L, M, Count, Seg, Stride: Integer;
  First, FirstPart, HasPix, Emit: Boolean;
  Pix, Prev: TPoint;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"curves","ms":').Append(Integer(GetTickCount - FStart));
    Text.Append(',"error":"').Append(Escape(FGraph.ErrorMessage)).Append('"');
    Text.Append(',"list":[');
    Count := 0;
    Entire := FGraph.EntireArray;
    LogStep(
      Format(
        'curves: plot %dx%d, view X=%s Y=%s centre(%s,%s), quality %d, CS=%d, formulas %d/%d, pieces %d',
        [
          FGraph.Width,
          FGraph.Height,
          Num(FGraph.MaxX),
          Num(FGraph.MaxY),
          Num(-FGraph.Offset.X),
          Num(-FGraph.Offset.Y),
          FGraph.Quality,
          Ord(FGraph.CS),
          FGraph.Formula.ActiveCount,
          FGraph.Formula.Count,
          Length(Entire)
        ]
      )
    );
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      Data := FGraph.Formula.Data[I];
      if not Assigned(Data) then Continue;
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"i":').Append(I);
      Text.Append(',"color":"').Append(Web(TColor(Data.Color))).Append('"');
      if FGraph.Formula.Active[I] then Text.Append(',"on":true')
      else
        Text.Append(',"on":false');
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
                Text.Append(Num(Entire[J][K].X)).Append(',').Append(Num(Entire[J][K].Y));
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
    LogStep(Format('  result: points %d, string length %d, head: %s', [Count, Length(Result), Copy(Result, 1, 220)]));
  finally
    Text.Free;
  end;
end;

function TLazPanel.Overlaps: string;
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
      Text.Append('{"x":').Append(Num(List[I].Point.X));
      Text.Append(',"y":').Append(Num(List[I].Point.Y));
      Text.Append(',"name":"').Append(Escape(FGraph.OverlapName[I])).Append('"}');
    end;
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TLazPanel.Extremes: string;

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
        Text.Append('[').Append(Num(List[I][J].X)).Append(',');
        Text.Append(Num(List[I][J].Y)).Append(']');
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

function TLazPanel.Trace(const Param: Extended): string;
var
  Text: TStringBuilder;
  I: Integer;
  Data: PFormulaData;
  Point: TPointD;
  Polar, First: Boolean;
begin
  Polar := FGraph.CS = csPolar;
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"trace","polar":');
    if Polar then Text.Append('true') else Text.Append('false');
    Text.Append(',"param":').Append(Num(Param)).Append(',"list":[');
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      Data := FGraph.Formula.Data[I];
      if not Assigned(Data) or not FGraph.Formula.Active[I] then Continue;
      if not FGraph.Formula.Tracing[I] then Continue;
      if not Check(FGraph.SA, Data.ScriptIndex) then Continue;
      if Polar then Point := FGraph.ComputePolar(Param, FGraph.SA[Data.ScriptIndex])
      else
        Point := FGraph.ComputeRectangular(Param, FGraph.SA[Data.ScriptIndex]);
      if IsNan(Point.X) or IsNan(Point.Y) or IsInfinite(Point.Y) then Continue;
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"i":').Append(I);
      Text.Append(',"x":').Append(Num(Point.X));
      Text.Append(',"y":').Append(Num(Point.Y)).Append('}');
    end;
    Text.Append(']}');
    Result := Text.ToString;
  finally
    Text.Free;
  end;
end;

function TLazPanel.Snapshot: string;
var
  Text: TStringBuilder;
  I: Integer;
  First: Boolean;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"snapshot"');
    if FGraph.CS = csPolar then Text.Append(',"cs":"polar"')
    else
      Text.Append(',"cs":"rect"');
    Text.Append(',"formulas":[');
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      if not First then Text.Append(',');
      First := False;
      Text.Append('{"text":"').Append(Escape(FGraph.Formula[I])).Append('"');
      if FGraph.Formula.Active[I] then Text.Append(',"on":true')
      else
        Text.Append(',"on":false');
      if FGraph.Formula.Tracing[I] then Text.Append(',"trace":true')
      else
        Text.Append(',"trace":false');
      Text.Append('}');
    end;

    Text.Append('],"options":{');
    Text.Append('"maxX":').Append(Num(FGraph.MaxX));
    Text.Append(',"maxY":').Append(Num(FGraph.MaxY));
    Text.Append(',"centerX":').Append(Num(-FGraph.Offset.X));
    Text.Append(',"centerY":').Append(Num(-FGraph.Offset.Y));
    Text.Append(',"grid":').Append(Flag(FGraph.ShowGrid));
    Text.Append(',"axis":').Append(Flag(FGraph.ShowAxis));
    Text.Append(',"trace":').Append(Flag(FGraph.Tracing));
    Text.Append(',"cross":').Append(Flag(FGraph.Overlap));
    Text.Append(',"peak":').Append(Flag(FGraph.Extreme));
    Text.Append(',"sign":').Append(Flag(FGraph.Sign));
    Text.Append(',"smooth":').Append(Flag(FGraph.Antialias));
    Text.Append(',"multicolor":').Append(Flag(FGraph.MultiColor));
    Text.Append(',"autoquality":').Append(Flag(FGraph.Autoquality));
    Text.Append(',"precise":').Append(Flag(FGraph.HighPrecision));
    Text.Append(',"quality":').Append(FGraph.Quality);
    Text.Append(',"accuracy":').Append(FGraph.Accuracy);
    Text.Append(',"penWidth":').Append(FGraph.GraphPen.Width);
    Text.Append(',"hSpacing":').Append(Num(FGraph.HSpacing));
    Text.Append(',"vSpacing":').Append(Num(FGraph.VSpacing));
    Text.Append(',"polarAngle":').Append(Num(RadToDeg(FGraph.PolarMaxAngle)));
    Text.Append(',"calcTime":').Append(FGraph.ThreadWorkTime);
    Text.Append(',"overlapTime":').Append(FGraph.OverlapMaxTime);
    Text.Append(',"overlapDepth":').Append(FGraph.OverlapMaxDepth);
    Text.Append(',"zoomIn":').Append(Num(FGraph.ZoomInFactor));
    Text.Append(',"zoomOut":').Append(Num(FGraph.ZoomOutFactor));
    Text.Append(',"markSpacing":').Append(FGraph.MarkSpacing);
    Text.Append(',"decimals":').Append(Decimals);
    Text.Append(',"keepRatio":').Append(Flag(FKeepRatio));
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

function TLazPanel.StateDir: string;
begin
  Result := Trim(Npp.ConfigDir);
  if Result = '' then Result := GetEnvironmentVariable('LOCALAPPDATA');
  Result := IncludeTrailingPathDelimiter(Result) + 'GraphBuilderLaz';
  ForceDirectories(Result);
  Result := IncludeTrailingPathDelimiter(Result);
end;

function TLazPanel.SlotFile(const Slot: Integer): string;
begin
  Result := StateDir + Format('slot%d.json', [Slot]);
end;

function TLazPanel.SessionFile: string;
begin
  Result := StateDir + 'session.json';
end;

function TLazPanel.Decimals: Integer;
begin
  Result := Pos('.', FGraph.PrecisionFormat);
  if Result > 0 then Result := Length(FGraph.PrecisionFormat) - Result;
end;

procedure TLazPanel.SetDecimals(const Value: Integer);
begin
  if Value > 0 then FGraph.PrecisionFormat := '0.' + StringOfChar('#', Value)
  else
    FGraph.PrecisionFormat := '0';
end;

function StyleToByte(const Style: TFontStyles): Integer;
begin
  Result := 0;
  if fsBold in Style then Result := Result or 1;
  if fsItalic in Style then Result := Result or 2;
  if fsUnderline in Style then Result := Result or 4;
  if fsStrikeOut in Style then Result := Result or 8;
end;

function ByteToStyle(const Value: Integer): TFontStyles;
begin
  Result := [];
  if Value and 1 <> 0 then Include(Result, fsBold);
  if Value and 2 <> 0 then Include(Result, fsItalic);
  if Value and 4 <> 0 then Include(Result, fsUnderline);
  if Value and 8 <> 0 then Include(Result, fsStrikeOut);
end;

function TLazPanel.Stored: string;
var
  Data: TJSONData;
  Root, Native: TJSONObject;
begin
  Result := FState;
  if Trim(FState) = '' then Exit;
  Data := nil;
  try
    try
      Data := GetJSON(FState);
    except
      Exit;
    end;
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    Native := TJSONObject.Create;
    Native.Add('signFontName', FGraph.SignFont.Name);
    Native.Add('signFontSize', FGraph.SignFont.Size);
    Native.Add('signFontColor', Integer(FGraph.SignFont.Color));
    Native.Add('signFontCharset', Integer(FGraph.SignFont.Charset));
    Native.Add('signFontStyle', StyleToByte(FGraph.SignFont.Style));
    Root.Add('native', Native);
    Result := Root.AsJSON;
  finally
    Data.Free;
  end;
end;

procedure TLazPanel.ApplyNative(const Root: TJSONObject);
var
  Item: TJSONData;
  Native: TJSONObject;
begin
  Item := Root.Find('native');
  if not (Item is TJSONObject) then Exit;
  Native := TJSONObject(Item);
  FGraph.SignFont.Name := Native.Get('signFontName', FGraph.SignFont.Name);
  FGraph.SignFont.Size := Native.Get('signFontSize', FGraph.SignFont.Size);
  FGraph.SignFont.Color := TColor(Native.Get('signFontColor', Integer(FGraph.SignFont.Color)));
  FGraph.SignFont.Charset := Native.Get('signFontCharset', Integer(FGraph.SignFont.Charset));
  FGraph.SignFont.Style := ByteToStyle(Native.Get('signFontStyle', StyleToByte(FGraph.SignFont.Style)));
  Root.Delete('native');
end;

procedure TLazPanel.SaveSession;
var
  List: TStringList;
begin
  if FState = '' then Exit;

  if Pos('"formulas":[]', FState) > 0 then Exit;
  List := TStringList.Create;
  try
    List.Text := Stored;
    try
      List.SaveToFile(SessionFile);
    except

      on E: Exception do LogStep('the session was not saved: ' + E.Message);
    end;
  finally
    List.Free;
  end;
end;

function TLazPanel.LoadSession: Boolean;
var
  List: TStringList;
begin
  Result := False;
  if not FileExists(SessionFile) then Exit;
  List := TStringList.Create;
  try
    try
      List.LoadFromFile(SessionFile);
      LoadState(List.Text);
      Result := True;
    except
      on E: Exception do LogStep('the session was not read: ' + E.Message);
    end;
  finally
    List.Free;
  end;
end;

procedure TLazPanel.LoadState(const Text: string);
var
  Data: TJSONData;
  Root: TJSONObject;
begin
  if Trim(Text) = '' then Exit;
  Data := nil;
  try
    try
      Data := GetJSON(Text);
    except
      Exit;
    end;
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);

    if not (Root.Find('formulas') is TJSONArray) then Exit;
    if TJSONArray(Root.Find('formulas')).Count = 0 then Exit;

    ApplyNative(Root);

    Root.Delete('cmd');
    Root.Add('type', 'snapshot');
    Answer(Root.AsJSON);
  finally
    Data.Free;
  end;
end;

function TLazPanel.Bookmarks: string;
var
  Text: TStringBuilder;
  I: Integer;
begin
  Text := TStringBuilder.Create;
  try
    Text.Append('{"type":"bookmarks","slots":[');
    for I := 0 to 9 do
    begin
      if I > 0 then Text.Append(',');
      if FileExists(SlotFile(I)) then Text.Append('true') else Text.Append('false');
    end;
    Text.Append(']}');
    Result := Text.ToString;
    LogStep('  occupancy: ' + Result);
  finally
    Text.Free;
  end;
end;

function TLazPanel.SignFont: string;
var
  Dialog: TFontDialog;
begin
  Result := BusyReply;
  Dialog := TFontDialog.Create(nil);
  try
    Dialog.Font.Assign(FGraph.SignFont);
    if not Dialog.Execute then Exit;
    FGraph.SignFont.Assign(Dialog.Font);
  finally
    Dialog.Free;
  end;
  Rebuild;
end;

function TLazPanel.BookmarkSlot(const Slot: Integer; const Mode: string): string;
var
  List: TStringList;
begin
  LogStep(Format('bookmark: mode=%s slot=%d file=%s present=%s state=%d',
    [Mode, Slot, SlotFile(Slot), BoolToStr(FileExists(SlotFile(Slot)), True), Length(FState)]));
  Result := Bookmarks;
  if (Slot < 0) or (Slot > 9) then Exit;
  if Mode = 'save' then
  begin
    if FState = '' then Exit;
    List := TStringList.Create;
    try
      List.Text := Stored;
      List.SaveToFile(SlotFile(Slot));
    finally
      List.Free;
    end;
    Result := Bookmarks;
  end
  else if Mode = 'load' then
  begin
    if not FileExists(SlotFile(Slot)) then Exit;
    List := TStringList.Create;
    try
      List.LoadFromFile(SlotFile(Slot));
      LoadState(List.Text);
    finally
      List.Free;
    end;

    DeleteFile(SlotFile(Slot));
    Result := Bookmarks;
  end;
end;

function TLazPanel.ReportPage: string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('type', 'report');
    Root.Add('html', ReportFacts.Extend('<html><head></head><body></body></html>', FGraph, FDark));
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

initialization
  Dot := DefaultFormatSettings;
  Dot.DecimalSeparator := '.';
end.
