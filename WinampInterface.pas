{------------------------------------------------------------------------------}
{                  Winamp interface unit                                       }
{------------------------------------------------------------------------------}
{  Date:2003.04.13                                                             }
{  implementation winamp interface:init,config,quit                            }
{  please see winamp sdk for detial of the interface                           }
{------------------------------------------------------------------------------}

unit WinampInterface;

interface

uses Windows, Messages;

const
  GEN_VERSION = $10;
  APP_NAME = 'Winamp titlebar plugin';
  WINAMP_HEIGHT = 14;
  WINAMP_WIDTH = 275;

type
  TInit = function: integer; stdcall;
  TQuit = procedure; stdcall;
  TConfig = procedure; stdcall;

  PwinampGeneralPurposePlugin = ^TwinampGeneralPurposePlugin;
  TwinampGeneralPurposePlugin = packed record
    version: integer;
    description: pchar;
    init: TInit;
    config: TConfig;
    quit: TQuit;
    hwndParent: HWND;
    hDllInstance: HWND;
  end;

type
  THotKey = (hkPREV,hkNext,hkVolUp,hkVolDown,hkShuffle,hkRepeat,hkPause,hkShow,
             hkDelCurr, hkAddFav, hkID3, hkFwd5s);
  TConfigRec = packed record { Configuration Record }
    Enable: Boolean;
    Alpha: Byte;
    HotKeys:array [THotKey] of Word;
  end;

var
  plugin: PwinampGeneralPurposePlugin; { Share for all process }
  WinampProcessID: Cardinal;
  Configuration: TConfigRec;
  KeyIDs : array [THotKey] of integer;

procedure PlayPrev;
procedure PlayNext;
procedure SetVolUp;
procedure SetVolDown;
procedure SetShuffle;
procedure SetRepeat;
procedure SetPause;
procedure SetShow;
procedure DelCurrFile;
procedure AddFav;
procedure ShowID3Dlg;
procedure PlayFwd;

function GetShade: Boolean;

const
  WProcs:array[THotKey] of procedure=(PlayPrev,PlayNext,SetVolUp,SetVolDown,SetShuffle
     ,SetRepeat,SetPause,SetShow, DelCurrFile, AddFav, ShowId3Dlg, PlayFwd);

function winampGetGeneralPurposePlugin: PwinampGeneralPurposePlugin; stdcall;
function GetDllPath: string; { Get Winamp Plugin's Ini file name }
function IntToStr(int: integer): string;

implementation

uses Configdialog, HookUnit;

const
  IPC_GETLISTPOS = 125;
  IPC_GETPLAYLISTFILE = 211;

var
  DescriptionBuff: string[255];
  bShow:Boolean = False;

procedure PlayPrev;
begin
  if SendMessage(plugin.hwndParent ,WM_USER,0,104) <> 1 then
    PostMessage(plugin.hwndParent ,WM_COMMAND, 40045,0);
  PostMessage(plugin.hwndParent,WM_COMMAND, 40044,0);
end;

procedure PlayNext;
begin
  if SendMessage(plugin.hwndParent ,WM_USER,0,104) <> 1 then
    PostMessage(plugin.hwndParent ,WM_COMMAND,40045,0);
  PostMessage(plugin.hwndParent,WM_COMMAND,40048,0);
end;

procedure SetVolUp;
begin
  PostMessage(plugin.hwndParent,WM_COMMAND,40058,0);
end;

procedure SetVolDown;
begin
  PostMessage(plugin.hwndParent,WM_COMMAND,40059,0);
end;

procedure SetShuffle;
begin
  PostMessage(plugin.hwndParent,WM_COMMAND,40023,0);
end;

procedure SetRepeat;
begin
  PostMessage(plugin.hwndParent,WM_COMMAND,40022,0);
end;

procedure SetPause;
begin
  PostMessage(plugin.hwndParent,WM_COMMAND,40046,0);
end;

procedure SetShow;
begin
  if bShow then
    ShowWindow(plugin.hwndParent,SW_SHOW)
  else
    ShowWindow(plugin.hwndParent,SW_HIDE);
//  PostMessage(plugin.hwndParent,WM_COMMAND,400258,0);
  bShow :=not bShow;
end;

function GetCurrFile: string;
var
  Index : integer;
  FileName: PChar;
begin
  index := SendMessage(plugin.hwndParent, WM_USER, 0, IPC_GETLISTPOS);
  FileName := PChar(SendMessage(plugin.hwndParent, WM_USER, index, IPC_GETPLAYLISTFILE));
  Result := FileName;
end;

function IntToStr(int: integer): string;
begin
  if int = 0 then
    Result := '0'
  else
    while int > 0 do
    begin
      Result := chr($30 + int mod 10) + Result;
      int := int div 10;
    end;
  if int > 0 then Result := chr($30 + int mod 10) + Result;
end; { IntToStr }

function GetCurrTrackLength: integer;
begin
  Result := SendMessage(plugin.hwndParent, WM_USER, 1, 105);
end;

function GetCurrInfo: string;
var
  Index : integer;
  Len : integer;
  Title : PChar;
begin
  index := SendMessage(plugin.hwndParent, WM_USER, 0, IPC_GETLISTPOS);
  Title := PChar(SendMessage(plugin.hwndParent, WM_USER, Index, 212));
  Len := GetCurrTrackLength;
  if Len = - 1 then Len := 0; 
  Result := '#EXTINF:' + IntToStr(Len) + ',' + Title;
end;

function FileSizeEx(const FileName: string): Int64;
{
  返回文件FileName的大小，支持超大文件
}
type
  Int64Rec = packed record
    case Integer of
      0: (Lo, Hi: Cardinal);
      1: (Cardinals: array [0..1] of Cardinal);
      2: (Words: array [0..3] of Word);
      3: (Bytes: array [0..7] of Byte);
  end;
var
  Info: TWin32FindData;
  Hnd: THandle;
begin
  Result := -1;
  Hnd := FindFirstFile(PChar(FileName), Info);
  if (Hnd <> INVALID_HANDLE_VALUE) then
  begin
    Windows.FindClose(Hnd);
    Int64Rec(Result).Lo := Info.nFileSizeLow;
    Int64Rec(Result).Hi := Info.nFileSizeHigh;
  end;
end;

function sprintf(const Format: string; Args: array of const): string; stdcall;
{
  类似C语言中sprintf的函数，请参考MSDN中的wvsprintf函数
Support Format:
  %[-][#][0][width][.precision]type
type Value Meaning
  c        Single character. This value is interpreted as type WCHAR if the calling
           application defines Unicode and as type __wchar_t otherwise.
  C        Single character. This value is interpreted as type __wchar_t if the calling
           application defines Unicode and as type WCHAR otherwise. 
  d        Signed decimal integer. This value is equivalent to i.
  hc, hC   Single character. The wsprintf function ignores character arguments
           with a numeric value of zero. This value is always interpreted as
           type __wchar_t, even when the calling application defines Unicode.
  hd       Signed short integer argument. 
  hs, hS   String. This value is always interpreted as type LPSTR, even when the
           calling application defines Unicode. 
  hu       Unsigned short integer. 
  i        Signed decimal integer. This value is equivalent to d. 
  lc, lC   Single character. The wsprintf function ignores character arguments
           with a numeric value of zero. This value is always interpreted as
           type WCHAR, even when the calling application does not define Unicode. 
  ld       Long signed integer. This value is equivalent to li.
  li       Long signed integer. This value is equivalent to ld.
  ls, lS   String. This value is always interpreted as type LPWSTR, even when the
           calling application does not define Unicode. This value is equivalent to ws.
  lu       Long unsigned integer. 
  lx, lX   Long unsigned hexadecimal integer in lowercase or uppercase. 
  p        Windows 2000/XP: Pointer. The address is printed using hexadecimal.  
  s        String. This value is interpreted as type LPWSTR when the calling
           application defines Unicode and as type LPSTR otherwise.
  S        String. This value is interpreted as type LPSTR when the calling
           application defines Unicode and as type LPWSTR otherwise. 
  u        Unsigned integer argument.
  x, X     Unsigned hexadecimal integer in lowercase or uppercase. 
}
var
  OutPutBuffer: array[0..1023] of char;
  ArgsBuffers: array of PChar;
  i : integer;
begin
  Result := Format;
  if Length(Args) = 0 then Exit;

  SetLength(ArgsBuffers, Length(Args));
  for i:= Low(Args) to High(Args) do
  begin
    ArgsBuffers[i] := Args[i].VPointer;
  end;
    
  ZeroMemory(@OutPutBuffer[0], SizeOf(OutPutBuffer));
  SetString(Result, OutPutBuffer, wvsprintf(OutPutBuffer, PChar(Format), @ArgsBuffers[0]));
end;

function BytesToString(const i64Size: Int64): string;
{
  转换文件大小为字符串描述
}
const
  i64GB = 1024 * 1024 * 1024;
  i64MB = 1024 * 1024;
  i64KB = 1024;
var
  a, b: integer;
begin
  if i64Size div i64GB > 0 then
  begin
    a := i64Size div i64GB;
    b := (i64Size mod i64GB) * 16 div i64GB;
    Result := sprintf('%d.%d GB', [a, b])
  end
  else if i64Size div i64MB > 0 then
  begin
    a := i64Size div i64MB;
    b := (i64Size mod i64MB) * 16 div i64MB;
    Result := sprintf('%d.%d MB', [a, b])
  end
  else if i64Size div i64KB > 0 then
  begin
    a := i64Size div i64KB;
    b := (i64Size mod i64KB) * 16 div i64KB;
    Result := sprintf('%d.%d KB', [a, b])
  end
  else
    Result := IntToStr(i64Size) + 'Byte(s)';
end;

function SecondsToString(MSeconds: int64): string;
{
  毫秒转换成XX天XX小时XX分钟XX秒的格式
}
const
  MSecPerDay: Integer = 1000 * 60 * 60 * 24;
  MSecPerHour: Integer = 1000 * 60 * 60;
  MSecPerMinute: Integer = 1000 * 60;
  MSecPerSecond: integer = 1000;
var
  D, H, M, S: integer;
begin
  D := MSeconds div MSecPerDay;
  MSeconds := MSeconds mod MSecPerDay;
  if D > 0 then Result := IntToStr(D) + ':';

  H := MSeconds div MSecPerHour;
  MSeconds := MSeconds mod MSecPerHour;
  if H > 0 then Result := Result + IntToStr(H) + ':';

  M := MSeconds div MSecPerMinute;
  MSeconds := MSeconds mod MSecPerMinute;
  if M > 0 then Result := Result + IntToStr(M) + ':';

  S := MSeconds div MSecPerSecond;
  if S > 0 then Result := Result + IntToStr(S);
end;

procedure DelCurrFile;
var
  CurrFile : string;
  Msg : string;
  Size : int64;
begin
  CurrFile := GetCurrFile;
  Size := FileSizeEx(CurrFile);
  if Size >  1024 * 1024 * 20 then
  begin
    Msg := 'File size: ' + BytesToString(Size) + #13#10
     + 'File name: ' + CurrFile + #13#10
     + 'Track time: ' + SecondsToString(GetCurrTrackLength * 1000) + #13#10
     + 'Current file maybe contant multi-track, are your sure?';
    if MessageBox(GetForegroundWindow, PChar(Msg), 'Confirm from Winamp',
                  MB_OKCANCEL or MB_ICONWARNING or MB_SYSTEMMODAL) = IDOK then
    begin
      PlayNext;
      DeleteFile(PChar(CurrFile));
    end;
  end else
  begin
    PlayNext;
    DeleteFile(PChar(CurrFile));
  end;
end;

function ExtractFilePath(FileName: string): string;
var                    
  i : integer;
begin
  for i := Length(FileName) downto 1 do
  begin
    if FileName[i] = '\' then
    begin
      Result := Copy(FileName, 1, i);
      Exit;
    end;
  end;
  Result := FileName;
end;

function FileExists(const FileName: string): Boolean;
var
  Handle: THandle;
  FindData: TWin32FindData;
begin
  Handle := FindFirstFile(PChar(FileName), FindData);
  Result := (Handle <> INVALID_HANDLE_VALUE)
    and ((FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0);
  Windows.FindClose(Handle);
end;

procedure AddFav;
var
  FavFile: string;
  F : Text;
begin
  FavFile :=  ExtractFilePath(ParamStr(0)) + 'My Favorite.m3u';
  AssignFile(F, FavFile);
  if FileExists(FavFile) then
    Append(F)
  else
  begin
    PostMessage(plugin.hwndParent, WM_USER, WPARAM(PChar(FavFile)), 129);
    Rewrite(F);
    Writeln(F, '#EXTM3U');
  end;

  WriteLn(F, GetCurrInfo);
  Writeln(F, GetCurrFile);
  Close(F);
end;

procedure ShowID3Dlg;
var
  OldWnd: HWND;
begin
  OldWnd := GetForegroundWindow;
  SetForegroundWindow(plugin.hwndParent);
  PostMessage(plugin.hwndParent, WM_COMMAND, 40188, 0);
  SetForegroundWindow(OldWnd);
end;

procedure PlayFwd;
begin
  PostMessage(plugin.hwndParent, WM_COMMAND, 40060, 0);
end;

function GetShade:Boolean;
begin
  Result := Boolean(PostMessage(plugin.hwndParent, WM_COMMAND, 40065, 0));
end;

function GetDllPath: string; { Get Winamp Plugin's Ini file name }
var
  Buff: array[0..MAX_PATH] of char;
  P: PChar;
begin
  FillChar(Buff, SizeOf(Buff), 0);
  GetModuleFileName(plugin.hDllInstance, @Buff, sizeof(Buff));
  P := @Buff[MAX_PATH];
  while (P^ <> '\') and (P <> Buff) do
    Dec(p); { Get File Name Without Path }
  (P + 1)^ := #0;
  Result := lstrcat(Buff, '');
end; { GetIniFileName }

function HexToBin(Text, Buffer: PChar; BufSize: Integer): Integer; assembler;
const
  Convert: array['0'..'f'] of SmallInt =
    ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,
     -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     -1,10,11,12,13,14,15);
var
  I: Integer;
begin
  I := BufSize;
  while I > 0 do
  begin
    if not (Text[0] in ['0'..'f']) or not (Text[1] in ['0'..'f']) then Break;
    Buffer[0] := Char((Convert[Text[0]] shl 4) + Convert[Text[1]]);
    Inc(Buffer);
    Inc(Text, 2);
    Dec(I);
  end;
  Result := BufSize - I;
end;

procedure LoadConfig; { Get Config From INI }
const
  CSDefaultCfg = '016464026602680262026A026F0A65026D026E026B02330465063B';
begin
  FillChar(Configuration, SizeOf(Configuration), 0);

  if not GetPrivateProfileStruct(APP_NAME, 'Config',
    @Configuration, SizeOf(Configuration),
    pchar(GetDllPath + 'plugin.ini')) then
  begin
    HexToBin(CSDefaultCfg, @Configuration, SizeOf(Configuration));
  end;
end; { LoadConfig }

procedure SaveConfig; { Save Config to INI }
begin
  WritePrivateProfileStruct(APP_NAME, 'Config',
    @Configuration, SizeOf(Configuration),
    pchar(GetDllPath + 'plugin.ini'));
end; { SaveConfig }

function init: integer; stdcall; { For Winamp interface }
const
  MAX_LEN = 100;
var
  DllFileName: array[0..MAX_LEN] of char;
  P: Pchar;
begin
  FillChar(DllFileName, SizeOf(DllFileName), 0);
  GetModuleFileName(plugin.hDllInstance, DllFileName, sizeof(DllFileName));
  P := @DllFileName[MAX_LEN];
  while (P^ <> '\') and (P <> DllFileName) do
    Dec(p); { Get File Name Without Path }
  DescriptionBuff := APP_NAME + ' v2.0.9 (' + (P + 1) + ')';

  InitGlobalAtom;
  GetWindowThreadProcessId(plugin.hwndParent, WinampProcessID);
  LoadConfig;
  HookWinampWindowProc;
  SetWindowBlend(Configuration.Alpha);
  if Configuration.Enable then Hook;
  Result := 0;
end; { Init }

procedure config; stdcall;
begin
  DialogBox(plugin.hDllInstance, MAKEINTRESOURCE(IDD_CONFIG_DIALOG),
    GetActiveWindow, @ConfigProc);
end; { config }

procedure quit; stdcall;
begin
  UnHookWinampWindowProc;
  UnInitGlobalAtom;
  SetWindowLong(plugin.hwndParent, GWL_EXSTYLE,
    GetWindowLong(plugin.hwndParent, GWL_EXSTYLE) and not WS_EX_LAYERED);
  if Configuration.Enable then UnHook;
  SaveConfig;
end; { quit }

function winampGetGeneralPurposePlugin: PwinampGeneralPurposePlugin;
begin
  plugin.version := GEN_VERSION;
  plugin.init := init;
  plugin.config := config;
  plugin.quit := quit;
  plugin.description := @DescriptionBuff[1];

  Result := plugin;
end; { winampGetGeneralPurposePlugin }

end.

