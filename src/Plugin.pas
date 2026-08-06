{ ************************************************************************** }
{                                                                            }
{ Plugin                                                                     }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit Plugin;

{$B-}

interface

uses
  Windows, Messages, Classes, SysUtils, NotepadPP.Types, NotepadPP.Plugin, NotepadPP.Scintilla,
  Parser, ParseTypes, Thread, DarkTheme, WebPanel;

type
  TSearchThread = class;

  TPlugin = class(TNppPlugin)
  private
    FHandle: THandle;
    FTextThread: TSearchThread;
    FLineThread: TSearchThread;
    FWeb: TWebPanel;
  protected
    procedure WindowMethod(var Message: TMessage); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start; virtual;
    procedure BeNotified(sn: PSciNotification); override;
    procedure DoNppnToolbarModification; override;
    procedure DoNppnDarkModeChanged; override;
    function Theme: TThemeKind; virtual;
    function HostBookmark(const Slot: Integer; const Mode: string): string; virtual;
    function HostReport: string; virtual;
    procedure WebToEditor(const NewDocument: Boolean); virtual;
    property LineThread: TSearchThread read FLineThread write FLineThread;
    property TextThread: TSearchThread read FTextThread write FTextThread;
    property Handle: THandle read FHandle write FHandle;
  end;

  TSearchThread = class(TThread)
  private
    FOutput: string;
    FSource: string;
    FParser: TCustomParser;
    FNotifyHandle: THandle;
    FScript: TScript;
  protected
    procedure Work; override;
    procedure Done; override;
  public
    destructor Destroy; override;
    function Start: Boolean; override;
    property Parser: TCustomParser read FParser write FParser;
    property NotifyHandle: THandle read FNotifyHandle write FNotifyHandle;
    property Source: string read FSource write FSource;
    property Output: string read FOutput write FOutput;
    property Script: TScript read FScript write FScript;
  end;

const
  M_FORMULA = WM_USER;
  M_TAB = WM_USER + 1;
  M_SELECT_ALL = WM_USER + 2;
  M_DRAW = WM_USER + 3;
  M_REFRESH = WM_USER + 4;
  M_COPY = WM_USER + 5;
  M_PASTE = WM_USER + 6;
  M_COPY_AND_DELETE = WM_USER + 7;
  M_BHIDE = WM_USER + 8;
  M_BSHOW = WM_USER + 9;
  M_LHIDE = WM_USER + 10;
  M_LSHOW = WM_USER + 11;

var
  Npp: TPlugin;

procedure Start; cdecl;

implementation

uses
  Controls, Vcl.ActnList, HTTPProd, ReportFacts, GDIPOBJ, GDIPAPI, MainForm, FastList,
  ParseUtils, StdCtrls, TextConsts, Types;

type
  TMainAccess = class(TMain);

var
  PlusFlag: Boolean = False;
  Hook: HHOOK;

procedure Start;
begin
  Npp.Start;
end;

function Focused(const Target: TWinControl): TWinControl;
var
  I: Integer;
begin
  if Assigned(Target) then
  begin
    if Target.Focused then
      Result := Target
    else
      Result := nil;
    if not Assigned(Result) then
      for I := 0 to Target.ControlCount - 1 do
        if Target.Controls[I] is TWinControl then
        begin
          Result := Focused(TWinControl(Target.Controls[I]));
          if Assigned(Result) then Break;
        end;
  end
  else
    Result := nil;
end;

function KeyboardHook(Code: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

  function CheckControl(Control: TWinControl): Boolean;
  begin
    Result := (Control is TCustomEdit) or (Control is TCustomComboBox);
  end;

var
  Control: TWinControl;
  Message: Integer;
begin
  if Code < 0 then
    Result := CallNextHookEx(Hook, Code, wParam, lParam)
  else begin
    Control := Focused(Main);
    if Assigned(Main) and Assigned(Control) and (Code = HC_ACTION) and (lParam and $40000000 = 0) then
    begin
      lParam := NativeInt(Control);
      case wParam of
        VK_TAB:
          begin
            wParam := Ord((GetKeyState(VK_CONTROL) and $80) = 0);
            Message := M_TAB;
          end;
        Ord('A'):
          if CheckControl(Control) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_SELECT_ALL
          else
            Message := 0;
        VK_RETURN:
          if Control = Main.bFormula then
            Message := M_DRAW
          else
            Message := 0;
        VK_F5: Message := M_REFRESH;
        Ord('C'):
          if (Control = Main.Graph) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_COPY
          else
            Message := 0;
        Ord('V'):
          if (Control = Main.Graph) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_PASTE
          else
            Message := 0;
        VK_DELETE:
          if (Control = Main.Graph) and ((GetKeyState(VK_SHIFT) and $80) <> 0) then
            Message := M_COPY_AND_DELETE
          else
            Message := 0;
        VK_INSERT:
          if (Control = Main.Graph) and ((GetKeyState(VK_SHIFT) and $80) <> 0) then
            Message := M_PASTE
          else
            Message := 0;
        VK_DOWN:
          if not CheckControl(Control) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_BHIDE
          else
            Message := 0;
        VK_UP:
          if not CheckControl(Control) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_BSHOW
          else
            Message := 0;
        VK_LEFT:
          if not CheckControl(Control) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_LHIDE
          else
            Message := 0;
        VK_RIGHT:
          if not CheckControl(Control) and ((GetKeyState(VK_CONTROL) and $80) <> 0) then
            Message := M_LSHOW
          else
            Message := 0;
      else
        Message := 0;
      end;
      if Message = 0 then
        Result := CallNextHookEx(Hook, Code, wParam, lParam)
      else begin
        PostMessage(Npp.Handle, Message, wParam, lParam);
        Result := 1;
      end;
    end
    else
      Result := CallNextHookEx(Hook, Code, wParam, lParam);
  end;
end;

procedure TPlugin.BeNotified(sn: PSciNotification);
var
  Point: TPoint;
  I, J, Size: Integer;
  S: string;
  B: UTF8String;

begin
  inherited;
  case sn.nmhdr.code of
    NPPN_READY:
      if (HWND(sn.nmhdr.hwndFrom) = NppData.NppHandle) and not PlusFlag then
      begin
        PlusFlag := not PlusFlag;
        Hook := SetWindowsHookEx(WH_KEYBOARD, KeyboardHook, 0, GetCurrentThreadId);
        GdiplusStartup(gdiplusToken, @StartupInput, nil);
      end;
    NPPN_SHUTDOWN:
      if (HWND(sn.nmhdr.hwndFrom) = NppData.NppHandle) and PlusFlag then
      begin
        PlusFlag := not PlusFlag;
        UnhookWindowsHookEx(Hook);
        FLineThread.Stop;
        if Assigned(Main) then
        begin
          Main.Graph.Stop;
          FreeAndNil(Main);
        end;
        GdiplusShutdown(gdiplusToken);
      end;
    SCN_CHARADDED, SCN_UPDATEUI, SCN_MODIFIED:
      if Assigned(Main) and Assigned(Main.Graph) then
      begin
        GetCursorPos(Point);
        ScreenToClient(NppData.ScintillaMainHandle, Point);
        I := SendMessage(NppData.ScintillaMainHandle, SCI_POSITIONFROMPOINTCLOSE, Point.X, Point.Y);
        if I >= 0 then
        begin
          S := '';
          Size := SendMessage(NppData.ScintillaMainHandle, SCI_GETSELTEXT, 0, 0);
          SetLength(B, Size + 1);
          FillChar(PAnsiChar(B)^, Size + 1, 0);
          SendMessage(NppData.ScintillaMainHandle, SCI_GETSELTEXT, 0, LPARAM(PAnsiChar(B)));
          S := UTF8ToString(PAnsiChar(B));
          if Trim(S) = '' then
          begin
            J := SendMessage(NppData.ScintillaMainHandle, SCI_LINEFROMPOSITION, I, 0);
            Size := SendMessage(NppData.ScintillaMainHandle, SCI_LINELENGTH, J, 0);
            SetLength(B, Size + 1);
            FillChar(PAnsiChar(B)^, Size + 1, 0);
            SendMessage(NppData.ScintillaMainHandle, SCI_GETLINE, J, LPARAM(PAnsiChar(B)));
            S := UTF8ToString(PAnsiChar(B));
          end;
          FLineThread.Stop;
          FLineThread.Parser := Main.Graph.Parser;
          FLineThread.NotifyHandle := FHandle;
          FLineThread.Source := S;
          FLineThread.Script := nil;
          FLineThread.Start;
        end;
      end;
  end;
end;

constructor TPlugin.Create;
const
  GB = 'Graph Builder';
  G = 'G';
var
  SK: TShortcutKey;
begin
  inherited;
  FLineThread := TSearchThread.Create(nil);
  FTextThread := TSearchThread.Create(nil);
  FHandle := AllocateHWnd(WindowMethod);
  PluginName := GB;
  FillChar(SK, SizeOf(TShortcutKey), 0);
  SK.IsAlt := True;
  SK.Key := G;
  AddFuncItem(GB, Plugin.Start, SK);
end;

destructor TPlugin.Destroy;
begin
  FLineThread.Stop;
  FLineThread.Free;
  FTextThread.Stop;
  FTextThread.Free;
  DeallocateHWnd(FHandle);
  inherited;
end;

procedure TPlugin.DoNppnToolbarModification;
begin
  inherited;
end;

procedure TPlugin.Start;
begin
  if not Assigned(Main) then
  begin
    Main := TMain.Create(Self, 1);
    FWeb := nil;
  end;
  Main.ApplyEditorTheme;
  Main.Show;
  Main.Suggest(SelectedText);
  if not Assigned(FWeb) then
  begin
    FWeb := TWebPanel.Create(Main, Main.Graph);
    FWeb.OnBookmark := HostBookmark;
    FWeb.OnReport := HostReport;
    FWeb.OnToEditor := WebToEditor;
  end;
  FWeb.Start(Theme);
end;

procedure TPlugin.WebToEditor(const NewDocument: Boolean);
var
  Text: string;
begin
  if not Assigned(Main) or not Assigned(Main.Graph) then Exit;
  Text := ReportFacts.AsMarkdown(Main.Graph);
  if Trim(Text) = '' then Exit;
  if NewDocument then
  begin
    NewTab;
    SetLanguageByName('markdown');
  end;
  ReplaceSelection(Text);
end;

function TPlugin.HostReport: string;
var
  Producer: TPageProducer;
  Template: string;
begin
  if not Assigned(Main) then Exit('');
  Producer := TPageProducer(Main.FindComponent('PP'));
  if Assigned(Producer) then
    Template := Producer.Content
  else
    Template := '<html><head></head><body></body></html>';
  Result := ReportFacts.Extend(Template, Main.Graph, DarkMode);
end;

function TPlugin.Theme: TThemeKind;
begin
  if DarkMode then
    Result := tkDark
  else
    Result := tkLight;
end;

function TPlugin.HostBookmark(const Slot: Integer; const Mode: string): string;
var
  Name: string;
  Cell: TCustomAction;
  Component: TComponent;
begin
  Result := FWeb.Bookmarks;
  if not Assigned(Main) or (Slot < 0) or (Slot > 9) then Exit;
  Name := 'B' + IntToStr(Slot);
  Component := Main.FindComponent(Name);
  if not (Component is TCustomAction) then Exit;
  Cell := TCustomAction(Component);
  if Mode = 'save' then
  begin
    TMainAccess(Main).PageKeepRatio := FWeb.KeepRatio;
    TMainAccess(Main).PagePenColor := FWeb.PenColor;
    TMainAccess(Main).SaveState(Name, False);
    Cell.Checked := True;
  end
  else if (Mode = 'load') and Cell.Checked then
  begin
    if TMainAccess(Main).LoadState(Name) then
    begin
      TMainAccess(Main).Open;
      FWeb.KeepRatio := TMainAccess(Main).PageKeepRatio;
      FWeb.PenColor := TMainAccess(Main).PagePenColor;
      FWeb.RefreshFromGraph;
    end;
    Cell.Checked := False;
  end;
  Result := FWeb.Bookmarks;
end;

procedure TPlugin.DoNppnDarkModeChanged;
begin
  inherited;
  if Assigned(Main) then Main.ApplyEditorTheme;
  if Assigned(FWeb) then FWeb.Reload(Theme);
end;

procedure TPlugin.WindowMethod(var Message: TMessage);
var
  Thread: TSearchThread;
  S: string;
  Control: TWinControl;
begin
  case Message.Msg of
    M_FORMULA:
      begin
        Thread := TSearchThread(Message.WParam);
        if Assigned(Thread) and Assigned(Thread.Script) then
        begin
          S := Main.Graph.Parser.ScriptToString(Thread.Script);
          if not Optimal(Thread.Script, stScript) and (Main.bFormula.Items.IndexOf(S) < 0) then
            Main.bFormula.Items.Add(S);
          Main.bFormula.Text := S;
          if Assigned(FWeb) then FWeb.Suggest(S);
        end;
      end;
    M_TAB: Main.Next(TWinControl(Message.lParam), Boolean(Message.WParam));
    M_SELECT_ALL:
      begin
        Control := TWinControl(Message.LParam);
        if Control is TCustomEdit then
          TCustomEdit(Control).SelectAll
        else
          if Control is TCustomComboBox then TCustomComboBox(Control).SelectAll;
      end;
    M_DRAW: Main.GDraw.Execute;
    M_REFRESH: Main.GRefresh.Execute;
    M_COPY: Main.GCopy.Execute;
    M_PASTE: Main.GPaste.Execute;
    M_COPY_AND_DELETE:
      begin
        Main.GCopy.Execute;
        Main.GClear.Execute;
      end;
    M_BHIDE: Main.BHide.Execute;
    M_BSHOW: Main.BShow.Execute;
    M_LHIDE: Main.LHide.Execute;
    M_LSHOW: Main.LShow.Execute;
  else
    Message.Result := DefWindowProc(FHandle, Message.Msg, Message.WParam, Message.LParam);
  end;
end;

destructor TSearchThread.Destroy;
begin
  FScript := nil;
  inherited;
end;

procedure TSearchThread.Done;
begin
end;

function TSearchThread.Start: Boolean;
begin
  if Started then Stop;
  Result := Assigned(FParser) and inherited Start;
end;

procedure TSearchThread.Work;
begin
  if FindFormula(FParser, FSource, FScript) then
    PostMessage(FNotifyHandle, M_FORMULA, WPARAM(Self), 0);
end;

initialization
  Npp := TPlugin.Create;

end.
