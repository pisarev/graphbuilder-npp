{ ************************************************************************** }
{                                                                            }
{ uLazTrace                                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }
unit uLazTrace;

{$MODE Delphi}

interface

procedure LogStep(const Text: string);

implementation

uses
  SysUtils;

var
  TraceFile: string = '';

procedure LogStep(const Text: string);
var
  F: TextFile;
begin
  try
    if TraceFile = '' then
      TraceFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'graphbuilderlaz.log';
    AssignFile(F, TraceFile);
    if FileExists(TraceFile) then Append(F) else Rewrite(F);
    try
      WriteLn(F, FormatDateTime('hh:nn:ss.zzz', Now), '  ', Text);
    finally
      CloseFile(F);
    end;
  except
  end;
end;

end.
