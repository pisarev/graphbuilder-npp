{ ************************************************************************** }
{                                                                            }
{ uLazPlugin                                                                 }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }
unit uLazPlugin;

{$MODE Delphi}

interface

uses
  SysUtils, Classes, uWVLoader, NotepadPP.Types, NotepadPP.Plugin, uLazTrace, uLazPanel;

type
  TLazPlugin = class(TNppPlugin)
  protected
    function DefaultName: string; override;
    procedure DoNppnShutdown; override;
    procedure DoNppnDarkModeChanged; override;
  public
    constructor Create;
    procedure Start;
  end;

var
  Npp: TLazPlugin = nil;

implementation

procedure StartCommand; cdecl;
begin
  LogStep('menu: command received');
  if Assigned(Npp) then Npp.Start else LogStep('menu: Npp was not created');
end;

constructor TLazPlugin.Create;
var
  SK: TShortcutKey;
begin
  inherited Create;
  PluginName := 'Graph Builder';
  FillChar(SK, SizeOf(TShortcutKey), 0);
  SK.IsAlt := True;
  SK.Key := 'G';
  AddFuncItem(PluginName, StartCommand, SK);
end;

function TLazPlugin.DefaultName: string;
begin
  Result := 'Graph Builder';
end;

procedure TLazPlugin.Start;
var
  Cache: string;
  TB: TToolbarData;
begin
  LogStep(Format('TToolbarData: size %d, ModuleName offset %d', [SizeOf(TToolbarData), PtrUInt(@TB.ModuleName) - PtrUInt(@TB)]));
  if not Assigned(GlobalWebView2Loader) then
  begin
    Cache := Trim(ConfigDir);
    if Cache = '' then Cache := GetEnvironmentVariable('LOCALAPPDATA');
    if Cache = '' then Cache := GetEnvironmentVariable('TEMP');
    Cache := IncludeTrailingPathDelimiter(Cache) + 'GraphBuilderLaz';
    LogStep('Edge loader: folder ' + Cache);
    ForceDirectories(Cache);
    GlobalWebView2Loader := TWVLoader.Create(nil);
    GlobalWebView2Loader.UserDataFolder := Cache;
    GlobalWebView2Loader.StartWebView2;
    LogStep('Edge loader: start requested');
  end;
  if not Assigned(Panel) then
  begin
    LogStep('panel: creating');
    Panel := TLazPanel.Create(Self, 1);
    LogStep('panel: created');
  end;
  LogStep('panel: showing');
  Panel.Show;
  LogStep('panel: shown');
end;

procedure TLazPlugin.DoNppnDarkModeChanged;
begin
  if Assigned(Panel) then Panel.SetTheme(DarkMode);
  inherited;
end;

procedure TLazPlugin.DoNppnShutdown;
begin
  FreeAndNil(Panel);
  inherited;
end;

initialization
  Npp := TLazPlugin.Create;
end.
