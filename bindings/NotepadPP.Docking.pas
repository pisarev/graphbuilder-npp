{ ************************************************************************** }
{                                                                            }
{ NotepadPP.Docking                                                          }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit NotepadPP.Docking;

interface

uses
  {$IFDEF FPC}
  Windows, Messages, LMessages, CommCtrl, Classes, SysUtils, Controls, Forms,
  {$ELSE}
  Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils, Vcl.Controls, Vcl.Forms,
  {$ENDIF}
  NotepadPP.Types, NotepadPP.Plugin, NotepadPP.Forms;

type
  {$IFDEF FPC}
  TNppNotify = LMessages.TLMNotify;
  {$ELSE}
  TNppNotify = Winapi.Messages.TWMNotify;
  {$ENDIF}

  TNppDockingForm = class(TNppForm)
  private
    FDlgId: Integer;
    FCmdId: Integer;
    FDockingMask: Cardinal;
    FToolbarData: TToolbarData;
    FOnDock: TNotifyEvent;
    FOnFloat: TNotifyEvent;
    procedure AdjustForDpi;
    procedure ClearControlParent(const Control: TControl);
    procedure WMNotify(var Message: TNppNotify); message WM_NOTIFY;
  protected
    property NppDefaultDockingMask: Cardinal read FDockingMask write FDockingMask;
    property OnDock: TNotifyEvent read FOnDock write FOnDock;
    property OnFloat: TNotifyEvent read FOnFloat write FOnFloat;
  public
    constructor Create(NppParent: TNppPlugin); overload; override;
    constructor Create(AOwner: TNppForm); overload; override;
    procedure AfterConstruction; override;
    constructor Create(NppParent: TNppPlugin; DlgId: Integer); reintroduce; overload; virtual;
    constructor Create(AOwner: TNppForm; DlgId: Integer); reintroduce; overload; virtual;
    procedure RegisterDockingForm(const MaskStyle: Cardinal = DWS_DF_CONT_LEFT);
    procedure UpdateDisplayInfo; overload;
    procedure UpdateDisplayInfo(const Info: string); overload;
    procedure Show;
    procedure Hide;
    property DlgId: Integer read FDlgId;
    property CmdId: Integer read FCmdId write FCmdId;
  end;

implementation

const
  TitleLength = 256;
  AddInfoLength = 256;

type
  PDockingText = ^TDockingText;
  TDockingText = record
    DlgId: Integer;
    Title: array[0..TitleLength - 1] of WideChar;
    AddInfo: array[0..AddInfoLength - 1] of WideChar;
    ModuleName: array[0..MAX_PATH] of WideChar;
  end;

resourcestring
  SNoDlgId = 'A docking window is created with a dialog id';

var
  TextList: TList = nil;

function DockingText(const DlgId: Integer): PDockingText;
var
  I: Integer;
begin
  if not Assigned(TextList) then TextList := TList.Create;
  for I := 0 to TextList.Count - 1 do
  begin
    Result := TextList[I];
    if Result.DlgId = DlgId then Exit;
  end;
  New(Result);
  FillChar(Result^, SizeOf(TDockingText), 0);
  Result.DlgId := DlgId;
  TextList.Add(Result);
end;

constructor TNppDockingForm.Create(NppParent: TNppPlugin);
begin
  raise EInvalidOperation.Create(SNoDlgId);
end;

constructor TNppDockingForm.Create(AOwner: TNppForm);
begin
  raise EInvalidOperation.Create(SNoDlgId);
end;

constructor TNppDockingForm.Create(NppParent: TNppPlugin; DlgId: Integer);
begin
  FDlgId := DlgId;
  FDockingMask := DWS_DF_CONT_LEFT;
  inherited Create(NppParent);
end;

constructor TNppDockingForm.Create(AOwner: TNppForm; DlgId: Integer);
begin
  FDlgId := DlgId;
  FDockingMask := DWS_DF_CONT_LEFT;
  inherited Create(AOwner);
end;

procedure TNppDockingForm.AfterConstruction;
begin
  inherited;
  FCmdId := Npp.SingleCommandId;
  HandleNeeded;
  AdjustForDpi;
  RegisterDockingForm(FDockingMask);
  ClearControlParent(Self);
end;

procedure TNppDockingForm.AdjustForDpi;
type
  TGetDpiForWindow = function(Window: HWND): UINT; stdcall;
var
  Dpi: Integer;
  Library_: HMODULE;
  GetDpi: TGetDpiForWindow;
  DC: HDC;
begin
  Dpi := 0;
  Library_ := GetModuleHandle(user32);
  if Library_ <> 0 then
  begin
    GetDpi := GetProcAddress(Library_, 'GetDpiForWindow');
    if Assigned(GetDpi) then Dpi := GetDpi(Handle);
  end;
  if Dpi <= 0 then
  begin
    DC := GetDC(Handle);
    if DC <> 0 then
      try
        Dpi := GetDeviceCaps(DC, LOGPIXELSX);
      finally
        ReleaseDC(Handle, DC);
      end;
  end;
  if (Dpi <= 0) or (Dpi = PixelsPerInch) then Exit;
  Scaled := True;
  {$IFDEF FPC}
  AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, Dpi, Width, MulDiv(Width, Dpi, PixelsPerInch));
  {$ELSE}
  ScaleForPPI(Dpi);
  {$ENDIF}
end;

procedure TNppDockingForm.RegisterDockingForm(const MaskStyle: Cardinal);
var
  Text: PDockingText;
  Wide: UnicodeString;
begin
  if not Assigned(Npp) then Exit;
  HandleNeeded;
  Text := DockingText(FDlgId);
  Wide := UnicodeString(Caption);
  StrLCopy(Text.Title, PWideChar(Wide), TitleLength - 1);
  Wide := UnicodeString(Npp.ModuleName);
  StrLCopy(Text.ModuleName, PWideChar(Wide), MAX_PATH);
  Text.AddInfo[0] := #0;
  FillChar(FToolbarData, SizeOf(FToolbarData), 0);
  FToolbarData.Client := Handle;
  FToolbarData.Name := Text.Title;
  FToolbarData.DlgID := FDlgId;
  FToolbarData.Mask := MaskStyle or DWS_ADDINFO;
  FToolbarData.AddInfo := Text.AddInfo;
  FToolbarData.ModuleName := Text.ModuleName;
  if not Icon.Empty then
  begin
    FToolbarData.IconTab := Icon.Handle;
    FToolbarData.Mask := FToolbarData.Mask or DWS_ICONTAB;
  end;
  Visible := True;
  Npp.SendNpp(NPPM_DMMREGASDCKDLG, 0, LPARAM(@FToolbarData));
end;

procedure TNppDockingForm.UpdateDisplayInfo;
begin
  UpdateDisplayInfo('');
end;

procedure TNppDockingForm.UpdateDisplayInfo(const Info: string);
var
  Text: PDockingText;
  Wide: UnicodeString;
begin
  if not Assigned(Npp) then Exit;
  Text := DockingText(FDlgId);
  Wide := UnicodeString(Info);
  StrLCopy(Text.AddInfo, PWideChar(Wide), AddInfoLength - 1);
  Npp.SendNpp(NPPM_DMMUPDATEDISPINFO, 0, LPARAM(Handle));
end;

procedure TNppDockingForm.Show;
var
  WasVisible: Boolean;
begin
  if Assigned(Npp) then Npp.SendNpp(NPPM_DMMSHOW, 0, LPARAM(Handle));
  WasVisible := Visible;
  inherited Show;
  if WasVisible then DoShow;
end;

procedure TNppDockingForm.Hide;
begin
  if Assigned(Npp) then Npp.SendNpp(NPPM_DMMHIDE, 0, LPARAM(Handle));
  DoHide;
end;

procedure TNppDockingForm.ClearControlParent(const Control: TControl);
var
  I: Integer;
  Window: TWinControl;
  Style: NativeInt;
begin
  if not Assigned(Control) then Exit;
  if Control is TWinControl then
  begin
    Window := TWinControl(Control);
    Window.HandleNeeded;
    Style := GetWindowLongPtr(Window.Handle, GWL_EXSTYLE);
    if (Style and WS_EX_CONTROLPARENT) <> 0 then
      SetWindowLongPtr(Window.Handle, GWL_EXSTYLE, Style and not WS_EX_CONTROLPARENT);
  end;
  for I := Control.ComponentCount - 1 downto 0 do
    if Control.Components[I] is TControl then
      ClearControlParent(TControl(Control.Components[I]));
end;

procedure TNppDockingForm.WMNotify(var Message: TNppNotify);
begin
  if not Assigned(Npp) or not Assigned(Message.NMHdr) or
    (Message.NMHdr.hwndFrom <> Npp.NppData.NppHandle) then
    begin
      inherited;
      Exit;
    end;
  Message.Result := 0;
  case Cardinal(Message.NMHdr.code) and $FFFF of
    DMN_CLOSE: DoHide;
    DMN_DOCK: if Assigned(FOnDock) then FOnDock(Self);
    DMN_FLOAT: if Assigned(FOnFloat) then FOnFloat(Self);
  end;
  inherited;
end;

procedure ClearTextList;
var
  I: Integer;
begin
  if not Assigned(TextList) then Exit;
  for I := 0 to TextList.Count - 1 do Dispose(PDockingText(TextList[I]));
  FreeAndNil(TextList);
end;

initialization

finalization
  ClearTextList;

end.
