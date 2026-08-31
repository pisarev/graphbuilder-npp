{ ************************************************************************** }
{                                                                            }
{ MainForm                                                                   }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit MainForm;

{$B-}
{$I Directives.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, IniFiles, Graphics, Controls, Forms, Dialogs,
  ActnList, ActnMan, StdCtrls, Buttons, Grids, ExtCtrls, ComCtrls, Contnrs, SHDocVw,
  XPStyleActnCtrls, NotepadPP.Types, NotepadPP.Plugin, NotepadPP.Forms, NotepadPP.Docking,
  BlobManager, FastList, CrossGraph.Types, CrossGraph.Engine, CrossGraph;

const
  FormulaSGCode = MaxWord;
  FormulaSGColCount = 5;
  GroupCount = 2;
  AColumn = 0;
  BColumn = 1;
  CColumn = 2;
  DColumn = 3;
  EColumn = 4;
  ObjectColumn = CColumn;
  WM_REMOVE = WM_USER + 1;

type
  TScrollBox = class(Forms.TScrollBox);

  TEdit = class(StdCtrls.TEdit)
  private
    FDecrementValue: string;
    FIncrementValue: string;
    FOutputRestrict: string;
    FBorderRestrict: string;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
  protected
    procedure Loaded; override;
  public
    property BorderRestrict: string read FBorderRestrict write FBorderRestrict;
    property OutputRestrict: string read FOutputRestrict write FOutputRestrict;
    property IncrementValue: string read FIncrementValue write FIncrementValue;
    property DecrementValue: string read FDecrementValue write FDecrementValue;
  end;

  PCellData = ^TCellData;
  TCellData = record
    FormulaIndex: Integer;
    A, B, C: TSpeedButton;
  end;

  TEventType = (etDelete, etEnableFormula, etEnableTracing);
  TCellEvent = procedure(const Data: PCellData; const EventType: TEventType) of object;

  TStringGrid = class(Grids.TStringGrid)
  private
    FCellEvent: TCellEvent;
    FInplaceList: TObjectList;
    function GetCellData(Index: Integer): PCellData;
    function GetEmpty: Boolean;
    function GetFormula(Index: Integer): string;
    function GetTracing(Index: Integer): string;
    procedure SetCellData(Index: Integer; const Value: PCellData);
    procedure SetFormula(Index: Integer; const Value: string);
    procedure SetTracing(Index: Integer; const Value: string);
  protected
    procedure WMRemove(var Message: TMessage); message WM_REMOVE;
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure Loaded; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function CanEditShow: Boolean; override;
    procedure TopLeftChanged; override;
    procedure ColWidthsChanged; override;
    procedure RowHeightsChanged; override;
    procedure Paint; override;
    procedure ResizeColumn; virtual;
    procedure Make(const Index: Integer); overload; virtual;
    procedure Make; overload; virtual;
    procedure Delete(const Index: Integer); virtual;
    procedure EnableFormula(Sender: TObject); virtual;
    procedure EnableTracing(Sender: TObject); virtual;
    procedure Remove(Sender: TObject); virtual;
    function Check: Boolean; overload; virtual;
    function Check(const Index: Integer): Boolean; overload; virtual;
    procedure DoCellEvent(const Data: PCellData; const EventType: TEventType); virtual;
    property InplaceList: TObjectList read FInplaceList write FInplaceList;
    property Empty: Boolean read GetEmpty;
  public
    destructor Destroy; override;
    function CellRect(ACol, ARow: Longint): TRect;
    function Add: Integer; virtual;
    procedure Clear; virtual;
    procedure Arrange(const Rect: TRect; const Inplace: TControl); overload; virtual;
    procedure Arrange; overload; virtual;
    function FindCellData(const Index: Integer; out Data: PCellData): Boolean; virtual;
    property CellData[Index: Integer]: PCellData read GetCellData write SetCellData;
    property Formula[Index: Integer]: string read GetFormula write SetFormula;
    property Tracing[Index: Integer]: string read GetTracing write SetTracing;
    property CellEvent: TCellEvent read FCellEvent write FCellEvent;
  end;

  TGraph = class(CrossGraph.TGraph)
  public
    property Parser;
  end;

  TMain = class(TNppDockingForm)
    AM: TActionManager;
    B0: TAction;
    B1: TAction;
    B2: TAction;
    B3: TAction;
    B4: TAction;
    B5: TAction;
    B6: TAction;
    B7: TAction;
    B8: TAction;
    B9: TAction;
    bFormula: TComboBox;
    BHide: TAction;
    bL: TScrollBox;
    bLayout: TComboBox;
    bQuality: TTrackBar;
    BShow: TAction;
    cAccuracy: TUpDown;
    cBlendValue: TUpDown;
    CD: TColorDialog;
    cDecimalPlaces: TUpDown;
    cMargin: TUpDown;
    cPenWidth: TUpDown;
    cQuality: TUpDown;
    eAccuracy: TEdit;
    eBlendValue: TEdit;
    eCalcTime: TEdit;
    eCenterX: TEdit;
    eCenterY: TEdit;
    eDecimalPlaces: TEdit;
    eHSpacing: TEdit;
    eMargin: TEdit;
    eMaxX: TEdit;
    eMaxY: TEdit;
    eOverlapMaxDepth: TEdit;
    eOverlapMaxTime: TEdit;
    ePenWidth: TEdit;
    ePolarMaxAngle: TEdit;
    eQuality: TEdit;
    eVSpacing: TEdit;
    eX: TEdit;
    eY: TEdit;
    eZoomInFactor: TEdit;
    eZoomOutFactor: TEdit;
    FD: TFontDialog;
    GAntialias: TAction;
    GAutoquality: TAction;
    GAxis: TAction;
    GClear: TAction;
    GColor: TAction;
    GCopy: TAction;
    GDraw: TAction;
    GExtreme: TAction;
    gFormula: TStringGrid;
    GGrid: TAction;
    GHighPrecision: TAction;
    GMulticolor: TAction;
    GOverlap: TAction;
    GPaste: TAction;
    GPolar: TAction;
    GPrint: TAction;
    GRectangular: TAction;
    GRefresh: TAction;
    GSign: TAction;
    GSignFont: TAction;
    GTracing: TAction;
    IL: TImageList;
    LHide: TAction;
    lPolarMaxAngle: TLabel;
    LShow: TAction;
    pB: TPanel;
    PC: TPageControl;
    pCalc: TPanel;
    pFormula: TPanel;
    pGraph: TTabSheet;
    pL: TPanel;
    pReport: TTabSheet;
    Splitter: TSplitter;
    WB: TWebBrowser;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure SGResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormFloat(Sender: TObject);
    procedure FormDock(Sender: TObject);
    procedure GDrawExecute(Sender: TObject);
    procedure GGridExecute(Sender: TObject);
    procedure GAxisExecute(Sender: TObject);
    procedure GTracingExecute(Sender: TObject);
    procedure GOverlapExecute(Sender: TObject);
    procedure GExtremeExecute(Sender: TObject);
    procedure GAntialiasExecute(Sender: TObject);
    procedure GMulticolorExecute(Sender: TObject);
    procedure GAutoqualityExecute(Sender: TObject);
    procedure GHighPrecisionExecute(Sender: TObject);
    procedure GSignExecute(Sender: TObject);
    procedure GCopyExecute(Sender: TObject);
    procedure GPasteExecute(Sender: TObject);
    procedure GSignFontExecute(Sender: TObject);
    procedure GClearExecute(Sender: TObject);
    procedure GRefreshExecute(Sender: TObject);
    procedure GColorExecute(Sender: TObject);
    procedure GPrintExecute(Sender: TObject);
    procedure GPrintUpdate(Sender: TObject);
    procedure LShowExecute(Sender: TObject);
    procedure LHideExecute(Sender: TObject);
    procedure BShowExecute(Sender: TObject);
    procedure BHideExecute(Sender: TObject);
    procedure BookmarkExecute(Sender: TObject);
    procedure bFormulaKeyPress(Sender: TObject; var Key: Char);
    procedure eXChange(Sender: TObject);
    procedure bQualityChange(Sender: TObject);
    procedure eCenterXChange(Sender: TObject);
    procedure eCenterYChange(Sender: TObject);
    procedure eMaxXChange(Sender: TObject);
    procedure eMaxYChange(Sender: TObject);
    procedure ePolarMaxAngleChange(Sender: TObject);
    procedure eAccuracyChange(Sender: TObject);
    procedure eDecimalPlacesChange(Sender: TObject);
    procedure eQualityChange(Sender: TObject);
    procedure ePenWidthChange(Sender: TObject);
    procedure eBlendValueChange(Sender: TObject);
    procedure bLayoutChange(Sender: TObject);
    procedure eMarginChange(Sender: TObject);
    procedure eHSpacingChange(Sender: TObject);
    procedure eVSpacingChange(Sender: TObject);
    procedure eCalcTimeChange(Sender: TObject);
    procedure eOverlapMaxTimeChange(Sender: TObject);
    procedure eOverlapMaxDepthChange(Sender: TObject);
    procedure eZoomInFactorChange(Sender: TObject);
    procedure eZoomOutFactorChange(Sender: TObject);
    procedure CSChange(Sender: TObject);
    procedure gFormulaDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure gFormulaSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: String);
    procedure PCChange(Sender: TObject);
    procedure SplitterMoved(Sender: TObject);
    procedure WBDocumentComplete(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant);
  private
    FReportLoaded: Boolean;
    FUpdateCount: Integer;
    FManager: TBlobManager;
    FFormulaList: TFastList;
    FTraceList: TFastList;
    FGraph: TGraph;
    FPageKeepRatio: Boolean;
    FPagePenColor: string;
  protected
    procedure WndProc(var Message: TMessage); override;
    function GetFileName: string; virtual;
    function GetUserPath: string; virtual;
    function GetDecimalPlaces: Integer; virtual;
    procedure SetDecimalPlaces(const Value: Integer); virtual;
    procedure Load(const AFile: TMemIniFile); virtual;
    procedure Save(const AFile: TMemIniFile; const FL: Boolean; const CS: PCoordinateSystem = nil); virtual;
    procedure Open; virtual;
    function LoadFile(const AFile: TMemIniFile; const AName: string): Boolean; virtual;
    procedure SaveFile(const AFile: TMemIniFile; const AName: string); virtual;
    procedure LoadFormulaList; virtual;
    procedure SaveFormulaList; virtual;
    function LoadState(const AName: string): Boolean; virtual;
    procedure SaveState(const AName: string; const FL: Boolean; const CS: PCoordinateSystem = nil); virtual;
    function HasState(const AName: string): Boolean; virtual;
    procedure CopyState(const AFrom, ATo: string); virtual;
    procedure DropState(const AName: string); virtual;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    property FormulaList: TFastList read FFormulaList write FFormulaList;
    property UpdateCount: Integer read FUpdateCount;
    property FileName: string read GetFileName;
    property UserPath: string read GetUserPath;
    property Manager: TBlobManager read FManager write FManager;
    property PageKeepRatio: Boolean read FPageKeepRatio write FPageKeepRatio;
    property PagePenColor: string read FPagePenColor write FPagePenColor;
    property ReportLoaded: Boolean read FReportLoaded write FReportLoaded;
  public
    FTitleBase: string;
    FOpenKeys: string;
    FGrabKeys: string;
    procedure SyncTitle;
  protected
    procedure Resize; override;
  public
    constructor Create(NppParent: TNppPlugin; DlgId: Integer); override;
    constructor Create(AOwner: TNppForm; DlgId: Integer); override;
    procedure ApplyEditorTheme; virtual;
    procedure Suggest(const Formula: string); virtual;
    procedure Next(const Control: TWinControl; const Forward: Boolean); virtual;
    procedure CellEvent(const Data: PCellData; const EventType: TEventType); virtual;
    procedure OffsetChange(Sender: TObject); virtual;
    function AddFormula(const Text: string; const Visible, Correct, Tracing: Boolean): Integer; virtual;
    procedure Clear; virtual;
    procedure MouseWheelHandler(var Message: TMessage); override;
    procedure TraceDone(Sender: TObject); virtual;
    procedure Trace(const Formula, Tracing: string); virtual;
    procedure RectangularTrace(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD); virtual;
    procedure PolarTrace(Sender: TObject; const FormulaIndex: Integer; const Angle: array of Extended;
      const Point: array of TPointD); virtual;
    property TraceList: TFastList read FTraceList write FTraceList;
    property Graph: TGraph read FGraph write FGraph;
    property DecimalPlaces: Integer read GetDecimalPlaces write SetDecimalPlaces;
  end;

const
  FileExt = '.ini';
  ReportFileName = 'report.html';
  PointsExt = '.csv';
  GraphName = 'Graph';
  PanelSection = 'Panel';
  LBoxSection = 'LBox';
  CSSection = 'CS';
  CenterSection = 'Center';
  SizeSection = 'Size';
  GraphSection = 'Graph';
  LineSection = 'Line';
  SignSection = 'Sign';
  GridSection = 'Grid';
  CalcSection = 'Calc';
  ZoomSection = 'Zoom';
  FormulaSection = 'Formula';
  FLSection = 'FormulaList';
  LIdent = 'L';
  BIdent = 'B';
  PositionIdent = 'Position';
  CSIdent = 'CS';
  XIdent = 'X';
  YIdent = 'Y';
  PolarMaxAngleIdent = 'PolarMaxAngle';
  GridIdent = 'Grid';
  AxisIdent = 'Axis';
  TracingIdent = 'Tracing';
  OverlapIdent = 'Overlap';
  ExtremeIdent = 'Extreme';
  AntialiasIdent = 'Antialias';
  MulticolorIdent = 'Multicolor';
  AutoqualityIdent = 'Autoquality';
  ColorIdent = 'Color';
  AccuracyIdent = 'Accuracy';
  HighPrecisionIdent = 'HighPrecision';
  PrecisionFormatIdent = 'PrecisionFormat';
  QualityIdent = 'Quality';
  PenWidthIdent = 'PenWidth';
  SignIdent = 'Sign';
  FontNameIdent = 'FontName';
  FontCharsetIdent = 'FontCharset';
  FontColorIdent = 'FontColor';
  FontHeightIdent = 'FontHeight';
  FontSizeIdent = 'FontSize';
  FontStyleIdent = 'FontStyle';
  TransparencyIdent = 'Transparency';
  LayoutIdent = 'Layout';
  MarginIdent = 'Margin';
  HSpacingIdent = 'HSpacing';
  VSpacingIdent = 'VSpacing';
  CalcTimeIdent = 'CalcTime';
  OverlapMaxDepthIdent = 'OverlapMaxDepth';
  OverlapMaxTimeIdent = 'OverlapMaxTime';
  MarkSpacingIdent = 'MarkSpacing';
  PageSection = 'Page';
  KeepRatioIdent = 'KeepRatio';
  PenColorIdent = 'PenColor';
  MinIdent = 'Min';
  MaxIdent = 'Max';
  InFactorIdent = 'InFactor';
  OutFactorIdent = 'OutFactor';
  FormulaVisible = 'Visible';
  FormulaCorrect = 'Correct';
  FormulaTracing = 'Tracing';
  ClipboardError = 'The clipboard does not contain any valid data';

var
  Main: TMain;

implementation

uses
  ClipboardMonitor, DarkTheme, ReportFacts, Share, WebPanel, Math, TypInfo, Types,
  CalcUtils, CrossGraph.Geometry, CrossVision.Geometry.Types, MemoryUtils, Parser,
  ParseTypes, StrUtils, TextBuilder, TextConsts, TextUtils, ValueTypes, ValueUtils,
  ZUtils, NumberUtils;

{$R *.dfm}

procedure TEdit.Loaded;
const
  Delimiter = '|';
begin
  inherited;
  FBorderRestrict := Trim(SubStr(HelpKeyword, Delimiter, 0, True));
  FOutputRestrict := Trim(SubStr(HelpKeyword, Delimiter, 1, True));
  FIncrementValue := Trim(SubStr(HelpKeyword, Delimiter, 2, True));
  FDecrementValue := Trim(SubStr(HelpKeyword, Delimiter, 3, True));
  HelpKeyword := '';
end;

procedure TEdit.WMMouseWheel(var Message: TWMMouseWheel);
var
  S, Value: string;
begin
  inherited;
  if not PtInRect(ClientRect, ScreenToClient(SmallPointToPoint(Message.Pos))) then Exit;
  if Message.WheelDelta > 0 then
    S := Format(Trim(FIncrementValue), [Text])
  else
    S := Format(Trim(FDecrementValue), [Text]);
  if (S <> '') and TryTextToString(S, Value) and ((Trim(FBorderRestrict) = '') or AsBoolean(Format(FBorderRestrict, [Value]))) then
    Text := Value;
end;

function TStringGrid.Add: Integer;
begin
  if Check then
  begin
    if not Empty then
    begin
      RowCount := RowCount + 1;
      Rows[RowCount - 1].Clear;
    end;
    Result := RowCount - 1;
    Make(Result);
  end
  else
    Result := -1;
end;

procedure TStringGrid.Arrange;
var
  I: Integer;
  Data: PCellData;
begin
  for I := FixedRows to RowCount - 1 do
    if FindCellData(I, Data) then
    begin
      if Assigned(Data.A) then Arrange(CellRect(AColumn, I), Data.A);
      if Assigned(Data.B) then Arrange(CellRect(BColumn, I), Data.B);
      if Assigned(Data.C) then Arrange(CellRect(EColumn, I), Data.C);
    end;
end;

procedure TStringGrid.Arrange(const Rect: TRect; const Inplace: TControl);
begin
  Inplace.BoundsRect := Classes.Rect(Rect.Left, Rect.Top, Rect.Right - 1, Rect.Bottom - 1);
  Inplace.Invalidate;
end;

function TStringGrid.CellRect(ACol, ARow: Integer): TRect;
begin
  Result := inherited CellRect(ACol, ARow);
  Result.Bottom := Result.Top + DefaultRowHeight;
end;

function TStringGrid.Check: Boolean;
begin
  Result := (Tag = FormulaSGCode) and (ColCount = FormulaSGColCount);
end;

function TStringGrid.CanEditShow: Boolean;
var
  Data: PCellData;
begin
  Result := inherited CanEditShow and (not Check or Check and not Empty and (Col = CColumn) and
    FindCellData(Row, Data) and Data.A.Down);
end;

function TStringGrid.Check(const Index: Integer): Boolean;
begin
  Result := (Index >= FixedRows) and (Index < RowCount);
end;

procedure TStringGrid.Clear;
var
  I: Integer;
  Data: PCellData;
begin
  if Check then
  begin
    for I := FixedRows to RowCount - 1 do
      if FindCellData(I, Data) then
      begin
        CellData[I] := nil;
        Dispose(Data);
        Rows[I].Clear;
      end;
    RowCount := FixedRows + 1;
    FInplaceList.Clear;
  end;
  inherited;
end;

procedure TStringGrid.ColWidthsChanged;
begin
  inherited;
  if Check then Arrange;
end;

procedure TStringGrid.Delete(const Index: Integer);
var
  I: Integer;
  Data: PCellData;
begin
  if Check and Check(Index) then
  begin
    if FindCellData(Index, Data) then Dispose(Data);
    CellData[Index] := nil;
    for I := Index to RowCount - 1 do
      if I < RowCount - 1 then
      begin
        Rows[I].Assign(Rows[I + 1]);
        if FindCellData(I, Data) then
        begin
          Dec(Data.FormulaIndex);
          if Assigned(Data.A) then
          begin
            Data.A.Tag := I;
            Data.A.GroupIndex := I * GroupCount + 1;
          end;
          if Assigned(Data.B) then
          begin
            Data.B.Tag := I;
            Data.B.GroupIndex := I * GroupCount + 2;
          end;
          if Assigned(Data.C) then Data.C.Tag := I;
        end;
      end
      else
        Rows[I].Clear;
    if RowCount - 1 > FixedRows then RowCount := RowCount - 1;
  end;
end;

destructor TStringGrid.Destroy;
begin
  Clear;
  inherited;
end;

procedure TStringGrid.DoCellEvent(const Data: PCellData; const EventType: TEventType);
begin
  if Assigned(FCellEvent) then FCellEvent(Data, EventType);
end;

procedure TStringGrid.EnableFormula(Sender: TObject);
var
  Button: TSpeedButton absolute Sender;
  Data: PCellData;
begin
  if FindCellData(Button.Tag, Data) then DoCellEvent(Data, etEnableFormula);
end;

procedure TStringGrid.EnableTracing(Sender: TObject);
var
  Button: TSpeedButton absolute Sender;
  Data: PCellData;
begin
  if FindCellData(Button.Tag, Data) then DoCellEvent(Data, etEnableTracing);
end;

function TStringGrid.FindCellData(const Index: Integer; out Data: PCellData): Boolean;
begin
  Data := CellData[Index];
  Result := Assigned(Data);
end;

function TStringGrid.GetCellData(Index: Integer): PCellData;
begin
  if Check(Index) then
    Result := PCellData(Rows[Index].Objects[ObjectColumn])
  else
    Result := nil;
end;

function TStringGrid.GetEmpty: Boolean;
begin
  Result := (RowCount = FixedRows + 1) and not Assigned(CellData[RowCount - 1]);
end;

function TStringGrid.GetFormula(Index: Integer): string;
begin
  if Check(Index) then
    Result := Rows[Index][CColumn]
  else
    Result := '';
end;

function TStringGrid.GetTracing(Index: Integer): string;
begin
  if Check(Index) then
    Result := Rows[Index][DColumn]
  else
    Result := '';
end;

procedure TStringGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Check then
    case Key of
      VK_RETURN, VK_ESCAPE: if EditorMode then EditorMode := False;
      VK_DELETE: Delete(Row);
    end;
end;

procedure TStringGrid.Loaded;
const
  FormulaText = 'Formula';
  TracingText = 'Tracing';
begin
  inherited;
  if Check then
  begin
    DefaultDrawing := False;
    DoubleBuffered := True;
    FInplaceList := TObjectList.Create;
    Cols[CColumn].Text := FormulaText;
    Cols[DColumn].Text := TracingText;
  end;
end;

procedure TStringGrid.Make(const Index: Integer);
const
  FormulaActiveText = 'Active';
  TracingActiveText = 'Tracing';
  RemoveText = 'Remove';
var
  Data: PCellData;
begin
  if Check and Check(Index) and not Assigned(CellData[Index]) then
  begin
    System.New(Data);
    ZeroMemory(Data, SizeOf(TCellData));
    CellData[Index] := Data;
    Data.A := TSpeedButton.Create(nil);
    FInplaceList.Add(Data.A);
    Data.A.AllowAllUp := True;
    SkinButton(Data.A);
    Data.A.Tag := Index;
    Data.A.GroupIndex := Index * GroupCount + 1;
    Data.A.Down := True;
    Data.A.OnClick := EnableFormula;
    Data.A.Caption := FormulaActiveText;
    Arrange(CellRect(AColumn, Index), Data.A);
    Data.A.Parent := Self;
    Data.B := TSpeedButton.Create(nil);
    FInplaceList.Add(Data.B);
    Data.B.AllowAllUp := True;
    SkinButton(Data.B);
    Data.B.Tag := Index;
    Data.B.GroupIndex := Index * GroupCount + 2;
    Data.B.Down := True;
    Data.B.OnClick := EnableTracing;
    Data.B.Caption := TracingActiveText;
    Arrange(CellRect(BColumn, Index), Data.B);
    Data.B.Parent := Self;
    Data.C := TSpeedButton.Create(nil);
    FInplaceList.Add(Data.C);
    SkinButton(Data.C);
    Data.C.Tag := Index;
    Data.C.OnClick := Remove;
    Data.C.Caption := RemoveText;
    Arrange(CellRect(EColumn, Index), Data.C);
    Data.C.Parent := Self;
  end;
end;

procedure TStringGrid.Make;
var
  I: Integer;
begin
  if Check then for I := FixedRows to RowCount - 1 do Make(I);
end;

procedure TStringGrid.Paint;
var
  I, J: Integer;
  S: string;
  Rect: TRect;
  Colors: TThemeColors;
begin
  Colors := DarkTheme.CurrentColors;
  inherited;
  if Check and not DefaultDrawing then
    for I := 0 to ColCount - 1 do for J := 0 to RowCount - 1 do
    begin
      S := Cols[I][J];
      Rect := CellRect(I, J);
      if J < FixedRows then
      begin
        Canvas.Brush.Color := Colors.Panel;
        Canvas.FillRect(Rect);
        Canvas.Font.Color := Colors.Muted;
        DrawText(Canvas.Handle, PChar(S), Length(S), Rect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
      end;
      Canvas.Brush.Color := Colors.Border;
      Canvas.FillRect(TRect.Create(Rect.Left, Rect.Bottom - 1, Rect.Right, Rect.Bottom));
      Canvas.FillRect(TRect.Create(Rect.Right - 1, Rect.Top, Rect.Right, Rect.Bottom));
    end;
end;

procedure TStringGrid.Remove(Sender: TObject);
begin
  PostMessage(Handle, WM_REMOVE, WPARAM(Sender), 0);
end;

procedure TStringGrid.ResizeColumn;
const
  ARatio = 0.075;
  BRatio = 0.075;
  CRatio = 0.175;
  DRatio = 0.600;
  ERatio = 0.075;
  Margin = 4;
var
  I: Integer;
begin
  if Check then
  begin
    I := ClientWidth - Margin;
    ColWidths[AColumn] := Round(I * ARatio) - GridLineWidth;
    ColWidths[BColumn] := Round(I * BRatio) - GridLineWidth;
    ColWidths[CColumn] := Round(I * CRatio) - GridLineWidth;
    ColWidths[DColumn] := Round(I * DRatio) - GridLineWidth;
    ColWidths[EColumn] := Round(I * ERatio) - GridLineWidth;
    Arrange;
  end;
end;

procedure TStringGrid.RowHeightsChanged;
begin
  inherited;
  if Check then Arrange;
end;

procedure TStringGrid.SetCellData(Index: Integer; const Value: PCellData);
begin
  if Check(Index) then Rows[Index].Objects[ObjectColumn] := Pointer(Value);
end;

procedure TStringGrid.SetFormula(Index: Integer; const Value: string);
begin
  if Check(Index) then Rows[Index][CColumn] := Value;
end;

procedure TStringGrid.SetTracing(Index: Integer; const Value: string);
begin
  if Check(Index) then Rows[Index][DColumn] := Value;
end;

procedure TStringGrid.TopLeftChanged;
begin
  inherited;
  Arrange;
end;

procedure TStringGrid.WMHScroll(var Message: TWMHScroll);
begin
  inherited;
  if Check then Arrange;
end;

procedure TStringGrid.WMRemove(var Message: TMessage);
var
  Button: TSpeedButton;
  I: Integer;
  Data: PCellData;
begin
  Button := TSpeedButton(Message.WParam);
  if Assigned(Button) then
    try
      I := Button.Tag;
      if FindCellData(I, Data) then
      begin
        DoCellEvent(Data, etDelete);
        if Assigned(Data.A) then FInplaceList.Remove(Data.A);
        if Assigned(Data.B) then FInplaceList.Remove(Data.B);
        if Assigned(Data.C) then FInplaceList.Remove(Data.C);
      end;
      Delete(I);
    finally
      FInplaceList.Remove(Button);
    end;
  ResizeColumn;
  Arrange;
end;

procedure TStringGrid.WMVScroll(var Message: TWMVScroll);
begin
  inherited;
  if Check then Arrange;
end;

procedure TMain.WndProc(var Message: TMessage);
begin
  inherited;
end;

function TMain.GetFileName: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  GetModuleFileName(HInstance, Buffer, Length(Buffer));
  Result := ChangeFileExt(ExtractFileName(Buffer), FileExt);
end;

function TMain.GetUserPath: string;
const
  AppData = 'APPDATA';
  Folder = 'GraphBuilder';
begin
  Result := Trim(GetEnvironmentVariable(AppData));
  if Result <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Result) + Folder);
    ForceDirectories(Result);
  end;
end;

function TMain.GetDecimalPlaces: Integer;
begin
  Result := Pos('.', FGraph.PrecisionFormat);
  if Result > 0 then Result := Length(FGraph.PrecisionFormat) - Result;
end;

procedure TMain.SetDecimalPlaces(const Value: Integer);
begin
  if Value > 0 then
    FGraph.PrecisionFormat := '0.' + DupeString('#', Value)
  else
    FGraph.PrecisionFormat := '0';
end;

procedure TMain.Load(const AFile: TMemIniFile);
type
  TConfig = record
    Visible, Correct, Tracing: Boolean;
  end;
var
  S, Item: string;
  A, B: Extended;
  List: TStringList;
  I, J: Integer;
  SArray: TArray<string>;
  Config: TConfig;
begin
  Clear;
  if AFile.ReadBool(PanelSection, LIdent, bL.Visible) then
    LShow.Execute
  else
    LHide.Execute;
  if AFile.ReadBool(PanelSection, BIdent, pB.Visible) then
    BShow.Execute
  else
    BHide.Execute;
  bL.VertScrollBar.Position := AFile.ReadInteger(LBoxSection, PositionIdent, bL.VertScrollBar.Position);
  S := AFile.ReadString(CSSection, CSIdent, GetEnumName(TypeInfo(TCoordinateSystem), Ord(FGraph.CS)));
  FGraph.CS := TCoordinateSystem(GetEnumValue(TypeInfo(TCoordinateSystem), S));
  A := AFile.ReadFloat(CenterSection, XIdent, FGraph.Offset.X);
  B := AFile.ReadFloat(CenterSection, YIdent, FGraph.Offset.Y);
  FGraph.Offset := PointD(A, B);
  FGraph.MaxX := AFile.ReadFloat(SizeSection, XIdent, FGraph.MaxX * 2) / 2;
  FGraph.MaxY := AFile.ReadFloat(SizeSection, YIdent, FGraph.MaxY * 2) / 2;
  FGraph.PolarMaxAngle := DegToRad(AFile.ReadFloat(SizeSection, PolarMaxAngleIdent,
    RadToDeg(FGraph.PolarMaxAngle)));
  FGraph.ShowGrid := AFile.ReadBool(GraphSection, GridIdent, FGraph.ShowGrid);
  FGraph.ShowAxis := AFile.ReadBool(GraphSection, AxisIdent, FGraph.ShowAxis);
  FGraph.Tracing := AFile.ReadBool(GraphSection, TracingIdent, FGraph.Tracing);
  FGraph.Overlap := AFile.ReadBool(GraphSection, OverlapIdent, FGraph.Overlap);
  FGraph.Extreme := AFile.ReadBool(GraphSection, ExtremeIdent, FGraph.Extreme);
  FGraph.HighPrecision := AFile.ReadBool(GraphSection, HighPrecisionIdent, FGraph.HighPrecision);
  FGraph.PrecisionFormat := AFile.ReadString(GraphSection, PrecisionFormatIdent, FGraph.PrecisionFormat);
  FGraph.Antialias := AFile.ReadBool(LineSection, AntialiasIdent, FGraph.Antialias);
  FGraph.MultiColor := AFile.ReadBool(LineSection, MultiColorIdent, FGraph.MultiColor);
  FGraph.Autoquality := AFile.ReadBool(LineSection, AutoqualityIdent, FGraph.Autoquality);
  FGraph.GraphPen.Color := StringToColor(AFile.ReadString(LineSection, ColorIdent,
    ColorToString(FGraph.GraphPen.Color)));
  FGraph.Accuracy := AFile.ReadInteger(LineSection, AccuracyIdent, FGraph.Accuracy);
  FGraph.Quality := AFile.ReadInteger(LineSection, QualityIdent, FGraph.Quality);
  FGraph.GraphPen.Width := AFile.ReadInteger(LineSection, PenWidthIdent, FGraph.GraphPen.Width);
  FGraph.Sign := AFile.ReadBool(SignSection, SignIdent, FGraph.Sign);
  FGraph.SignBlendValue := AFile.ReadInteger(SignSection, TransparencyIdent, FGraph.SignBlendValue);
  S := AFile.ReadString(SignSection, LayoutIdent, GetEnumName(TypeInfo(TLayoutType), Ord(FGraph.SignLayout)));
  FGraph.SignLayout := TLayoutType(GetEnumValue(TypeInfo(TLayoutType), S));
  FGraph.SignMargin := AFile.ReadInteger(SignSection, MarginIdent, FGraph.SignMargin);
  FGraph.SignFont.Name := AFile.ReadString(SignSection, FontNameIdent, FGraph.SignFont.Name);
  FGraph.SignFont.Charset := AFile.ReadInteger(SignSection, FontCharsetIdent, FGraph.SignFont.Charset);
  FGraph.SignFont.Color := StringToColor(AFile.ReadString(SignSection, FontColorIdent,
    ColorToString(FGraph.SignFont.Color)));
  FGraph.SignFont.Height := AFile.ReadInteger(SignSection, FontHeightIdent, FGraph.SignFont.Height);
  FGraph.SignFont.Size := AFile.ReadInteger(SignSection, FontSizeIdent, FGraph.SignFont.Size);
  FGraph.SignFont.Style := TFontStyles(Byte(AFile.ReadInteger(SignSection, FontStyleIdent,
    Byte(FGraph.SignFont.Style))));
  FGraph.HSpacing := AFile.ReadFloat(GridSection, HSpacingIdent, FGraph.HSpacing);
  FGraph.VSpacing := AFile.ReadFloat(GridSection, VSpacingIdent, FGraph.VSpacing);
  FGraph.ThreadWorkTime := AFile.ReadInteger(CalcSection, CalcTimeIdent, FGraph.ThreadWorkTime);
  FGraph.OverlapMaxDepth := AFile.ReadInteger(CalcSection, OverlapMaxDepthIdent, FGraph.OverlapMaxDepth);
  FGraph.OverlapMaxTime := AFile.ReadInteger(CalcSection, OverlapMaxTimeIdent, FGraph.OverlapMaxTime);
  FGraph.MarkSpacing := AFile.ReadInteger(CalcSection, MarkSpacingIdent, FGraph.MarkSpacing);
  FPageKeepRatio := AFile.ReadBool(PageSection, KeepRatioIdent, FPageKeepRatio);
  FPagePenColor := AFile.ReadString(PageSection, PenColorIdent, FPagePenColor);
  FGraph.MaxZoom := AFile.ReadFloat(ZoomSection, MaxIdent, FGraph.MaxZoom);
  FGraph.MinZoom := AFile.ReadFloat(ZoomSection, MinIdent, FGraph.MinZoom);
  FGraph.ZoomInFactor := AFile.ReadFloat(ZoomSection, InFactorIdent, FGraph.ZoomInFactor);
  FGraph.ZoomOutFactor := AFile.ReadFloat(ZoomSection, OutFactorIdent, FGraph.ZoomOutFactor);
  if AFile.SectionExists(FormulaSection) then
  begin
    List := TStringList.Create;
    try
      AFile.ReadSectionValues(FormulaSection, List);
      BeginUpdate;
      try
        for I := 0 to List.Count - 1 do
        begin
          S := Decode(Trim(List.Names[I]));
          if S <> '' then
          begin
            FillChar(Config, SizeOf(TConfig), 0);
            if Split(Trim(List.ValueFromIndex[I]), Comma, SArray, False) then
              try
                for J := Low(SArray) to High(SArray) do
                begin
                  Item := SArray[J];
                  if Same(Item, FormulaVisible) then
                    Config.Visible := True
                  else
                    if Same(Item, FormulaCorrect) then
                      Config.Correct := True
                  else
                    if Same(Item, FormulaTracing) then Config.Tracing := True;
                end;
              finally
                SArray := nil;
              end;
            AddFormula(S, Config.Visible, Config.Correct, Config.Tracing);
          end;
        end;
      finally
        EndUpdate;
      end;
      if not FGraph.Silent then FGraph.Build;
      gFormula.ResizeColumn;
      gFormula.Invalidate;
    finally
      List.Free;
    end;
  end;
  if AFile.SectionExists(FLSection) then
  begin
    List := TStringList.Create;
    try
      AFile.ReadSectionValues(FLSection, List);
      for I := 0 to List.Count - 1 do
      begin
        J := GetEnumValue(TypeInfo(TCoordinateSystem), List.ValueFromIndex[I]);
        S := Decode(Trim(List.Names[I])) + FFormulaList.NameValueSeparator + IntToStr(J);
        if FFormulaList.IndexOf(S) < 0 then FFormulaList.Add(S);
      end;
      LoadFormulaList;
    finally
      List.Free;
    end;
  end;
  FGraph.Invalidate;
end;

procedure TMain.Open;
begin
  BeginUpdate;
  try
    GRectangular.Checked := FGraph.CS = csRectangular;
    GPolar.Checked := FGraph.CS = csPolar;
    eCenterX.Text := FloatToStr(-FGraph.Offset.X);
    eCenterY.Text := FloatToStr(-FGraph.Offset.Y);
    eMaxX.Text := FloatToStr(FGraph.MaxX * 2);
    eMaxY.Text := FloatToStr(FGraph.MaxY * 2);
    ePolarMaxAngle.Text := FloatToStr(RadToDeg(FGraph.PolarMaxAngle));
    lPolarMaxAngle.Enabled := GPolar.Checked;
    ePolarMaxAngle.Enabled := GPolar.Checked;
    GGrid.Checked := FGraph.ShowGrid;
    GAxis.Checked := FGraph.ShowAxis;
    GTracing.Checked := FGraph.Tracing;
    GOverlap.Checked := FGraph.Overlap;
    GExtreme.Checked := FGraph.Extreme;
    GAntialias.Checked := FGraph.Antialias;
    GMulticolor.Checked := FGraph.MultiColor;
    GAutoquality.Checked := FGraph.Autoquality;
    GHighPrecision.Checked := FGraph.HighPrecision;
    cDecimalPlaces.Position := DecimalPlaces;
    cAccuracy.Position := FGraph.Accuracy;
    bQuality.Position := FGraph.Quality;
    cQuality.Position := FGraph.Quality;
    cPenWidth.Position := FGraph.GraphPen.Width;
    GSign.Checked := FGraph.Sign;
    cBlendValue.Position := FGraph.SignBlendValue;
    bLayout.ItemIndex := Ord(FGraph.SignLayout);
    cMargin.Position := FGraph.SignMargin;
    eHSpacing.Text := FloatToStr(FGraph.HSpacing);
    eVSpacing.Text := FloatToStr(FGraph.VSpacing);
    eCalcTime.Text := IntToStr(FGraph.ThreadWorkTime);
    eOverlapMaxTime.Text := IntToStr(FGraph.OverlapMaxTime);
    eOverlapMaxDepth.Text := IntToStr(FGraph.OverlapMaxDepth);
    eZoomInFactor.Text := FloatToStr(FGraph.ZoomInFactor);
    eZoomOutFactor.Text := FloatToStr(FGraph.ZoomOutFactor);
  finally
    EndUpdate;
  end;
end;

procedure TMain.Save(const AFile: TMemIniFile; const FL: Boolean; const CS: PCoordinateSystem);
const
  Format = ffGeneral;
  Precision = 15;
  Digits = 18;
var
  S: string;
  I, J: Integer;
  B: TTextBuilder;
begin
  AFile.WriteBool(PanelSection, LIdent, bL.Visible);
  AFile.WriteBool(PanelSection, BIdent, pB.Visible);
  AFile.WriteInteger(LBoxSection, PositionIdent, bL.VertScrollBar.Position);
  if Assigned(CS) then
    AFile.WriteString(CSSection, CSIdent, GetEnumName(TypeInfo(TCoordinateSystem), Ord(CS^)))
  else
    AFile.WriteString(CSSection, CSIdent, GetEnumName(TypeInfo(TCoordinateSystem), Ord(FGraph.CS)));
  S := FloatToStrF(FGraph.Offset.X, Format, Precision, Digits);
  AFile.WriteString(CenterSection, XIdent, S);
  S := FloatToStrF(FGraph.Offset.Y, Format, Precision, Digits);
  AFile.WriteString(CenterSection, YIdent, S);
  S := FloatToStrF(FGraph.MaxX * 2, Format, Precision, Digits);
  AFile.WriteString(SizeSection, XIdent, S);
  S := FloatToStrF(RadToDeg(FGraph.PolarMaxAngle), Format, Precision, Digits);
  AFile.WriteString(SizeSection, PolarMaxAngleIdent, S);
  S := FloatToStrF(FGraph.MaxY * 2, Format, Precision, Digits);
  AFile.WriteString(SizeSection, YIdent, S);
  AFile.WriteBool(GraphSection, GridIdent, FGraph.ShowGrid);
  AFile.WriteBool(GraphSection, AxisIdent, FGraph.ShowAxis);
  AFile.WriteBool(GraphSection, TracingIdent, FGraph.Tracing);
  AFile.WriteBool(GraphSection, OverlapIdent, FGraph.Overlap);
  AFile.WriteBool(GraphSection, ExtremeIdent, FGraph.Extreme);
  AFile.WriteBool(GraphSection, HighPrecisionIdent, FGraph.HighPrecision);
  AFile.WriteString(GraphSection, PrecisionFormatIdent, FGraph.PrecisionFormat);
  AFile.WriteBool(LineSection, AntialiasIdent, FGraph.Antialias);
  AFile.WriteBool(LineSection, MultiColorIdent, FGraph.MultiColor);
  AFile.WriteBool(LineSection, AutoqualityIdent, FGraph.Autoquality);
  AFile.WriteString(LineSection, ColorIdent, ColorToString(FGraph.GraphPen.Color));
  AFile.WriteInteger(LineSection, AccuracyIdent, FGraph.Accuracy);
  AFile.WriteInteger(LineSection, QualityIdent, FGraph.Quality);
  AFile.WriteInteger(LineSection, PenWidthIdent, FGraph.GraphPen.Width);
  AFile.WriteBool(SignSection, SignIdent, FGraph.Sign);
  AFile.WriteInteger(SignSection, TransparencyIdent, FGraph.SignBlendValue);
  AFile.WriteString(SignSection, LayoutIdent, GetEnumName(TypeInfo(TLayoutType), Ord(FGraph.SignLayout)));
  AFile.WriteInteger(SignSection, MarginIdent, FGraph.SignMargin);
  AFile.WriteString(SignSection, FontNameIdent, FGraph.SignFont.Name);
  AFile.WriteInteger(SignSection, FontCharsetIdent, FGraph.SignFont.Charset);
  AFile.WriteString(SignSection, FontColorIdent, ColorToString(FGraph.SignFont.Color));
  AFile.WriteInteger(SignSection, FontHeightIdent, FGraph.SignFont.Height);
  AFile.WriteInteger(SignSection, FontSizeIdent, FGraph.SignFont.Size);
  AFile.WriteInteger(SignSection, FontStyleIdent, Byte(FGraph.SignFont.Style));
  AFile.WriteFloat(GridSection, HSpacingIdent, FGraph.HSpacing);
  AFile.WriteFloat(GridSection, VSpacingIdent, FGraph.VSpacing);
  AFile.WriteInteger(CalcSection, CalcTimeIdent, FGraph.ThreadWorkTime);
  AFile.WriteInteger(CalcSection, OverlapMaxDepthIdent, FGraph.OverlapMaxDepth);
  AFile.WriteInteger(CalcSection, OverlapMaxTimeIdent, FGraph.OverlapMaxTime);
  AFile.WriteInteger(CalcSection, MarkSpacingIdent, FGraph.MarkSpacing);
  AFile.WriteBool(PageSection, KeepRatioIdent, FPageKeepRatio);
  AFile.WriteString(PageSection, PenColorIdent, FPagePenColor);
  AFile.WriteFloat(ZoomSection, MaxIdent, FGraph.MaxZoom);
  AFile.WriteFloat(ZoomSection, MinIdent, FGraph.MinZoom);
  AFile.WriteFloat(ZoomSection, InFactorIdent, FGraph.ZoomInFactor);
  AFile.WriteFloat(ZoomSection, OutFactorIdent, FGraph.ZoomOutFactor);
  AFile.EraseSection(FormulaSection);
  B := TTextBuilder.Create;
  try
    for I := 0 to FGraph.Formula.Count - 1 do
    begin
      if FGraph.Formula.Visible[I] then B.Append(FormulaVisible, Comma);
      if FGraph.Formula.Correct[I] then B.Append(FormulaCorrect, Comma);
      if FGraph.Formula.Tracing[I] then B.Append(FormulaTracing, Comma);
      AFile.WriteString(FormulaSection, Encode(FGraph.Formula[I]), B.Text);
      B.Clear;
    end;
  finally
    B.Free;
  end;
  AFile.EraseSection(FLSection);
  if FL then
  begin
    SaveFormulaList;
    for I := 0 to FFormulaList.Count - 1 do
      if TryStrToInt(FFormulaList.ValueFromIndex[I], J) then
        AFile.WriteString(FLSection, Encode(FFormulaList.Names[I]),
          GetEnumName(TypeInfo(TCoordinateSystem), J));
  end;
end;

function TMain.LoadFile(const AFile: TMemIniFile; const AName: string): Boolean;
var
  I: Integer;
  List: TStringList;
begin
  Result := FManager.Find(AName, I);
  if Result then
  begin
    FManager.Item[FManager.CommonNameList, I].Stream.Position := 0;
    List := TStringList.Create;
    try
      List.LoadFromStream(FManager.Item[FManager.CommonNameList, I].Stream, TEncoding.Unicode);
      AFile.SetStrings(List);
    finally
      List.Free;
    end;
  end;
end;

procedure TMain.SaveFile(const AFile: TMemIniFile; const AName: string);
var
  List: TStringList;
  Item: PItem;
begin
  List := TStringList.Create;
  try
    AFile.GetStrings(List);
    if FManager.Find(AName, Item) then
    begin
      Item.Stream.Clear;
      List.SaveToStream(Item.Stream, TEncoding.Unicode);
    end
    else
      FManager.ImportText(AName, List.Text);
  finally
    List.Free;
  end;
end;

procedure TMain.LoadFormulaList;
const
  Examples: array[0..9] of string = ('Sin(X)', 'X * X - 2', '1 / X',
    'Sin(X) / X', 'Exp(- X * X)', 'Abs(X) - 1', 'X * Sin(1 / X)',
    'Sqrt(Abs(X))', 'Ln(Abs(X))', 'Tan(X)');
var
  I, J: Integer;
begin
  bFormula.Clear;
  for I := 0 to FFormulaList.Count - 1 do
    if TryStrToInt(Trim(FFormulaList.ValueFromIndex[I]), J) and (TCoordinateSystem(J) = FGraph.CS) then
      bFormula.Items.Add(Trim(FFormulaList.Names[I]));
  if bFormula.Items.Count = 0 then
    for I := Low(Examples) to High(Examples) do bFormula.Items.Add(Examples[I]);
end;

procedure TMain.ApplyEditorTheme;
var
  Kind: TThemeKind;
begin
  if Assigned(Npp) and Npp.DarkMode then
    Kind := tkDark
  else
    Kind := tkLight;
  DarkTheme.ApplyTheme(Self, FGraph, Kind);
  if Assigned(FGraph) and (FGraph.Formula.Count > 0) then FGraph.Build;
end;

procedure TMain.Suggest(const Formula: string);
const
  LengthLimit = 200;
var
  Text: string;
begin
  Text := Trim(Formula);
  if (Text = '') or (Length(Text) > LengthLimit) or (Pos(#10, Text) > 0) or (Pos(#13, Text) > 0) then
    Exit;
  bFormula.Text := Text;
  bFormula.SelectAll;
end;

procedure TMain.SaveFormulaList;
var
  I: Integer;
  S: string;
begin
  for I := 0 to bFormula.Items.Count - 1 do
  begin
    S := Trim(bFormula.Items[I]);
    if FFormulaList.IndexOfName(S) < 0 then FFormulaList.Values[S] := IntToStr(Ord(FGraph.CS));
  end;
end;

function TMain.LoadState(const AName: string): Boolean;
var
  AFile: TMemIniFile;
begin
  AFile := TMemIniFile.Create('');
  try
    Result := LoadFile(AFile, AName);
    Load(AFile);
  finally
    AFile.Free;
  end;
end;

function TMain.HasState(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := FManager.Find(AName, I);
end;

procedure TMain.CopyState(const AFrom, ATo: string);
var
  AFile: TMemIniFile;
begin
  if not HasState(AFrom) then Exit;
  AFile := TMemIniFile.Create('');
  try
    if LoadFile(AFile, AFrom) then SaveFile(AFile, ATo);
  finally
    AFile.Free;
  end;
end;

procedure TMain.DropState(const AName: string);
var
  I: Integer;
begin
  if FManager.Find(AName, I) then FManager.DeleteItem(I);
end;

procedure TMain.SaveState(const AName: string; const FL: Boolean; const CS: PCoordinateSystem);
var
  AFile: TMemIniFile;
begin
  AFile := TMemIniFile.Create('');
  try
    Save(AFile, FL, CS);
    SaveFile(AFile, AName);
  finally
    AFile.Free;
  end;
end;

procedure TMain.BeginUpdate;
begin
  InterlockedIncrement(FUpdateCount);
end;

procedure TMain.EndUpdate;
begin
  InterlockedDecrement(FUpdateCount);
end;

function TMain.AddFormula(const Text: string; const Visible, Correct, Tracing: Boolean): Integer;
var
  I: Integer;
  Data: PCellData;
begin
  if Assigned(FGraph) and (FGraph.Formula.IndexOf(Text) < 0) then
  begin
    FGraph.Stop;
    Result := FGraph.Formula.Add(Text, Visible, Correct, Tracing);
    BeginUpdate;
    try
      I := gFormula.Add;
      if gFormula.FindCellData(I, Data) then
      begin
        Data.FormulaIndex := Result;
        Data.A.Down := Visible;
        Data.B.Down := Tracing;
        gFormula.Formula[I] := FGraph.Formula[Result];
      end;
    finally
      EndUpdate;
    end;
    if FUpdateCount = 0 then gFormula.ResizeColumn;
    pCalc.Visible := Graph.Formula.ActiveCount = 1;
    exChange(Self);
  end
  else
    Result := -1;
end;

procedure TMain.Clear;
begin
  BeginUpdate;
  try
    FGraph.Clear;
    gFormula.Clear;
  finally
    EndUpdate;
  end;
end;

procedure TMain.MouseWheelHandler(var Message: TMessage);
var
  Point: TPoint;
begin
  Point := SmallPointToPoint(SmallPoint(LongWord(Message.LParam)));
  if Assigned(FGraph) and FGraph.Showing and PtInRect(FGraph.ClientRect, FGraph.ScreenToClient(Point)) then
  begin
    FGraph.Perform(CM_MOUSEWHEEL, Message.WParam, Message.LParam);
    Message.Result := 1;
  end
  else
    inherited;
end;

constructor TMain.Create(AOwner: TNppForm; DlgId: Integer);
begin
  inherited;
end;

procedure TMain.SyncTitle;
const
  Buttons = 72;
begin
  if FTitleBase = '' then Exit;
  Caption := FitTitle(FTitleBase, FOpenKeys, FGrabKeys, ClientWidth - Buttons, Canvas.TextWidth);
end;

procedure TMain.Resize;
begin
  inherited;
  SyncTitle;
end;

constructor TMain.Create(NppParent: TNppPlugin; DlgId: Integer);
begin
  inherited;
  FTitleBase := Caption;
  if Assigned(NppParent) then
  begin
    FOpenKeys := Trim(NppParent.ShortcutText(DlgId));
    FGrabKeys := Trim(NppParent.ShortcutText(DlgId + 1));
  end;
  SyncTitle;
end;

procedure TMain.Next(const Control: TWinControl; const Forward: Boolean);
begin
  if Assigned(Control) then SelectNext(Control, Forward, True);
end;

procedure TMain.CellEvent(const Data: PCellData; const EventType: TEventType);
begin
  if (FUpdateCount = 0) and Assigned(Data) and FGraph.Formula.CheckIndex(Data.FormulaIndex) then
  begin
    FGraph.Stop;
    case EventType of
      etDelete:
        begin
          FGraph.Formula.Delete(Data.FormulaIndex);
          FGraph.Build;
        end;
      etEnableFormula:
        begin
          gFormula.EditorMode := False;
          FGraph.Formula.Visible[Data.FormulaIndex] := Data.A.Down;
          FGraph.Build;
          gFormula.Invalidate;
        end;
      etEnableTracing:
        begin
          gFormula.EditorMode := False;
          FGraph.Formula.Tracing[Data.FormulaIndex] := Data.B.Down;
        end;
    end;
    pCalc.Visible := Graph.Formula.ActiveCount = 1;
    eXChange(Self);
  end;
end;

procedure TMain.OffsetChange(Sender: TObject);
begin
  BeginUpdate;
  try
    eCenterX.Text := FloatToStr(-FGraph.Offset.X);
    eCenterY.Text := FloatToStr(-FGraph.Offset.Y);
    eMaxX.Text := FloatToStr(FGraph.MaxX * 2);
    eMaxY.Text := FloatToStr(FGraph.MaxY * 2);
  finally
    EndUpdate;
  end;
end;

procedure TMain.TraceDone(Sender: TObject);
var
  I, J: Integer;
  S: string;
begin
  for I := gFormula.FixedRows to gFormula.RowCount - 1 do
  begin
    J := FTraceList.IndexOfName(Encode(gFormula.Formula[I]));
    if J < 0 then
      gFormula.Tracing[I] := ''
    else begin
      S := Trim(Decode({$IFDEF DELPHI_7}FTraceList.ValueFromIndex[J]{$ELSE}GetValueFromIndex(FTraceList,
        J){$ENDIF}));
      if not TextUtils.SameText(S, Trim(gFormula.Tracing[I])) then gFormula.Tracing[I] := S;
    end;
  end;
  FTraceList.Clear;
end;

procedure TMain.Trace(const Formula, Tracing: string);
type
  TCode = record
    Formula, Tracing: string;
  end;
var
  Code: TCode;
  I: Integer;
begin
  Code.Formula := Encode(Formula);
  Code.Tracing := Encode(Tracing);
  I := FTraceList.IndexOfName(Code.Formula);
  if I < 0 then
    FTraceList.Add(Code.Formula + TextConsts.Equal + Code.Tracing)
  else
    {$IFDEF DELPHI_7}FTraceList.ValueFromIndex[I] := Code.Tracing{$ELSE}SetValueFromIndex(FTraceList, I, Code.Tracing){$ENDIF};
end;

procedure TMain.RectangularTrace(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD);
const
  Tracing = 'X: %s, Y: %s';
begin
  Trace(FGraph.Formula[FormulaIndex],
    Format(Tracing, [FormatFloat(FGraph.FloatFormat(FGraph.XFormat), Point.X), FormatFloat(FGraph.FloatFormat(FGraph.YFormat), Point.Y)]));
end;

procedure TMain.PolarTrace(Sender: TObject; const FormulaIndex: Integer; const Angle: array of Extended;
  const Point: array of TPointD);
const
  Tracing = 'A: %s, X: %s, Y: %s';
var
  B: TTextBuilder;
  I: Integer;
begin
  B := TTextBuilder.Create;
  try
    for I := Low(Angle) to High(Angle) do
      B.Append(
        Format(
          Tracing,
          [
            FormatFloat(
              FGraph.FloatFormat(FGraph.AngleFormat),
              RadToDeg(Angle[I])
            ),
            FormatFloat(
              FGraph.FloatFormat(FGraph.XFormat),
              Point[I].X
            ),
            FormatFloat(
              FGraph.FloatFormat(FGraph.YFormat),
              Point[I].Y
            )
          ]
        ),
        Space + Pipe + Space
      );
    Trace(FGraph.Formula[FormulaIndex], B.Text);
  finally
    B.Free;
  end;
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FGraph.Stop;
  Action := caFree;
end;

procedure TMain.FormCreate(Sender: TObject);
var
  I: TCoordinateSystem;
  S: string;
begin
  NppDefaultDockingMask := DWS_DF_FLOATING;
  KeyPreview := True;
  OnFloat := FormFloat;
  OnDock := FormDock;
  bL.VertScrollBar.Range := pL.Height;
  bL.AdjustSize;
  LShow.Visible := not bL.Visible;
  LHide.Visible := not LShow.Visible;
  BShow.Visible := not pB.Visible;
  BHide.Visible := not BShow.Visible;
  FManager := TBlobManager.Create(Self);
  FManager.Compression := False;
  FFormulaList := TFastList.Create;
  FFormulaList.IndexTypes := [ttNameValue, ttName];
  FTraceList := TFastList.Create;
  FTraceList.IndexTypes := [ttNameValue, ttName];
  FGraph := TGraph.Create(Self);
  FGraph.Name := GraphName;
  FGraph.OnOffsetChange := OffsetChange;
  FGraph.OnTraceDone := TraceDone;
  FGraph.OnRectangularTrace := RectangularTrace;
  FGraph.OnPolarTrace := PolarTrace;
  FGraph.Parent := pGraph;
  FGraph.Align := alClient;
  SeedPageDefaults(FGraph);
  gFormula.CellEvent := CellEvent;
  for I := Low(TCoordinateSystem) to High(TCoordinateSystem) do
    SaveState(GetEnumName(TypeInfo(TCoordinateSystem), Ord(I)), False, @I);
  S := UserPath + FileName;
  if FileExists(S) then
  begin
    try
      FManager.LoadFromFile(S);
    except
    end;
    B0.Checked := Assigned(FManager.Find(B0.Name));
    B1.Checked := Assigned(FManager.Find(B1.Name));
    B2.Checked := Assigned(FManager.Find(B2.Name));
    B3.Checked := Assigned(FManager.Find(B3.Name));
    B4.Checked := Assigned(FManager.Find(B4.Name));
    B5.Checked := Assigned(FManager.Find(B5.Name));
    B6.Checked := Assigned(FManager.Find(B6.Name));
    B7.Checked := Assigned(FManager.Find(B7.Name));
    B8.Checked := Assigned(FManager.Find(B8.Name));
    B9.Checked := Assigned(FManager.Find(B9.Name));
    LoadState(FGraph.Name);
  end;
  Open;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
  SaveState(FGraph.Name, True);
  try
    FManager.SaveToFile(UserPath + FileName);
  except
  end;
  FTraceList.Free;
  Main := nil;
end;

procedure TMain.FormHide(Sender: TObject);
begin
  inherited;
  SendMessage(Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, CmdID, 0);
  Close;
end;

type
  TControlDynArray = array of TControl;

function CCompare(const AIndex, BIndex: Integer; const Target: Pointer;
  const Data: Pointer = nil): TValueRelationship;
var
  ControlArray: TControlDynArray absolute Target;
begin
  Result := CompareValue(ControlArray[AIndex].Tag, ControlArray[BIndex].Tag);
end;

procedure TMain.SGResize(Sender: TObject);
const
  StartWidth = 100;
  RealignTag = 100;
var
  I, J: Integer;
  Order: TControlDynArray;
begin
  inherited;
  gFormula.ResizeColumn;
  try
    J := 0;
    for I := 0 to pFormula.ControlCount - 1 do
      if pFormula.Controls[I].Tag >= 0 then
      begin
        Inc(J, pFormula.Controls[I].Width);
        if pFormula.Controls[I].Tag >= RealignTag then
          Add(TNativeIntDynArray(Order), NativeInt(pFormula.Controls[I]));
      end;
    J := pFormula.ClientWidth - J;
    if J > StartWidth then
    begin
      bFormula.ClientWidth := J;
      QSort(Order, Low(Order), High(Order), CCompare, NativeIntExchange);
      J := 0;
      for I := High(Order) downto Low(Order) do
      begin
        Order[I].Left := pFormula.ClientWidth - Order[I].Width - J;
        Inc(J, Order[I].Width);
      end;
    end;
  finally
    Order := nil;
  end;
  bFormula.Invalidate;
  gFormula.Invalidate;
end;

procedure TMain.FormShow(Sender: TObject);
var
  I: Integer;
begin
  inherited;
  for I := 0 to AM.ActionCount - 1 do AM.Actions[I].Update;
  SendMessage(Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, CmdID, 1);
  SGResize(Sender);
end;

procedure TMain.FormDock(Sender: TObject);
begin
  SendMessage(Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, CmdID, 1);
end;

procedure TMain.FormFloat(Sender: TObject);
begin
  SendMessage(Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, CmdID, 1);
end;

procedure TMain.GDrawExecute(Sender: TObject);
var
  I: Integer;
  S: string;
begin
  Screen.Cursor := crHourGlass;
  try
    gFormula.EditorMode := False;
    I := AddFormula(Trim(bFormula.Text), True, True, True);
    try
      FGraph.Build;
      if (I >= 0) and FGraph.Formula.Correct[I] then
      begin
        S := FGraph.Parser.ScriptToString(FGraph.SA[FGraph.Formula.Data[I].ScriptIndex]);
        if bFormula.Items.IndexOf(S) < 0 then bFormula.Items.Add(S);
      end;
    except
      on E: Exception do Clear;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TMain.GGridExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.ShowGrid := not FGraph.ShowGrid;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GAxisExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.ShowAxis := not FGraph.ShowAxis;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GTracingExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Tracing := not FGraph.Tracing;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GOverlapExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Overlap := not FGraph.Overlap;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GExtremeExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Extreme := not FGraph.Extreme;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GAntialiasExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Antialias := not FGraph.Antialias;
    FGraph.Invalidate;
  end;
end;

procedure TMain.GMulticolorExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.MultiColor := not FGraph.MultiColor;
    FGraph.Invalidate;
    gFormula.Invalidate;
  end;
end;

procedure TMain.GAutoqualityExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.AutoQuality := not FGraph.AutoQuality;
    FGraph.Build;
  end;
end;

procedure TMain.GHighPrecisionExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.HighPrecision := not FGraph.HighPrecision;
    FGraph.Build;
  end;
end;

procedure TMain.GSignExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Sign := not FGraph.Sign;
    FGraph.Build;
  end;
end;

procedure TMain.GCopyExecute(Sender: TObject);
var
  List: TStringList;
  AFile: TMemIniFile;
  Stream: TMemoryStream;
  I: Integer;
begin
  if Assigned(FGraph) then
  begin
    List := TStringList.Create;
    try
      AFile := TMemIniFile.Create('');
      try
        Save(AFile, False);
        AFile.GetStrings(List);
      finally
        AFile.Free;
      end;
      Stream := TMemoryStream.Create;
      try
        List.SaveToStream(Stream);
        Compress(Stream);
        I := NumberUtils.GetHashCode(Stream.Memory, Stream.Size);
        Stream.Position := Stream.Size;
        Stream.Write(I, SizeOf(Integer));
        Parse(Stream, List, DefaultCharCount);
      finally
        Stream.Free;
      end;
      CopyToClipboard(Application.Handle, List.Text);
    finally
      List.Free;
    end;
  end;
end;

procedure TMain.GPasteExecute(Sender: TObject);
var
  S: string;
  List: TStringList;
  Stream: TMemoryStream;
  I, J: Integer;
  AFile: TMemIniFile;
begin
  if Assigned(FGraph) and PasteFromClipboard(Application.Handle, S) then
    try
      List := TStringList.Create;
      try
        List.Text := S;
        Stream := TMemoryStream.Create;
        try
          if Parse(List, Stream) then
          begin
            J := Stream.Size - SizeOf(Integer);
            Stream.Position := J;
            Stream.Read(I, SizeOf(Integer));
            Stream.Size := J;
            J := NumberUtils.GetHashCode(Stream.Memory, Stream.Size);
            if I = J then
            begin
              Decompress(Stream);
              Stream.Position := 0;
              List.LoadFromStream(Stream);
            end
            else
              Abort;
          end
          else
            Abort;
        finally
          Stream.Free;
        end;
        SaveState(GetEnumName(TypeInfo(TCoordinateSystem), Ord(FGraph.CS)), False);
        SaveFormulaList;
        AFile := TMemIniFile.Create('');
        try
          AFile.SetStrings(List);
          Load(AFile);
          Open;
        finally
          AFile.Free;
        end;
      finally
        List.Free;
      end;
    except
      FGraph.ErrorMessage := ClipboardError;
      FGraph.Invalidate;
    end;
end;

procedure TMain.GSignFontExecute(Sender: TObject);
begin
  FD.Font.Assign(FGraph.SignFont);
  if FD.Execute then
  begin
    FGraph.SignFont.Assign(FD.Font);
    FGraph.Invalidate;
  end;
end;

procedure TMain.GClearExecute(Sender: TObject);
var
  I, J: Integer;
begin
  if Assigned(FGraph) then
  begin
    gFormula.EditorMode := False;
    Clear;
    bFormula.Clear;
    for I := FFormulaList.Count - 1 downto 0 do
      if TryStrToInt(FFormulaList.ValueFromIndex[I], J) and (TCoordinateSystem(J) = FGraph.CS) then
        FFormulaList.Delete(I);
    FGraph.Invalidate;
    gFormula.ResizeColumn;
    gFormula.Invalidate;
  end;
end;

procedure TMain.GRefreshExecute(Sender: TObject);
begin
  if Assigned(FGraph) then FGraph.Invalidate;
end;

procedure TMain.GColorExecute(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    CD.Color := FGraph.GraphPen.Color;
    if CD.Execute then
    begin
      FGraph.GraphPen.Color := CD.Color;
      FGraph.Invalidate;
    end;
  end;
end;

procedure TMain.GPrintExecute(Sender: TObject);
var
  pvaIn, pvaOut: OleVariant;
begin
  WB.ControlInterface.ExecWB(OLECMDID_PRINT, OLECMDEXECOPT_PROMPTUSER, pvaIn, pvaOut);
end;

procedure TMain.GPrintUpdate(Sender: TObject);
begin
  GPrint.Enabled := (PC.ActivePage = pReport) and FReportLoaded;
end;

procedure TMain.LShowExecute(Sender: TObject);
begin
  LShow.Visible := False;
  LHide.Visible := not LShow.Visible;
  bL.Visible := LHide.Visible;
  bL.AdjustSize;
end;

procedure TMain.LHideExecute(Sender: TObject);
begin
  LHide.Visible := False;
  LShow.Visible := not LHide.Visible;
  bL.Visible := LHide.Visible;
end;

procedure TMain.BShowExecute(Sender: TObject);
begin
  BShow.Visible := False;
  BHide.Visible := not BShow.Visible;
  pB.Visible := BHide.Visible;
  Splitter.Top := Height - pB.Height;
  gFormula.ResizeColumn;
end;

procedure TMain.BHideExecute(Sender: TObject);
begin
  BHide.Visible := False;
  BShow.Visible := not BHide.Visible;
  pB.Visible := BHide.Visible;
end;

procedure TMain.BookmarkExecute(Sender: TObject);
var
  Action: TAction absolute Sender;
  Busy, Drop, Over: Boolean;
begin
  Busy := HasState(Action.Name);
  Drop := GetKeyState(VK_SHIFT) < 0;
  Over := GetKeyState(VK_CONTROL) < 0;
  if Busy and Drop then
    DropState(Action.Name)
  else if Busy and not Over then
  begin
    gFormula.EditorMode := False;
    PC.ActivePage := pGraph;
    LoadState(Action.Name);
    Open;
  end
  else if not (Drop and not Busy) then
    SaveState(Action.Name, False);
  Action.Checked := HasState(Action.Name);
end;

procedure TMain.bFormulaKeyPress(Sender: TObject; var Key: Char);
begin
  if Assigned(FGraph) and (Key = Chr(VK_RETURN)) then
  begin
    Key := #0;
    GDraw.Execute;
  end;
end;

procedure TMain.eXChange(Sender: TObject);
const
  ValueFormat = '0.############';
var
  I: Integer;
  Backup: TValue;
  Script: TScript;
begin
  if (eX.Text <> '') and Assigned(FGraph) and (FUpdateCount = 0) then
    for I := 0 to Graph.Formula.Count - 1 do if Graph.Formula.Active[I] then
    begin
      Backup := Graph.GlobalValue;
      try
        Script := Graph.SA[Graph.Formula.Data[I].ScriptIndex];
        try
          Graph.GlobalValue := Graph.Parser.AsValue(eX.Text);
        except
          Break;
        end;
        eY.Text := FormatFloat(ValueFormat, GetExtended(Graph.Parser.ExecuteScript(Script)^));
      finally
        Graph.GlobalValue := Backup;
      end;
      Exit;
    end;
  eY.Text := '';
end;

procedure TMain.bQualityChange(Sender: TObject);
begin
  if Assigned(FGraph) then
  begin
    FGraph.Quality := bQuality.Position;
    cQuality.Position := FGraph.Quality;
    bQuality.SelEnd := bQuality.Position;
  end;
end;

procedure TMain.eCenterXChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eCenterX.Text, Value) then
  begin
    FGraph.Offset := PointD(-Value, FGraph.Offset.Y);
    FGraph.Build;
  end;
end;

procedure TMain.eCenterYChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eCenterY.Text, Value) then
  begin
    FGraph.Offset := PointD(FGraph.Offset.X, -Value);
    FGraph.Build;
  end;
end;

procedure TMain.eMaxXChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eMaxX.Text, Value) and
    (Value > 0) then
    begin
      FGraph.MaxX := Value / 2;
      FGraph.Build;
    end;
end;

procedure TMain.eMaxYChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eMaxY.Text, Value) and
    (Value > 0) then
    begin
      FGraph.MaxY := Value / 2;
      FGraph.Build;
    end;
end;

procedure TMain.ePolarMaxAngleChange(Sender: TObject);
var
  Value: Integer;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToInt(ePolarMaxAngle.Text, Value) and
    (Value > 0) then
    begin
      if Value < 1 then
      begin
        BeginUpdate;
        try
          Value := 1;
          ePolarMaxAngle.Text := IntToStr(Value);
        finally
          EndUpdate;
        end;
      end;
      FGraph.PolarMaxAngle := DegToRad(Value);
      FGraph.Build;
    end;
end;

procedure TMain.eAccuracyChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.Accuracy := cAccuracy.Position;
    FGraph.Build;
  end;
end;

procedure TMain.eDecimalPlacesChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    DecimalPlaces := cDecimalPlaces.Position;
    FGraph.Invalidate;
  end;
end;

procedure TMain.eQualityChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.Quality := cQuality.Position;
    bQuality.Position := FGraph.Quality;
    FGraph.Build;
  end;
end;

procedure TMain.ePenWidthChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.GraphPen.Width := cPenWidth.Position;
    FGraph.Invalidate;
  end;
end;

procedure TMain.eBlendValueChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.SignBlendValue := cBlendValue.Position;
    FGraph.Invalidate;
    gFormula.Invalidate;
  end;
end;

procedure TMain.bLayoutChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.SignLayout := TLayoutType(bLayout.ItemIndex);
    FGraph.Invalidate;
  end;
end;

procedure TMain.eMarginChange(Sender: TObject);
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    FGraph.SignMargin := cMargin.Position;
    FGraph.Invalidate;
  end;
end;

procedure TMain.eHSpacingChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eHSpacing.Text, Value) and
    (Value > 0) then
    begin
      FGraph.HSpacing := Value;
      FGraph.Invalidate;
    end;
end;

procedure TMain.eVSpacingChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eVSpacing.Text, Value) and
    (Value > 0) then
    begin
      FGraph.VSpacing := Value;
      FGraph.Invalidate;
    end;
end;

procedure TMain.eCalcTimeChange(Sender: TObject);
var
  Value: Integer;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToInt(eCalcTime.Text, Value) and
    (Value > 0) then
    begin
      if Value < 1 then
      begin
        BeginUpdate;
        try
          Value := 1;
          eCalcTime.Text := IntToStr(Value);
        finally
          EndUpdate;
        end;
      end;
      FGraph.ThreadWorkTime := Value;
    end;
end;

procedure TMain.eOverlapMaxTimeChange(Sender: TObject);
var
  Value: Integer;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToInt(eOverlapMaxTime.Text, Value) and
    (Value > 0) then
    begin
      if Value < 0 then
      begin
        BeginUpdate;
        try
          Value := 0;
          eOverlapMaxTime.Text := IntToStr(Value);
        finally
          EndUpdate;
        end;
      end;
      FGraph.OverlapMaxTime := Value;
    end;
end;

procedure TMain.eOverlapMaxDepthChange(Sender: TObject);
var
  Value: Integer;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToInt(eOverlapMaxDepth.Text, Value) and
    (Value > 0) then
    begin
      if Value < 1 then
      begin
        BeginUpdate;
        try
          Value := 1;
          eOverlapMaxDepth.Text := IntToStr(Value);
        finally
          EndUpdate;
        end;
      end;
      FGraph.OverlapMaxDepth := Value;
    end;
end;

procedure TMain.eZoomInFactorChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eZoomInFactor.Text, Value) and
    (Value > 0) then
      FGraph.ZoomInFactor := Value;
end;

procedure TMain.eZoomOutFactorChange(Sender: TObject);
var
  Value: Extended;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) and TryStrToFloat(eZoomOutFactor.Text, Value) and
    (Value > 0) then
      FGraph.ZoomOutFactor := Value;
end;

procedure TMain.CSChange(Sender: TObject);
var
  Action: TAction absolute Sender;
  Value: TCoordinateSystem;
begin
  if Assigned(FGraph) and (FUpdateCount = 0) then
  begin
    Value := TCoordinateSystem(Action.Tag);
    if Value <> FGraph.CS then
    begin
      lPolarMaxAngle.Enabled := GPolar.Checked;
      ePolarMaxAngle.Enabled := GPolar.Checked;
      gFormula.EditorMode := False;
      SaveState(GetEnumName(TypeInfo(TCoordinateSystem), Ord(FGraph.CS)), False);
      SaveFormulaList;
      Clear;
      FGraph.CS := Value;
      if LoadState(GetEnumName(TypeInfo(TCoordinateSystem), Ord(FGraph.CS))) then
      begin
        Open;
        LoadFormulaList;
      end;
      FGraph.Invalidate;
    end;
  end;
end;

procedure TMain.gFormulaDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
const
  RowTint = 40;
var
  Data: PCellData;
  A, B: TColor;
  I, J, K: Byte;
  S: string;
  Colors: TThemeColors;
begin
  Colors := DarkTheme.CurrentColors;
  Data := gFormula.CellData[ARow];
  if (ACol = CColumn) and FGraph.MultiColor and Assigned(Data) and Data.A.Down then
  begin
    A := ColorToRGB(gFormula.Color);
    B := FGraph.Formula.Data[Data.FormulaIndex].Color;
    I := Blend(GetRValue(A), GetRValue(B), RowTint);
    J := Blend(GetGValue(A), GetGValue(B), RowTint);
    K := Blend(GetBValue(A), GetBValue(B), RowTint);
    gFormula.Canvas.Brush.Color := RGB(I, J, K);
    gFormula.Canvas.Font.Assign(gFormula.Font);
  end
  else begin
    gFormula.Canvas.Font.Assign(gFormula.Font);
    if Assigned(Data) and Data.A.Down then
      gFormula.Canvas.Brush.Color := Colors.Surface
    else begin
      gFormula.Canvas.Brush.Color := Colors.Panel;
      gFormula.Canvas.Font.Color := Colors.Muted;
    end;
  end;
  gFormula.Canvas.FillRect(Rect);
  S := Trim(gFormula.Cols[ACol][ARow]);
  if S <> '' then
  begin
    I := (Rect.Bottom - Rect.Top - gFormula.Canvas.TextHeight(S)) div 2;
    gFormula.Canvas.TextRect(Rect, Rect.Left + 2, Rect.Top + I, S);
  end;
end;

procedure TMain.gFormulaSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: String);
var
  Data: PCellData;
begin
  if (FUpdateCount = 0) and not gFormula.EditorMode and gFormula.FindCellData(ARow, Data) and
    FGraph.Formula.CheckIndex(Data.FormulaIndex) then
    begin
      FGraph.Formula[Data.FormulaIndex] := gFormula.Formula[ARow];
      FGraph.Formula.Visible[Data.FormulaIndex] := True;
      FGraph.Formula.Correct[Data.FormulaIndex] := True;
      FGraph.Build;
    end;
end;

procedure TMain.PCChange(Sender: TObject);
var
  FileName: string;
  List: TStringList;
begin
  if PC.ActivePage = pReport then
  begin
    pReport.SetFocus;
    FileName := UserPath + ReportFileName;
    List := TStringList.Create;
    try
      ReportFacts.SavePoints(FGraph, ChangeFileExt(FileName, PointsExt));
      List.Text := ReportFacts.Extend('<html><head></head><body></body></html>',
        FGraph, Assigned(Npp) and Npp.DarkMode, ChangeFileExt(FileName, PointsExt));
      List.SaveToFile(FileName, TEncoding.UTF8);
    finally
      List.Free;
    end;
    WB.Navigate(FileName);
  end;
  GPrint.Update;
end;

procedure TMain.SplitterMoved(Sender: TObject);
begin
  inherited;
  gFormula.ResizeColumn;
end;

procedure TMain.WBDocumentComplete(Sender: TObject; const pDisp: IDispatch; var URL: OleVariant);
begin
  inherited;
  FReportLoaded := True;
  GPrint.Update;
end;

initialization
  RegisterClasses([TSpeedButton, TGroupBox, TLabel, TToolBar, TToolButton]);

end.
