{ ************************************************************************** }
{                                                                            }
{ NotepadPP.Plugin                                                           }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit NotepadPP.Plugin;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Windows, Messages, SysUtils,
  {$ELSE}
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  {$ENDIF}
  NotepadPP.Types;

type
  TNppPlugin = class
  private
    FNppData: TNppData;
    FFuncItems: TFuncItemArray;
    FShortcuts: array of PShortcutKey;
    FPluginName: string;
    FNameForNpp: UnicodeString;
    FModuleName: string;
    function GetFuncCount: Integer;
    function GetFuncItem(const Index: Integer): PFuncItem;
  protected
    function DefaultName: string; virtual;
    procedure DoNppnReady; virtual;
    procedure DoNppnToolbarModification; virtual;
    procedure DoNppnShutdown; virtual;
    procedure DoNppnDarkModeChanged; virtual;
    procedure DoNotify(const Notification: PSciNotification); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    function AddFuncItem(const Caption: string; const Func: TPluginCommand): Integer; overload;
    function AddFuncItem(const Caption: string; const Func: TPluginCommand;
      const ShortcutKey: TShortcutKey): Integer; overload;
    function AddSeparator: Integer;
    function CommandCount: Integer;
    function SingleCommandId: Integer;
    procedure SetInfo(const Value: TNppData); virtual;
    procedure BeNotified(Notification: PSciNotification); virtual;
    function MessageProc(const Message: Cardinal; const WParam: WPARAM;
      const LParam: LPARAM): LRESULT; virtual;
    function CurrentScintilla: HWND;
    function SendEditor(const Message: Cardinal; const WParam: WPARAM = 0; const LParam: LPARAM = 0): LRESULT;
    function SendNpp(const Message: Cardinal; const WParam: WPARAM = 0; const LParam: LPARAM = 0): LRESULT;
    function SelectedText: string;
    procedure ReplaceSelection(const Value: string);
    function LineAtScreenPoint(const Point: TPoint): string;
    function NewTab: HWND;
    function SetLanguageByName(const Match: string): Boolean;
    function ConfigDir: string;
    function DarkMode: Boolean;
    procedure RegisterModeless(const Window: HWND);
    procedure UnregisterModeless(const Window: HWND);
    property NppData: TNppData read FNppData;
    function ShortcutText(const Index: Integer): string;
    function AddToolbarIcon(const Index: Integer; const Icons: TToolbarIcons): Boolean;
    function NameForNpp: PWideChar;
    property PluginName: string read FPluginName write FPluginName;
    property ModuleName: string read FModuleName;
    property FuncCount: Integer read GetFuncCount;
    property FuncItem[const Index: Integer]: PFuncItem read GetFuncItem;
    property FuncItems: TFuncItemArray read FFuncItems;
  end;

implementation

const
  SCI_GETSELTEXT = 2161;
  SCI_REPLACESEL = 2170;
  SCI_GETLINE = 2153;
  SCI_LINELENGTH = 2350;
  SCI_LINEFROMPOSITION = 2166;
  SCI_POSITIONFROMPOINTCLOSE = 2023;

constructor TNppPlugin.Create;
var
  Buffer: array[0..MAX_PATH] of WideChar;
  Length_: DWORD;
begin
  inherited Create;
  FPluginName := DefaultName;
  FillChar(Buffer, SizeOf(Buffer), 0);
  Length_ := GetModuleFileNameW(HInstance, @Buffer[0], Length(Buffer));
  if Length_ > 0 then FModuleName := ExtractFileName(string(PWideChar(@Buffer[0])));
end;

destructor TNppPlugin.Destroy;
var
  I: Integer;
begin
  for I := Low(FShortcuts) to High(FShortcuts) do Dispose(FShortcuts[I]);
  FShortcuts := nil;
  FFuncItems := nil;
  inherited;
end;

function TNppPlugin.DefaultName: string;
begin
  Result := 'Plugin';
end;

function TNppPlugin.GetFuncCount: Integer;
begin
  Result := Length(FFuncItems);
end;

function TNppPlugin.GetFuncItem(const Index: Integer): PFuncItem;
begin
  if (Index < 0) or (Index > High(FFuncItems)) then
    Result := nil
  else
    Result := @FFuncItems[Index];
end;

function TNppPlugin.AddFuncItem(const Caption: string; const Func: TPluginCommand): Integer;
var
  Item: PFuncItem;
  Text: WideString;
begin
  Result := Length(FFuncItems);
  SetLength(FFuncItems, Result + 1);
  Item := @FFuncItems[Result];
  FillChar(Item^, SizeOf(TFuncItem), 0);
  Text := Copy(Caption, 1, MenuItemNameLength - 1);
  Move(PWideChar(Text)^, Item.ItemName[0], System.Length(Text) * SizeOf(WideChar));
  Item.Func := Func;
end;

function TNppPlugin.AddFuncItem(const Caption: string; const Func: TPluginCommand;
  const ShortcutKey: TShortcutKey): Integer;
var
  Key: PShortcutKey;
  Index: Integer;
begin
  Result := AddFuncItem(Caption, Func);
  New(Key);
  Key^ := ShortcutKey;
  Index := Length(FShortcuts);
  SetLength(FShortcuts, Index + 1);
  FShortcuts[Index] := Key;
  FFuncItems[Result].ShortcutKey := Key;
end;

function TNppPlugin.AddSeparator: Integer;
begin
  Result := AddFuncItem('-', nil);
end;

function TNppPlugin.CommandCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(FFuncItems) to High(FFuncItems) do
    if Assigned(FFuncItems[I].Func) then Inc(Result);
end;

function TNppPlugin.SingleCommandId: Integer;
var
  I: Integer;
begin
  Result := 0;
  if CommandCount <> 1 then Exit;
  for I := Low(FFuncItems) to High(FFuncItems) do
    if Assigned(FFuncItems[I].Func) then Exit(FFuncItems[I].CmdID);
end;

procedure TNppPlugin.SetInfo(const Value: TNppData);
begin
  FNppData := Value;
end;

procedure TNppPlugin.BeNotified(Notification: PSciNotification);
begin
  if not Assigned(Notification) then Exit;
  case Notification.NotifyHeader.Code of
    NPPN_READY: DoNppnReady;
    NPPN_TBMODIFICATION: DoNppnToolbarModification;
    NPPN_SHUTDOWN: DoNppnShutdown;
    NPPN_DARKMODECHANGED: DoNppnDarkModeChanged;
  else
    DoNotify(Notification);
  end;
end;

function TNppPlugin.MessageProc(const Message: Cardinal; const WParam: WPARAM; const LParam: LPARAM): LRESULT;
begin
  Result := 1;
end;

procedure TNppPlugin.DoNppnReady;
begin
end;

procedure TNppPlugin.DoNppnToolbarModification;
begin
end;

procedure TNppPlugin.DoNppnShutdown;
begin
end;

procedure TNppPlugin.DoNppnDarkModeChanged;
begin
end;

procedure TNppPlugin.DoNotify(const Notification: PSciNotification);
begin
end;

function TNppPlugin.CurrentScintilla: HWND;
var
  Index: Integer;
begin
  Index := 0;
  SendMessage(FNppData.NppHandle, NPPM_GETCURRENTSCINTILLA, 0, LPARAM(@Index));
  if Index = 0 then
    Result := FNppData.ScintillaMainHandle
  else
    Result := FNppData.ScintillaSecondHandle;
end;

function TNppPlugin.SendEditor(const Message: Cardinal; const WParam: WPARAM; const LParam: LPARAM): LRESULT;
begin
  Result := SendMessage(CurrentScintilla, Message, WParam, LParam);
end;

function TNppPlugin.SendNpp(const Message: Cardinal; const WParam: WPARAM; const LParam: LPARAM): LRESULT;
begin
  Result := SendMessage(FNppData.NppHandle, Message, WParam, LParam);
end;

function TNppPlugin.SelectedText: string;
var
  Size: LRESULT;
  Buffer: TArray<AnsiChar>;
begin
  Size := SendEditor(SCI_GETSELTEXT, 0, 0);
  if Size <= 0 then Exit('');
  SetLength(Buffer, Size + 1);
  FillChar(Buffer[0], Length(Buffer), 0);
  SendEditor(SCI_GETSELTEXT, 0, LPARAM(@Buffer[0]));
  Result := UTF8ToString(PAnsiChar(@Buffer[0]));
end;

procedure TNppPlugin.ReplaceSelection(const Value: string);
var
  Text: UTF8String;
begin
  Text := UTF8Encode(Value);
  SendEditor(SCI_REPLACESEL, 0, LPARAM(PAnsiChar(Text)));
end;

function TNppPlugin.LineAtScreenPoint(const Point: TPoint): string;
var
  Editor: HWND;
  Local: TPoint;
  Position, Line, Size: LRESULT;
  Buffer: TArray<AnsiChar>;
begin
  Result := '';
  Editor := CurrentScintilla;
  if Editor = 0 then Exit;
  Local := Point;
  if not ScreenToClient(Editor, Local) then Exit;
  Position := SendMessage(Editor, SCI_POSITIONFROMPOINTCLOSE, Local.X, Local.Y);
  if Position < 0 then Exit;
  Line := SendMessage(Editor, SCI_LINEFROMPOSITION, Position, 0);
  Size := SendMessage(Editor, SCI_LINELENGTH, Line, 0);
  if Size <= 0 then Exit;
  SetLength(Buffer, Size + 1);
  FillChar(Buffer[0], Length(Buffer), 0);
  SendMessage(Editor, SCI_GETLINE, Line, LPARAM(@Buffer[0]));
  Result := UTF8ToString(PAnsiChar(@Buffer[0]));
end;

function TNppPlugin.NewTab: HWND;
begin
  SendNpp(NPPM_MENUCOMMAND, 0, IDM_FILE_NEW);
  Result := CurrentScintilla;
end;

procedure LanguageCommands(const Menu: HMENU; const Match: string; var Plain, Dark: Integer);
var
  I, Count, Id: Integer;
  Sub: HMENU;
  Buffer: array[0..255] of WideChar;
  Wide: UnicodeString;
  Name: string;
begin
  Count := GetMenuItemCount(Menu);
  for I := 0 to Count - 1 do
  begin
    Sub := GetSubMenu(Menu, I);
    if Sub <> 0 then
    begin
      LanguageCommands(Sub, Match, Plain, Dark);
      Continue;
    end;
    Id := GetMenuItemID(Menu, I);
    if (Id < IDM_LANG) or (Id >= IDM_LANG + 1000) then Continue;
    FillChar(Buffer, SizeOf(Buffer), 0);
    if GetMenuStringW(Menu, I, @Buffer[0], Length(Buffer), MF_BYPOSITION) = 0 then Continue;
    Wide := PWideChar(@Buffer[0]);
    Name := LowerCase(string(Wide));
    if Pos(LowerCase(Match), Name) = 0 then Continue;
    if Pos('dark', Name) > 0 then
    begin
      if Dark = 0 then Dark := Id;
    end
    else if Plain = 0 then
      Plain := Id;
  end;
end;

function TNppPlugin.SetLanguageByName(const Match: string): Boolean;
var
  Plain, Dark, Id: Integer;
begin
  Plain := 0;
  Dark := 0;
  LanguageCommands(GetMenu(FNppData.NppHandle), Match, Plain, Dark);
  if DarkMode then
    Id := Dark
  else
    Id := Plain;
  if Id = 0 then
    if DarkMode then
      Id := Plain
    else
      Id := Dark;
  Result := Id <> 0;
  if Result then SendMessage(FNppData.NppHandle, WM_COMMAND, WPARAM(Id), 0);
end;

function TNppPlugin.ShortcutText(const Index: Integer): string;
var
  Item: PFuncItem;
  Key: TShortcutKey;
  Letter: string;
begin
  Result := '';
  Item := FuncItem[Index];
  if not Assigned(Item) then Exit;
  FillChar(Key, SizeOf(Key), 0);
  if SendNpp(NPPM_GETSHORTCUTBYCMDID, WPARAM(Item.CmdID), LPARAM(@Key)) = 0 then Exit;
  if Key.Key = #0 then Exit;
  if Key.IsCtrl then Result := Result + 'Ctrl+';
  if Key.IsAlt then Result := Result + 'Alt+';
  if Key.IsShift then Result := Result + 'Shift+';
  Letter := Char(Byte(Key.Key));
  Result := Result + UpperCase(Letter);
end;

function TNppPlugin.AddToolbarIcon(const Index: Integer; const Icons: TToolbarIcons): Boolean;
var
  Item: PFuncItem;
  Handles: TToolbarIcons;
begin
  Result := False;
  Item := FuncItem[Index];
  if not Assigned(Item) then Exit;
  if (Icons.ToolbarBmp = 0) or (Icons.ToolbarIcon = 0) or (Icons.ToolbarIconDarkMode = 0) then Exit;
  Handles := Icons;
  Result := SendNpp(NPPM_ADDTOOLBARICON_FORDARKMODE, WPARAM(Item.CmdID), LPARAM(@Handles)) <> 0;
end;

function TNppPlugin.NameForNpp: PWideChar;
begin
  FNameForNpp := UnicodeString(FPluginName);
  Result := PWideChar(FNameForNpp);
end;

function TNppPlugin.ConfigDir: string;
var
  Buffer: array[0..MAX_PATH] of WideChar;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  SendNpp(NPPM_GETPLUGINSCONFIGDIR, MAX_PATH, LPARAM(@Buffer[0]));
  Result := string(PWideChar(@Buffer[0]));
end;

function TNppPlugin.DarkMode: Boolean;
begin
  Result := SendNpp(NPPM_ISDARKMODEENABLED) <> 0;
end;

procedure TNppPlugin.RegisterModeless(const Window: HWND);
begin
  SendNpp(NPPM_MODELESSDIALOG, MODELESSDIALOGADD, LPARAM(Window));
end;

procedure TNppPlugin.UnregisterModeless(const Window: HWND);
begin
  SendNpp(NPPM_MODELESSDIALOG, MODELESSDIALOGREMOVE, LPARAM(Window));
end;

end.
