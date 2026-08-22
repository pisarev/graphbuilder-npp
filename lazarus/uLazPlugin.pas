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
  SysUtils, Classes, Windows, ExtCtrls, uWVLoader, NotepadPP.Types, NotepadPP.Scintilla,
  NotepadPP.Plugin, Parser, ParseTypes, ValueTypes, CrossGraph, uLazTrace, uLazPanel,
  ToolbarGlyph;

type
  TLazPlugin = class(TNppPlugin)
  private
    FProbe: TMathParser;
    FProbeValue: TValue;
    FLast: string;
    FShow: TTimer;
    FShown: string;
    function Formula(const Text: string): string;
    procedure Pick;
    procedure ShowLater;
    procedure ShowSelection(Sender: TObject);
  protected
    function DefaultName: string; override;
    procedure DoNppnToolbarModification; override;
    procedure DoNppnShutdown; override;
    procedure DoNppnDarkModeChanged; override;
    procedure DoNotify(const Notification: PSciNotification); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure AdoptSelection;
    procedure ReportToEditor(const Text: string; const NewDocument: Boolean);
  end;

var
  Npp: TLazPlugin = nil;

implementation

const
  PreviewDelay = 250;
  PanelMenuIndex = 0;

procedure StartCommand; cdecl;
begin
  LogStep('menu: command received');
  if Assigned(Npp) then
    Npp.Start
  else
    LogStep('menu: Npp was not created');
end;

procedure AdoptCommand; cdecl;
begin
  LogStep('menu: plot the selection');
  if Assigned(Npp) then
    Npp.AdoptSelection
  else
    LogStep('menu: Npp was not created');
end;

constructor TLazPlugin.Create;
var
  SK: TShortcutKey;
begin
  inherited Create;
  PluginName := 'Graph Builder';
  FShow := TTimer.Create(nil);
  FShow.Enabled := False;
  FShow.Interval := PreviewDelay;
  FShow.OnTimer := ShowSelection;
  FillChar(SK, SizeOf(TShortcutKey), 0);
  SK.IsAlt := True;
  SK.Key := 'G';
  AddFuncItem(PluginName, StartCommand, SK);
  FillChar(SK, SizeOf(TShortcutKey), 0);
  SK.IsAlt := True;
  SK.IsShift := True;
  SK.Key := 'G';
  AddFuncItem('Plot the selection', AdoptCommand, SK);
end;

procedure TLazPlugin.AdoptSelection;
var
  Lines, Good: TStringList;
  I: Integer;
  Text: string;
begin
  if not Assigned(Panel) then
  begin
    LogStep('plot the selection: no panel yet, bringing it up');
    Start;
    if not Assigned(Panel) then Exit;
  end;
  Lines := TStringList.Create;
  Good := TStringList.Create;
  try
    Lines.Text := SelectedText;
    for I := 0 to Lines.Count - 1 do
    begin
      Text := Formula(Lines[I]);
      if (Text <> '') and (Good.IndexOf(Text) < 0) then Good.Add(Text);
    end;
    LogStep(Format('plot the selection: lines %d, formulas %d', [Lines.Count, Good.Count]));
    FShown := SelectedText;
    if not Panel.Adopt(Good, SelectedText) then
      LogStep('plot the selection: the page has not come up yet, nothing was sent');
  finally
    Good.Free;
    Lines.Free;
  end;
end;

destructor TLazPlugin.Destroy;
begin
  if Assigned(FShow) then FShow.Enabled := False;
  FreeAndNil(FShow);
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
  if Trim(SelectedText) <> '' then Exit;
  if not GetCursorPos(Point) then Exit;
  Text := Formula(LineAtScreenPoint(Point));
  if (Text = '') or (Text = FLast) then Exit;
  LogStep('picked up from the editor: ' + Text);
  FLast := Text;
  if not Panel.Suggest(Text) then
    LogStep('the panel has not started yet, the formula was held back');
end;

procedure TLazPlugin.ShowLater;
begin
  if not Assigned(FShow) then Exit;
  FShow.Enabled := False;
  FShow.Enabled := True;
end;

procedure TLazPlugin.ShowSelection(Sender: TObject);
var
  Lines, Good: TStringList;
  I: Integer;
  Selection, Text: string;
begin
  if Assigned(FShow) then FShow.Enabled := False;
  if not Assigned(Panel) then Exit;
  Selection := SelectedText;
  if Selection = FShown then Exit;
  FShown := Selection;
  Lines := TStringList.Create;
  Good := TStringList.Create;
  try
    Lines.Text := Selection;
    for I := 0 to Lines.Count - 1 do
    begin
      Text := Formula(Lines[I]);
      if (Text <> '') and (Good.IndexOf(Text) < 0) then Good.Add(Text);
    end;
    LogStep(Format('preview of the selection: characters %d, lines %d, formulas %d',
      [Length(Selection), Lines.Count, Good.Count]));
    Panel.Preview(Good, Selection);
  finally
    Good.Free;
    Lines.Free;
  end;
end;

procedure TLazPlugin.DoNotify(const Notification: PSciNotification);
begin
  if not Assigned(Notification) then Exit;
  case Notification.NotifyHeader.Code of
    SCN_CHARADDED, SCN_UPDATEUI, SCN_MODIFIED:
      begin
        Pick;
        ShowLater;
      end;
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
  LogStep(Format('TToolbarData: size %d, ModuleName offset %d',
    [SizeOf(TToolbarData), PtrUInt(@TB.ModuleName) - PtrUInt(@TB)]));
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
    if GlobalWebView2Loader.StartWebView2 then
      LogStep('Edge loader: start requested')
    else
      LogStep('Edge loader: START FAILED, state ' +
        IntToStr(Ord(GlobalWebView2Loader.Status)) + ', reason: ' +
        UTF8Encode(GlobalWebView2Loader.ErrorMessage));
  end;
  if not Assigned(Panel) then
  begin
    LogStep('panel: creating');
    Panel := TLazPanel.Create(Self, PanelMenuIndex);
    LogStep('panel: created');
  end;
  LogStep('panel: showing');
  Panel.Show;
  LogStep('panel: shown');
end;

procedure TLazPlugin.DoNppnToolbarModification;
var
  Glyph: TToolbarGlyph;
  Icons: TToolbarIcons;
begin
  inherited;
  Glyph := BuildToolbarGlyph(GlyphSide);
  if Glyph.Painted = 0 then
  begin
    LogStep('toolbar: the icon came out empty, there will be no button');
    Exit;
  end;
  FillChar(Icons, SizeOf(Icons), 0);
  Icons.ToolbarBmp := Glyph.Bmp;
  Icons.ToolbarIcon := Glyph.Light;
  Icons.ToolbarIconDarkMode := Glyph.Dark;
  if AddToolbarIcon(PanelMenuIndex, Icons) then
    LogStep(Format('toolbar: the request went out, icon %dx%d, %d pixels painted',
      [GlyphSide, GlyphSide, Glyph.Painted]))
  else
    LogStep('toolbar: the request did not go out - the icon is incomplete');
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
