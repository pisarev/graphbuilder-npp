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
  SysUtils, Classes, Windows, uWVLoader, NotepadPP.Types, NotepadPP.Scintilla, NotepadPP.Plugin,
  Parser, ParseTypes, ValueTypes, CrossGraph, uLazTrace, uLazPanel;

type
  TLazPlugin = class(TNppPlugin)
  private
    FProbe: TMathParser;
    FProbeValue: TValue;
    FLast: string;
    function Formula(const Text: string): string;
    procedure Pick;
  protected
    function DefaultName: string; override;
    procedure DoNppnShutdown; override;
    procedure DoNppnDarkModeChanged; override;
    procedure DoNotify(const Notification: PSciNotification); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure ReportToEditor(const Text: string; const NewDocument: Boolean);
  end;

var
  Npp: TLazPlugin = nil;

implementation

procedure StartCommand; cdecl;
begin
  LogStep('menu: command received');
  if Assigned(Npp) then
    Npp.Start
  else
    LogStep('menu: Npp was not created');
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

destructor TLazPlugin.Destroy;
begin
  FreeAndNil(FProbe);
  inherited;
end;

function TLazPlugin.DefaultName: string;
begin
  Result := 'Graph Builder';
end;

function TLazPlugin.Formula(const Text: string): string;
var
  Candidate: string;
  Script: TScript;
begin
  Result := '';
  Candidate := Trim(Text);
  while (Candidate <> '') and (Candidate[Length(Candidate)] in [';', ',']) do
    Delete(Candidate, Length(Candidate), 1);
  Candidate := Trim(Candidate);
  if (Candidate = '') or (Length(Candidate) > 300) then Exit;
  if not Assigned(FProbe) then
  begin
    FProbe := TMathParser.Create(nil);
    FProbe.AddVariable(ValueVariableName, FProbeValue, False);
    FProbe.AddVariable(AngleVariableName, FProbeValue, False);
  end;
  Script := nil;
  try
    FProbe.StringToScript(Candidate, Script);
  except
    Exit;
  end;
  Result := Candidate;
end;

procedure TLazPlugin.Pick;
var
  Point: TPoint;
  Text: string;
begin
  if not Assigned(Panel) then Exit;
  Text := Formula(SelectedText);
  if Text = '' then
  begin
    if not GetCursorPos(Point) then Exit;
    Text := Formula(LineAtScreenPoint(Point));
  end;
  if (Text = '') or (Text = FLast) then Exit;
  FLast := Text;
  LogStep('picked up from the editor: ' + Text);
  Panel.Suggest(Text);
end;

procedure TLazPlugin.DoNotify(const Notification: PSciNotification);
begin
  if not Assigned(Notification) then Exit;
  case Notification.NotifyHeader.Code of
    SCN_CHARADDED, SCN_UPDATEUI, SCN_MODIFIED: Pick;
  end;
  inherited;
end;

procedure TLazPlugin.ReportToEditor(const Text: string; const NewDocument: Boolean);
begin
  if Trim(Text) = '' then Exit;
  if NewDocument then
  begin
    NewTab;
    SetLanguageByName('markdown');
  end;
  ReplaceSelection(Text);
  if NewDocument then
    LogStep(Format('report to the editor: %d characters, new tab', [Length(Text)]))
  else
    LogStep(Format('report to the editor: %d characters, at the caret', [Length(Text)]));
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
    if Cache = '' then Cache := SysUtils.GetEnvironmentVariable('LOCALAPPDATA');
    if Cache = '' then Cache := SysUtils.GetEnvironmentVariable('TEMP');
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
