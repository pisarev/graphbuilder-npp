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
  StdCtrls, Clipbrd, Dialogs, fpjson, jsonparser, uWVBrowser, uWVWinControl, uWVWindowParent,
  uWVTypes, uWVTypeLibrary, uWVBrowserBase, uWVLoader, uWVCoreWebView2Args, NotepadPP.Plugin,
  NotepadPP.Docking, uLazTrace, CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine,
  CrossGraph, ReportFacts;

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
    FNote: TLabel;
    FWaitFrom: Cardinal;
    FReady: Boolean;
    FPending: string;
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
    procedure Complain(const Text: string);
    procedure Poll(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Created(Sender: TObject);
    procedure Failed(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure Leaving(Sender: TObject; const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2NavigationStartingEventArgs);
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
    function Restorable(const Root: TJSONObject): Boolean;
    procedure SaveSession;
    function LoadSession: Boolean;
    procedure LoadState(const Text: string);
    procedure WMMove(var aMessage: TWMMove); message WM_MOVE;
    procedure WMSize(var aMessage: TWMSize); message WM_SIZE;
  protected
    procedure CreateWnd; override;
    procedure DockDocked(Sender: TObject);
    procedure DockFloated(Sender: TObject);
    procedure DockDropped(Sender: TObject);
    procedure DockSwitchIn(Sender: TObject);
    procedure DockSwitchOff(Sender: TObject);
    function Deliver(const Kind: string; const List: TStrings; const Raw: string): Boolean;
  public
    constructor Create(NppParent: TNppPlugin; DlgId: Integer); override;
    procedure SetTheme(const Dark: Boolean);
    function Suggest(const Text: string): Boolean;
    function Adopt(const List: TStrings; const Raw: string): Boolean;
    function Preview(const List: TStrings; const Raw: string): Boolean;
  end;

var
  Panel: TLazPanel = nil;

const
  PageZoomIn = 0.1;
  PageZoomOut = 0.1;
  PageQuality = 18;
  PageAccuracy = 1;
  PagePenWidth = 1;
  PageDecimals = 6;
  PageHSpacing = 1;
  PageVSpacing = 1;
  PagePolarAngle = 360;
  PageCalcTime = 5000;
  PageOverlapTime = 1000;
  PageOverlapDepth = 16;
  PageMarkSpacing = 14;
  PageSignLayout = 1;
  PageSignMargin = 16;
  PageSignBlend = 235;
  PageKeepRatio = True;
  PagePenColor = '--c1';

procedure SeedPageDefaults(const Graph: TGraph);

implementation

uses uLazPlugin, uShare;

const
  MaxSegmentPoints = 6000;
  DoneCheck = 40;
  BusyReply = '{"type":"busy"}';
  WaitLimit = 15000;
  NoRuntime = 'The panel is drawn by the Microsoft Edge WebView2 runtime, ' +
    'and it is not present in the system. On Windows 11 it is standard; on Windows 10 it comes ' +
    'with Edge, and Microsoft ships it as a separate download. Reason:';
  NoLoader = 'The panel is drawn by the Microsoft Edge WebView2 runtime, ' +
    'and the loader was not created. The plugin could not begin to bring it up at all - ' +
    'details are in the plugin log.';
  TooLong = 'The Microsoft Edge WebView2 runtime did not come up within ' +
    'the time allowed. There is nothing more to wait for: close the panel and open it ' +
    'again, and if it repeats - see the plugin log.';

var
  Dot: TFormatSettings;

function Num(const Value: Extended): string;
begin
  if IsNan(Value) or IsInfinite(Value) then Exit('0');
  Result := FormatFloat('0.##########', Value, Dot);
end;

function Flag(const Value: Boolean): string;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
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
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(string(PWideChar(@Buffer[0])))) +
    'ui\index.html';
end;

procedure TLazPanel.CreateWnd;
begin
  inherited;
  LogStep('panel window created, handle ' + IntToStr(PtrUInt(Handle)));
end;

procedure TLazPanel.DockDocked(Sender: TObject);
begin
  LogStep('docking: DMN_DOCK, the panel is in the dock');
end;

procedure TLazPanel.DockFloated(Sender: TObject);
begin
  LogStep('docking: DMN_FLOAT, the panel is floating');
end;

procedure TLazPanel.DockDropped(Sender: TObject);
begin
  LogStep('docking: the window was dropped after dragging, handle ' + IntToStr(PtrUInt(Handle)));
end;

procedure TLazPanel.DockSwitchIn(Sender: TObject);
begin
  LogStep('docking: the panel is shown on its own tab');
end;

procedure TLazPanel.DockSwitchOff(Sender: TObject);
begin
  LogStep('docking: the panel moved to a hidden tab');
end;

procedure SeedPageDefaults(const Graph: TGraph);
begin
  if not Assigned(Graph) then Exit;
  Graph.ZoomInFactor := PageZoomIn;
  Graph.ZoomOutFactor := PageZoomOut;
  Graph.Quality := PageQuality;
  Graph.Accuracy := PageAccuracy;
  Graph.GraphPen.Width := PagePenWidth;
  Graph.PrecisionFormat := '0.' + StringOfChar('#', PageDecimals);
  Graph.HSpacing := PageHSpacing;
  Graph.VSpacing := PageVSpacing;
  Graph.PolarMaxAngle := DegToRad(PagePolarAngle);
  Graph.ThreadWorkTime := PageCalcTime;
  Graph.OverlapMaxTime := PageOverlapTime;
  Graph.OverlapMaxDepth := PageOverlapDepth;
  Graph.MarkSpacing := PageMarkSpacing;
  Graph.SignLayout := TLayoutType(PageSignLayout);
  Graph.SignMargin := PageSignMargin;
  Graph.SignBlendValue := PageSignBlend;
end;

constructor TLazPanel.Create(NppParent: TNppPlugin; DlgId: Integer);
begin
  inherited Create(NppParent, DlgId);
  Caption := 'Graph Builder';
  Width := 900;
  Height := 600;
  OnShow := Shown;
  OnDock := DockDocked;
  OnFloat := DockFloated;
  OnFloatDropped := DockDropped;
  OnSwitchIn := DockSwitchIn;
  OnSwitchOff := DockSwitchOff;
  FKeepRatio := PageKeepRatio;
  FPenColor := PagePenColor;
  FGraph := TGraph.Create(Self);
  SeedPageDefaults(FGraph);
  FGraph.Parent := Self;
  FGraph.SetBounds(0, 0, ClientWidth, ClientHeight);
  FGraph.HandleNeeded;
  FGraph.Silent := True;
  FGraph.Visible := False;
  FGraph.OnOverlap := GraphOverlap;
  FGraph.OnExtreme := GraphExtreme;
  FHost := TWVWindowParent.Create(Self);
  FHost.Parent := Self;
  FHost.Align := alClient;
  FBrowser := TWVBrowser.Create(Self);
  FBrowser.OnAfterCreated := Created;
  FBrowser.OnWebMessageReceived := Incoming;
  FBrowser.OnInitializationError := Failed;
  FBrowser.OnNavigationStarting := Leaving;
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

procedure TLazPanel.Complain(const Text: string);
begin
  LogStep('THE PANEL IS EMPTY: ' + Text);
  UpdateDisplayInfo(Text);
  if not Assigned(FNote) then
  begin
    FNote := TLabel.Create(Self);
    FNote.Parent := Self;
    FNote.Align := alTop;
    FNote.WordWrap := True;
    FNote.BorderSpacing.Around := 12;
    FNote.Font.Size := 10;
  end;
  FNote.Caption := Text;
  FNote.Visible := True;
  if Assigned(FHost) then FHost.Visible := False;
end;

procedure TLazPanel.Shown(Sender: TObject);
begin
  LogStep(Format('show: created=%s, loader=%s',
    [BoolToStr(FStarted, True), BoolToStr(Assigned(GlobalWebView2Loader), True)]));
  if FStarted then Exit;
  if not Assigned(GlobalWebView2Loader) then
  begin
    Complain(NoLoader);
    Exit;
  end;
  if GlobalWebView2Loader.InitializationError then
  begin
    Complain(NoRuntime + ' ' + string(GlobalWebView2Loader.ErrorMessage));
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
    FWaitFrom := GetTickCount;
    FWait.Enabled := True;
  end;
end;

procedure TLazPanel.Poll(Sender: TObject);
begin
  if not Assigned(GlobalWebView2Loader) then
  begin
    FWait.Enabled := False;
    Complain(NoLoader);
    Exit;
  end;
  if GlobalWebView2Loader.InitializationError then
  begin
    FWait.Enabled := False;
    Complain(NoRuntime + ' ' + string(GlobalWebView2Loader.ErrorMessage));
    Exit;
  end;
  if not GlobalWebView2Loader.Initialized then
  begin
    if GetTickCount - FWaitFrom > WaitLimit then
    begin
      FWait.Enabled := False;
      Complain(TooLong);
    end;
    Exit;
  end;
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

procedure TLazPanel.Leaving(Sender: TObject; const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2NavigationStartingEventArgs);
begin
  FReady := False;
end;

procedure TLazPanel.Failed(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  Complain(NoRuntime + ' ' + string(aErrorMessage));
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

function TLazPanel.Suggest(const Text: string): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not FReady then
  begin
    FPending := Text;
    Exit;
  end;
  Root := TJSONObject.Create;
  try
    Root.Add('type', 'suggest');
    Root.Add('text', Text);
    Answer(Root.AsJSON);
  finally
    Root.Free;
  end;
  Result := True;
end;

function TLazPanel.Deliver(const Kind: string; const List: TStrings; const Raw: string): Boolean;
var
  Root: TJSONObject;
  Items: TJSONArray;
  I: Integer;
begin
  Result := False;
  if not FReady then Exit;
  Root := TJSONObject.Create;
  try
    Items := TJSONArray.Create;
    if Assigned(List) then
      for I := 0 to List.Count - 1 do
        if Trim(List[I]) <> '' then Items.Add(Trim(List[I]));
    Root.Add('type', Kind);
    Root.Add('list', Items);
    Root.Add('text', Raw);
    Answer(Root.AsJSON);
  finally
    Root.Free;
  end;
  Result := True;
end;

function TLazPanel.Adopt(const List: TStrings; const Raw: string): Boolean;
begin
  Result := False;
  if (not Assigned(List) or (List.Count = 0)) and (Trim(Raw) = '') then Exit;
  Result := Deliver('adopt', List, Raw);
end;

function TLazPanel.Preview(const List: TStrings; const Raw: string): Boolean;
begin
  Result := Deliver('preview', List, Raw);
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
  Cmd, Formula, Pasted: string;
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
      if Root.Get('cs', '') = 'polar' then
        FGraph.CS := csPolar
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
      FState := Text;
      SaveSession;
      if Root.Find('options') is TJSONObject then Apply(TJSONObject(Root.Find('options')));
      Rebuild;
      Exit(BusyReply);
    end;
    if Cmd = 'signfont' then Exit(SignFont);
    if Cmd = 'trace' then Exit(Trace(Root.Get('param', 0.0)));
    if Cmd = 'bookmark' then
      Exit(BookmarkSlot(Root.Get('slot', 0), Root.Get('mode', 'status')));
    if Cmd = 'copy' then
    begin
      if Root.Get('text', '') <> '' then
        Clipboard.AsText := Root.Get('text', '')
      else if FState <> '' then
        Clipboard.AsText := FState;
      Exit;
    end;
    if Cmd = 'paste' then
    begin
      Pasted := Clipboard.AsText;
      case ClipboardKind(Pasted) of
        ckShare: LoadState(WithoutEditor(ShareState(Pasted)));
        ckState: LoadState(WithoutEditor(Pasted));
        ckBroken:;
      else
        Item := TJSONObject.Create;
        try
          Item.Add('type', 'clipboard');
          Item.Add('text', Pasted);
          Answer(Item.AsJSON);
        finally
          Item.Free;
        end;
      end;
      Exit;
    end;
    if Cmd = 'report' then Exit(ReportPage);
    if Cmd = 'toeditor' then
    begin
      if Npp is TLazPlugin then
        TLazPlugin(Npp).ReportToEditor(ReportFacts.AsMarkdown(FGraph),
          Root.Get('where', 'new') <> 'here');
      Exit;
    end;
    if Cmd = 'ready' then
    begin
      if Npp is TLazPlugin then
        Answer('{"type":"hello","engine":"crossgraph-fpc","editor":true,"budgets":true}')
      else
        Answer('{"type":"hello","engine":"crossgraph-fpc"}');
      LoadSession;
      FReady := True;
      if FPending <> '' then
      begin
        LogStep('handing over the formula that was held back: ' + FPending);
        Suggest(FPending);
        FPending := '';
      end;
      Exit('');
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
      if FGraph.Formula.Active[I] then
        Text.Append(',"on":true')
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
    LogStep(Format('  result: points %d, string length %d, head: %s',
      [Count, Length(Result), Copy(Result, 1, 220)]));
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
    if Polar then
      Text.Append('true')
    else
      Text.Append('false');
    Text.Append(',"param":').Append(Num(Param)).Append(',"list":[');
    First := True;
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      Data := FGraph.Formula.Data[I];
      if not Assigned(Data) or not FGraph.Formula.Active[I] then Continue;
      if not FGraph.Formula.Tracing[I] then Continue;
      if not Check(FGraph.SA, Data.ScriptIndex) then Continue;
      if Polar then
        Point := FGraph.ComputePolar(Param, FGraph.SA[Data.ScriptIndex])
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
      if FGraph.Formula.Active[I] then
        Text.Append(',"on":true')
      else
        Text.Append(',"on":false');
      if FGraph.Formula.Tracing[I] then
        Text.Append(',"trace":true')
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
  if Value > 0 then
    FGraph.PrecisionFormat := '0.' + StringOfChar('#', Value)
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

function TLazPanel.Restorable(const Root: TJSONObject): Boolean;
var
  List: TJSONData;
begin
  Result := False;
  if not Assigned(Root) then Exit;
  List := Root.Find('formulas');
  if not (List is TJSONArray) then Exit;
  Result := (TJSONArray(List).Count > 0) or Root.Get('cleared', False);
end;

procedure TLazPanel.SaveSession;
var
  List: TStringList;
  Data: TJSONData;
  Keep: Boolean;
begin
  if FState = '' then Exit;
  Data := nil;
  Keep := False;
  try
    try
      Data := GetJSON(FState);
      Keep := (Data is TJSONObject) and Restorable(TJSONObject(Data));
    except
      Keep := False;
    end;
  finally
    Data.Free;
  end;
  if not Keep then Exit;
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
    if not Restorable(Root) then Exit;
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
      if FileExists(SlotFile(I)) then
        Text.Append('true')
      else
        Text.Append('false');
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
  SaveSession;
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
    Result := Bookmarks;
  end
  else if Mode = 'drop' then
  begin
    if not FileExists(SlotFile(Slot)) then Exit;
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
