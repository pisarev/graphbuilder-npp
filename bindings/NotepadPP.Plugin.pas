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
  Windows, SysUtils,
  {$ELSE}
  Winapi.Windows, System.SysUtils,
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
    function ConfigDir: string;
    function DarkMode: Boolean;
    procedure RegisterModeless(const Window: HWND);
    procedure UnregisterModeless(const Window: HWND);
    property NppData: TNppData read FNppData;
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
