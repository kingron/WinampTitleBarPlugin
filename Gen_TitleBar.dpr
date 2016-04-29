library Gen_TitleBar;

uses
  Windows,
  WinampInterface in 'WinampInterface.pas',
  Configdialog in 'Configdialog.pas',
  HookUnit in 'HookUnit.pas';

{$R *.RES}
{$R ConfigDialog.RES}

exports
  winampGetGeneralPurposePlugin;

var
  MapHandle: HGLOBAL; { For Share FileMap }

procedure OpenShareData;
begin
  MapHandle := CreateFileMapping(Dword(-1), nil, PAGE_READWRITE, 0,
                                 SizeOf(plugin^), APP_NAME);
  if MapHandle <> 0 then
  begin
    plugin := MapViewOfFile(MapHandle, FILE_MAP_ALL_ACCESS,
                            0, 0, SizeOf(plugin^));
    if plugin = nil then CloseHandle(MapHandle);
  end;
end; { OpenShareData }

procedure CloseShareData;         
begin
  UnmapViewOfFile(Pointer(MapHandle));
end; { CloseShareData }

procedure DllEntryPoint(dwReason: Dword);
begin
  case dwReason of
    DLL_PROCESS_ATTACH: OpenShareData;
    DLL_PROCESS_DETACH: CloseShareData;
  end;
end;

begin
  DllProc := @DllEntryPoint;
  DllEntryPoint(DLL_PROCESS_ATTACH);
end.

